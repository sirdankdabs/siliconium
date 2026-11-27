/*
 * mvkcache: a persistent, lazy, parallel pipeline cache for MoltenVK.
 *
 * DXVK 1.10 creates its pipelines without a VkPipelineCache, so every run
 * translates each shader again (SPIR-V -> MSL with SPIRV-Cross, x86_64 code
 * under Rosetta: ~7 ms a shader, two per pipeline, thousands per map).
 *
 * This library is installed as libMoltenVK.dylib (the real one is renamed
 * libMoltenVK.real.dylib and re-exported), so every Wine process uses it.
 *
 * Design (v2):
 *  - Lazy on-demand micro-shards (default 32): zero disk I/O and zero memory
 *    allocated in the constructor (D3D11/DXMT games, launcher and probe
 *    processes pay nothing). Each shard is read from disk only when a pipeline
 *    actually hashes to it, and its file buffer is freed immediately after
 *    vkCreatePipelineCache (eliminating 300+ MB permanent RAM retention and
 *    preventing Metal from eagerly compiling every map's shaders and
 *    overflowing AGX compiled variant footprint limits).
 *  - No cold-bypass race: the first compiler thread that needs shard s loads
 *    that single small micro-shard synchronously under shard s's own mutex
 *    (other threads run on the other 31 shards in parallel), so every
 *    pipeline from #1 onward hits the cache and is persisted back.
 *  - Fragment-stage sharding: in D3D9 games, fragment shaders are the large,
 *    unique stage (~30 KB MSL) while vertex shaders are small (~9-10 KB) and
 *    shared across many pipelines. Hashing by the fragment shader when present
 *    eliminates cross-shard fragment duplication (e.g. 1.83x -> 1.0x in MW3).
 *  - On-disk LZ4 compression (macOS libcompression) cuts shard files ~4-6x
 *    with >3 GB/s decompression, reducing SSD I/O and write amplification.
 *  - Hooks vkDestroyShaderModule to keep the module hash table bounded.
 *
 *   MVKCACHE_FILE    cache file prefix (default: MVKCACHE_DEFAULT_FILE from
 *                    the build, else mvkcache.bin next to this library);
 *                    v2 shards are <prefix>.v2.0 ... <prefix>.v2.N-1
 *   MVKCACHE_SHARDS  number of shards, 1-64 (default 32)
 *   MVKCACHE_LOG     1: log to stderr
 *   MVKCACHE_OFF     1: pass through only
 *   MVKCACHE_FPS     1: log frame-time statistics every 5 s (stderr)
 */
#include <compression.h>
#include <dlfcn.h>
#include <pthread.h>
#include <pthread/qos.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

typedef int32_t VkResult;
typedef void *VkInstance;
typedef void *VkDevice;
typedef uint64_t VkPipelineCache;
typedef uint64_t VkShaderModule;
typedef void (*PFN_vkVoidFunction)(void);

typedef struct {
    int32_t sType;
    const void *pNext;
    uint32_t flags;
    size_t initialDataSize;
    const void *pInitialData;
} VkPipelineCacheCreateInfo;

typedef struct {
    int32_t sType;
    const void *pNext;
    uint32_t flags;
    size_t codeSize;
    const uint32_t *pCode;
} VkShaderModuleCreateInfo;

typedef struct {
    int32_t sType;
    const void *pNext;
    uint32_t flags;
    uint32_t stage;
    VkShaderModule module;
    const char *pName;
    const void *pSpecializationInfo;
} VkPipelineShaderStageCreateInfo;

typedef struct {            /* leading members of VkGraphicsPipelineCreateInfo */
    int32_t sType;
    const void *pNext;
    uint32_t flags;
    uint32_t stageCount;
    const VkPipelineShaderStageCreateInfo *pStages;
} GfxInfoHead;

typedef struct {            /* leading members of VkComputePipelineCreateInfo */
    int32_t sType;
    const void *pNext;
    uint32_t flags;
    VkPipelineShaderStageCreateInfo stage;
} CmpInfoHead;

typedef PFN_vkVoidFunction (*PFN_GIPA)(VkInstance, const char *);
typedef PFN_vkVoidFunction (*PFN_GDPA)(VkDevice, const char *);
typedef VkResult (*PFN_CreatePC)(VkDevice, const VkPipelineCacheCreateInfo *, const void *, VkPipelineCache *);
typedef void (*PFN_DestroyPC)(VkDevice, VkPipelineCache, const void *);
typedef VkResult (*PFN_GetPCData)(VkDevice, VkPipelineCache, size_t *, void *);
typedef VkResult (*PFN_CreatePipes)(VkDevice, VkPipelineCache, uint32_t, const void *, const void *, void *);
typedef VkResult (*PFN_CreateSM)(VkDevice, const VkShaderModuleCreateInfo *, const void *, VkShaderModule *);
typedef void (*PFN_DestroySM)(VkDevice, VkShaderModule, const void *);
typedef void (*PFN_DestroyDevice)(VkDevice, const void *);

static PFN_GIPA real_gipa;
static PFN_GDPA real_gdpa;
static PFN_CreatePC real_create_pc;
static PFN_DestroyPC real_destroy_pc;
static PFN_GetPCData real_get_pc_data;
static PFN_CreatePipes real_create_gfx, real_create_cmp;
static PFN_CreateSM real_create_sm;
static PFN_DestroySM real_destroy_sm;
static PFN_DestroyDevice real_destroy_dev;

#define MAX_SHARDS 64
#define DEFAULT_SHARDS 32
#define MAX_DEVS 8
#define VK_INCOMPLETE_RESULT 5
#define VK_STAGE_FRAGMENT_BIT 0x00000010u

static char cache_path[1024];
static int nshards = DEFAULT_SHARDS;
static int logging, disabled, fps_log;

typedef struct {
    VkDevice dev;
    VkPipelineCache pc[MAX_SHARDS];
    volatile int ready[MAX_SHARDS];       /* 0: unloaded, 1: loaded & usable */
    volatile uint32_t dirty[MAX_SHARDS];  /* 1: new pipelines added since last save */
    size_t saved_raw[MAX_SHARDS];         /* uncompressed VkPipelineCache size on disk */
    pthread_mutex_t slock[MAX_SHARDS];    /* serializes one-time lazy load of shard s */
    uint32_t loaded_count;
    uint64_t load_ns_total;
} DevCaches;

static DevCaches devs[MAX_DEVS];
static volatile int devs_ready[MAX_DEVS];
static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;   /* devs[] lifecycle and saving */
static volatile uint64_t created, last_create_ns, create_ns;
static uint64_t saved_count = (uint64_t)-1, last_save_ns;
static pthread_once_t saver_once = PTHREAD_ONCE_INIT;

#define LOG(...) do { if (logging) { fprintf(stderr, "[mvkcache] " __VA_ARGS__); fputc('\n', stderr); } } while (0)

static uint64_t now_ns(void) { return clock_gettime_nsec_np(CLOCK_UPTIME_RAW); }

/* ---- shader code hashes, by module handle (open-addressed with backward-shift delete) ---- */

#define HASH_SLOTS (1 << 16)
static struct { VkShaderModule m; uint64_t h; } hashes[HASH_SLOTS];
static pthread_mutex_t hlock = PTHREAD_MUTEX_INITIALIZER;

static uint64_t fnv(const void *p, size_t n)
{
    const unsigned char *b = p;
    uint64_t h = 1469598103934665603ull;
    for (size_t i = 0; i < n; i++) { h ^= b[i]; h *= 1099511628211ull; }
    return h;
}

static size_t slot_of(VkShaderModule m) { return (size_t)((m * 0x9E3779B97F4A7C15ull) >> 48) & (HASH_SLOTS - 1); }

static void remember_hash(VkShaderModule m, uint64_t h)
{
    if (!m) return;
    pthread_mutex_lock(&hlock);
    size_t s = slot_of(m);
    for (size_t i = 0; i < HASH_SLOTS; i++, s = (s + 1) & (HASH_SLOTS - 1)) {
        if (hashes[s].m == m || hashes[s].m == 0) {
            hashes[s].m = m;
            hashes[s].h = h;
            break;
        }
    }
    pthread_mutex_unlock(&hlock);
}

static void forget_hash(VkShaderModule m)
{
    if (!m) return;
    pthread_mutex_lock(&hlock);
    size_t s = slot_of(m);
    for (size_t i = 0; i < HASH_SLOTS; i++, s = (s + 1) & (HASH_SLOTS - 1)) {
        if (hashes[s].m == 0) break;
        if (hashes[s].m == m) {
            /* Backward-shift deletion preserves probe chains without tombstones */
            size_t hole = s;
            size_t cur = (hole + 1) & (HASH_SLOTS - 1);
            while (hashes[cur].m != 0) {
                size_t ideal = slot_of(hashes[cur].m);
                size_t dist_cur = (cur - ideal) & (HASH_SLOTS - 1);
                size_t dist_hole = (cur - hole) & (HASH_SLOTS - 1);
                if (dist_cur >= dist_hole) {
                    hashes[hole] = hashes[cur];
                    hole = cur;
                }
                cur = (cur + 1) & (HASH_SLOTS - 1);
            }
            hashes[hole].m = 0;
            hashes[hole].h = 0;
            break;
        }
    }
    pthread_mutex_unlock(&hlock);
}

static uint64_t module_hash(VkShaderModule m)
{
    uint64_t h = 0;
    pthread_mutex_lock(&hlock);
    size_t s = slot_of(m);
    for (size_t i = 0; i < HASH_SLOTS; i++, s = (s + 1) & (HASH_SLOTS - 1)) {
        if (hashes[s].m == m) { h = hashes[s].h; break; }
        if (hashes[s].m == 0) break;
    }
    pthread_mutex_unlock(&hlock);
    return h ? h : m;
}

static VkResult my_create_sm(VkDevice dev, const VkShaderModuleCreateInfo *ci, const void *alloc, VkShaderModule *out)
{
    VkResult r = real_create_sm(dev, ci, alloc, out);
    if (r == 0 && ci && ci->pCode && out && *out)
        remember_hash(*out, fnv(ci->pCode, ci->codeSize) | 1);
    return r;
}

static void my_destroy_sm(VkDevice dev, VkShaderModule m, const void *alloc)
{
    forget_hash(m);
    real_destroy_sm(dev, m, alloc);
}

/* ---- compressed shard file I/O (LZ4 via libcompression) ---- */

#define MVKZ_MAGIC_0 'M'
#define MVKZ_MAGIC_1 'V'
#define MVKZ_MAGIC_2 'K'
#define MVKZ_MAGIC_3 'Z'
#define MVKZ_VERSION 1u
#define MVKZ_MAX_RAW (256ull << 20) /* 256 MB sanity cap per single micro-shard */

typedef struct {
    uint8_t magic[4];
    uint32_t version;
    uint64_t raw_size;
} MvkzHeader;

static void shard_file(int i, char *buf, size_t n)
{
    if (nshards == DEFAULT_SHARDS)
        snprintf(buf, n, "%s.v2.%d", cache_path, i);
    else
        snprintf(buf, n, "%s.v2.%d.%d", cache_path, nshards, i);
}

static int read_shard_file(int i, void **out_data, size_t *out_size)
{
    char path[1100];
    shard_file(i, path, sizeof path);
    FILE *f = fopen(path, "rb");
    if (!f) return 0;
    if (fseek(f, 0, SEEK_END) != 0) { fclose(f); return 0; }
    long n = ftell(f);
    if (n <= 0 || fseek(f, 0, SEEK_SET) != 0) { fclose(f); return 0; }
    uint8_t *file_buf = malloc((size_t)n);
    if (!file_buf) { fclose(f); return 0; }
    int ok = fread(file_buf, 1, (size_t)n, f) == (size_t)n;
    fclose(f);
    if (!ok) { free(file_buf); return 0; }

    if ((size_t)n >= sizeof(MvkzHeader) &&
        file_buf[0] == MVKZ_MAGIC_0 && file_buf[1] == MVKZ_MAGIC_1 &&
        file_buf[2] == MVKZ_MAGIC_2 && file_buf[3] == MVKZ_MAGIC_3) {
        MvkzHeader hdr;
        memcpy(&hdr, file_buf, sizeof hdr);
        if (hdr.version != MVKZ_VERSION || hdr.raw_size == 0 || hdr.raw_size > MVKZ_MAX_RAW) {
            free(file_buf);
            return 0;
        }
        uint8_t *raw = malloc((size_t)hdr.raw_size);
        if (!raw) { free(file_buf); return 0; }
        size_t decoded = compression_decode_buffer(
            raw, (size_t)hdr.raw_size,
            file_buf + sizeof hdr, (size_t)n - sizeof hdr,
            NULL, COMPRESSION_LZ4);
        free(file_buf);
        if (decoded != (size_t)hdr.raw_size) {
            free(raw);
            return 0;
        }
        *out_data = raw;
        *out_size = decoded;
        return 1;
    }

    /* Raw uncompressed VkPipelineCache fallback */
    *out_data = file_buf;
    *out_size = (size_t)n;
    return 1;
}

static int write_shard_file(int i, const void *raw_data, size_t raw_size, size_t *out_written)
{
    char path[1100], tmp[1200];
    shard_file(i, path, sizeof path);
    snprintf(tmp, sizeof tmp, "%s.%d.tmp", path, getpid());

    size_t dst_cap = raw_size + (raw_size >> 4) + 64;
    uint8_t *comp = malloc(dst_cap);
    size_t comp_size = 0;
    if (comp) {
        comp_size = compression_encode_buffer(
            comp, dst_cap, (const uint8_t *)raw_data, raw_size, NULL, COMPRESSION_LZ4);
    }

    FILE *f = fopen(tmp, "wb");
    if (!f) { free(comp); return 0; }

    int ok = 0;
    size_t written = 0;
    if (comp && comp_size > 0 && comp_size + sizeof(MvkzHeader) < raw_size) {
        MvkzHeader hdr = { { MVKZ_MAGIC_0, MVKZ_MAGIC_1, MVKZ_MAGIC_2, MVKZ_MAGIC_3 }, MVKZ_VERSION, raw_size };
        ok = fwrite(&hdr, 1, sizeof hdr, f) == sizeof hdr &&
             fwrite(comp, 1, comp_size, f) == comp_size;
        written = sizeof hdr + comp_size;
    } else {
        ok = fwrite(raw_data, 1, raw_size, f) == raw_size;
        written = raw_size;
    }
    free(comp);

    int closed = (fclose(f) == 0);
    if (ok && closed && rename(tmp, path) == 0) {
        if (out_written) *out_written = written;
        return 1;
    }
    unlink(tmp);
    return 0;
}

/* ---- saving ---- */

/* Called with global lock + shard slock[i] held. Writes a loaded shard if it outgrew what is on disk. */
static void save_shard_locked(int d, int i)
{
    VkDevice dev = devs[d].dev;
    VkPipelineCache pc = devs[d].pc[i];
    if (!dev || !pc) return;

    for (int attempt = 0; attempt < 3; attempt++) {
        size_t size = 0;
        if (real_get_pc_data(dev, pc, &size, NULL) != 0 || size <= devs[d].saved_raw[i])
            return;
        /* Generous headroom so concurrent 8-thread bursts avoid VK_INCOMPLETE */
        size_t cap = size + (size >> 2) + 262144;
        void *buf = malloc(cap);
        if (!buf) return;
        size_t actual = cap;
        VkResult r = real_get_pc_data(dev, pc, &actual, buf);
        if (r == 0 && actual > devs[d].saved_raw[i]) {
            size_t disk_bytes = 0;
            if (write_shard_file(i, buf, actual, &disk_bytes)) {
                LOG("saved shard %d: %zu KB raw -> %zu KB on disk (%llu pipelines)",
                    i, actual >> 10, disk_bytes >> 10, (unsigned long long)created);
                devs[d].saved_raw[i] = actual;
            }
            free(buf);
            return;
        }
        free(buf);
        if (r != VK_INCOMPLETE_RESULT) return;
    }
}

static void save_all_locked(void)
{
    for (int d = 0; d < MAX_DEVS; d++) {
        if (!devs[d].dev) continue;
        for (int i = 0; i < nshards; i++) {
            if (!__atomic_load_n(&devs[d].ready[i], __ATOMIC_ACQUIRE)) continue;
            if (!__atomic_exchange_n(&devs[d].dirty[i], 0, __ATOMIC_ACQ_REL)) continue;
            pthread_mutex_lock(&devs[d].slock[i]);
            if (devs[d].ready[i] && devs[d].pc[i])
                save_shard_locked(d, i);
            pthread_mutex_unlock(&devs[d].slock[i]);
        }
    }
}

static void *saver(void *arg)
{
    (void)arg;
    pthread_set_qos_class_self_np(QOS_CLASS_BACKGROUND, 0);
    for (;;) {
        sleep(1);
        uint64_t c = __atomic_load_n(&created, __ATOMIC_RELAXED);
        if (c == saved_count) continue;
        uint64_t now = now_ns();
        uint64_t last = __atomic_load_n(&last_create_ns, __ATOMIC_RELAXED);
        uint64_t delta = (saved_count == (uint64_t)-1) ? c : (c - saved_count);
        /* Save once pipeline creation pauses 3 s, or 1.5 s after a >=500 burst, or every 30 s */
        int idle_ready  = (now - last >= 3000000000ull);
        int burst_ready = (delta >= 500 && now - last >= 1500000000ull);
        int periodic    = (now - last_save_ns >= 30000000000ull);
        if (!idle_ready && !burst_ready && !periodic) continue;
        LOG("%llu pipelines so far, %.2f ms each on average",
            (unsigned long long)c, c ? __atomic_load_n(&create_ns, __ATOMIC_RELAXED) / 1e6 / c : 0.0);
        pthread_mutex_lock(&lock);
        save_all_locked();
        saved_count = c;
        last_save_ns = now_ns();
        pthread_mutex_unlock(&lock);
    }
    return NULL;
}

static void start_saver(void)
{
    pthread_t t;
    if (pthread_create(&t, NULL, saver, NULL) == 0) pthread_detach(t);
}

/* ---- lazy per-shard device caches ---- */

static int resolve_cache_fns(VkDevice dev)
{
    if (!real_create_pc) real_create_pc = (PFN_CreatePC)real_gdpa(dev, "vkCreatePipelineCache");
    if (!real_destroy_pc) real_destroy_pc = (PFN_DestroyPC)real_gdpa(dev, "vkDestroyPipelineCache");
    if (!real_get_pc_data) real_get_pc_data = (PFN_GetPCData)real_gdpa(dev, "vkGetPipelineCacheData");
    return real_create_pc && real_destroy_pc && real_get_pc_data;
}

static VkPipelineCache ensure_shard_loaded(int d, int s)
{
    if (__atomic_load_n(&devs[d].ready[s], __ATOMIC_ACQUIRE))
        return devs[d].pc[s];

    pthread_mutex_lock(&devs[d].slock[s]);
    if (!__atomic_load_n(&devs[d].ready[s], __ATOMIC_ACQUIRE)) {
        VkDevice dev = devs[d].dev;
        if (dev) {
            uint64_t t0 = now_ns();
            void *buf = NULL;
            size_t raw_size = 0;
            int has_file = read_shard_file(s, &buf, &raw_size);

            VkPipelineCache pc = 0;
            VkPipelineCacheCreateInfo ci = {
                17 /* VK_STRUCTURE_TYPE_PIPELINE_CACHE_CREATE_INFO */,
                NULL, 0, has_file ? raw_size : 0, has_file ? buf : NULL
            };
            VkResult r = real_create_pc(dev, &ci, NULL, &pc);
            if (r != 0 && has_file) {
                ci.initialDataSize = 0;
                ci.pInitialData = NULL;
                if (real_create_pc(dev, &ci, NULL, &pc) != 0) pc = 0;
            }
            /* Free raw file buffer immediately — zero permanent RAM retention */
            free(buf);

            devs[d].pc[s] = pc;
            devs[d].saved_raw[s] = (has_file && r == 0) ? raw_size : 0;
            __atomic_store_n(&devs[d].ready[s], 1, __ATOMIC_RELEASE);

            uint64_t dt = now_ns() - t0;
            __atomic_add_fetch(&devs[d].loaded_count, 1, __ATOMIC_RELAXED);
            __atomic_add_fetch(&devs[d].load_ns_total, dt, __ATOMIC_RELAXED);
            if (has_file)
                LOG("shard %d loaded on demand in %.1f ms (%zu KB raw, %s)",
                    s, dt / 1e6, raw_size >> 10, r == 0 ? "hit" : "corrupt->empty");
        }
    }
    VkPipelineCache pc = devs[d].pc[s];
    pthread_mutex_unlock(&devs[d].slock[s]);
    return pc;
}

static VkPipelineCache device_cache(VkDevice dev, int s)
{
    for (int d = 0; d < MAX_DEVS; d++)
        if (__atomic_load_n(&devs_ready[d], __ATOMIC_ACQUIRE) && devs[d].dev == dev)
            return ensure_shard_loaded(d, s);

    pthread_mutex_lock(&lock);
    int d, free_slot = -1;
    for (d = 0; d < MAX_DEVS; d++) {
        if (devs[d].dev == dev) break;
        if (!devs[d].dev && free_slot < 0) free_slot = d;
    }
    if (d == MAX_DEVS) {
        if (free_slot < 0 || !resolve_cache_fns(dev)) {
            pthread_mutex_unlock(&lock);
            return 0;
        }
        d = free_slot;
        devs[d].dev = dev;
        devs[d].loaded_count = 0;
        devs[d].load_ns_total = 0;
        for (int i = 0; i < nshards; i++) {
            devs[d].pc[i] = 0;
            devs[d].ready[i] = 0;
            devs[d].dirty[i] = 0;
            devs[d].saved_raw[i] = 0;
        }
        __atomic_store_n(&devs_ready[d], 1, __ATOMIC_RELEASE);
        pthread_once(&saver_once, start_saver);
        LOG("device %p: lazy cache initialized (%d micro-shards, prefix %s)", dev, nshards, cache_path);
    }
    pthread_mutex_unlock(&lock);
    return ensure_shard_loaded(d, s);
}

static void my_destroy_dev(VkDevice dev, const void *alloc)
{
    pthread_mutex_lock(&lock);
    for (int d = 0; d < MAX_DEVS; d++) {
        if (devs[d].dev == dev) {
            __atomic_store_n(&devs_ready[d], 0, __ATOMIC_RELEASE);
            for (int i = 0; i < nshards; i++) {
                pthread_mutex_lock(&devs[d].slock[i]);
                if (devs[d].ready[i] && devs[d].pc[i]) {
                    if (__atomic_exchange_n(&devs[d].dirty[i], 0, __ATOMIC_ACQ_REL))
                        save_shard_locked(d, i);
                    real_destroy_pc(dev, devs[d].pc[i], NULL);
                    devs[d].pc[i] = 0;
                }
                devs[d].ready[i] = 0;
                devs[d].saved_raw[i] = 0;
                pthread_mutex_unlock(&devs[d].slock[i]);
            }
            LOG("device %p destroyed: %u/%d shards touched (%.2f s cumulative load)",
                dev, devs[d].loaded_count, nshards, devs[d].load_ns_total / 1e9);
            devs[d].dev = NULL;
        }
    }
    pthread_mutex_unlock(&lock);
    real_destroy_dev(dev, alloc);
}

static int shard_of(const VkPipelineShaderStageCreateInfo *st, uint32_t n)
{
    uint64_t h = 0;
    if (st && n) {
        for (uint32_t i = 0; i < n; i++) {
            if (st[i].stage == VK_STAGE_FRAGMENT_BIT) {
                h = module_hash(st[i].module);
                break;
            }
        }
        if (!h) {
            for (uint32_t i = 0; i < n; i++)
                h = h * 31 + module_hash(st[i].module);
        }
    }
    h ^= h >> 33;
    h *= 0xff51afd7ed558ccdull;
    h ^= h >> 33;
    return (int)(h % (uint64_t)nshards);
}

static void mark_shard_dirty(VkDevice dev, int s)
{
    for (int d = 0; d < MAX_DEVS; d++) {
        if (__atomic_load_n(&devs_ready[d], __ATOMIC_ACQUIRE) && devs[d].dev == dev) {
            __atomic_store_n(&devs[d].dirty[s], 1, __ATOMIC_RELEASE);
            return;
        }
    }
}

static VkResult my_create_gfx(VkDevice dev, VkPipelineCache pc, uint32_t n, const void *ci, const void *alloc, void *out)
{
    int used_shard = -1;
    if (!pc && n && ci) {
        const GfxInfoHead *g = ci;
        used_shard = shard_of(g->pStages, g->stageCount);
        pc = device_cache(dev, used_shard);
        if (pc) mark_shard_dirty(dev, used_shard);
    }
    uint64_t t = now_ns();
    VkResult r = real_create_gfx(dev, pc, n, ci, alloc, out);
    uint64_t end = now_ns();
    __atomic_store_n(&last_create_ns, end, __ATOMIC_RELAXED);
    __atomic_add_fetch(&create_ns, end - t, __ATOMIC_RELAXED);
    __atomic_add_fetch(&created, n, __ATOMIC_RELAXED);
    return r;
}

static VkResult my_create_cmp(VkDevice dev, VkPipelineCache pc, uint32_t n, const void *ci, const void *alloc, void *out)
{
    int used_shard = -1;
    if (!pc && n && ci) {
        const CmpInfoHead *c = ci;
        used_shard = shard_of(&c->stage, 1);
        pc = device_cache(dev, used_shard);
        if (pc) mark_shard_dirty(dev, used_shard);
    }
    uint64_t t = now_ns();
    VkResult r = real_create_cmp(dev, pc, n, ci, alloc, out);
    uint64_t end = now_ns();
    __atomic_store_n(&last_create_ns, end, __ATOMIC_RELAXED);
    __atomic_add_fetch(&create_ns, end - t, __ATOMIC_RELAXED);
    __atomic_add_fetch(&created, n, __ATOMIC_RELAXED);
    return r;
}

/* ---- frame-time statistics ---- */

typedef VkResult (*PFN_Present)(void *, const void *);
static PFN_Present real_present;
#define FT_MAX 4096
static float ft[FT_MAX];
static int ft_n;
static uint64_t ft_last, ft_start;

static int cmpf(const void *a, const void *b) { float x = *(const float *)a, y = *(const float *)b; return (x > y) - (x < y); }

static VkResult my_present(void *queue, const void *info)
{
    VkResult r = real_present(queue, info);
    uint64_t t = now_ns();
    if (ft_last && ft_n < FT_MAX) ft[ft_n++] = (t - ft_last) / 1e6f;
    ft_last = t;
    if (!ft_start) ft_start = t;
    if (t - ft_start >= 5000000000ull && ft_n > 10) {
        double sum = 0; int slow = 0;
        for (int i = 0; i < ft_n; i++) { sum += ft[i]; if (ft[i] > 1000.0f / 150) slow++; }
        qsort(ft, ft_n, sizeof *ft, cmpf);
        float p99 = ft[(int)(ft_n * 0.99)], p50 = ft[ft_n / 2], mx = ft[ft_n - 1];
        fprintf(stderr, "[fps] avg %.1f FPS, median %.2f ms, 1%% low %.1f FPS, worst %.1f ms, %d/%d frames over 6.7 ms\n",
                1000.0 * ft_n / sum, p50, 1000.0 / p99, mx, slow, ft_n);
        ft_n = 0; ft_start = t;
    }
    return r;
}

/* ---- entry points ---- */

static PFN_vkVoidFunction hook(const char *name, PFN_vkVoidFunction real)
{
    if (!real || disabled) return real;
#define H(n, var, fn) if (!strcmp(name, n)) { if (!var) var = (void *)real; return (PFN_vkVoidFunction)fn; }
    H("vkCreateShaderModule", real_create_sm, my_create_sm);
    H("vkDestroyShaderModule", real_destroy_sm, my_destroy_sm);
    H("vkCreateGraphicsPipelines", real_create_gfx, my_create_gfx);
    H("vkCreateComputePipelines", real_create_cmp, my_create_cmp);
    H("vkDestroyDevice", real_destroy_dev, my_destroy_dev);
    if (fps_log) { H("vkQueuePresentKHR", real_present, my_present); }
#undef H
    return real;
}

PFN_vkVoidFunction vkGetDeviceProcAddr(VkDevice dev, const char *name);

PFN_vkVoidFunction vkGetInstanceProcAddr(VkInstance inst, const char *name)
{
    if (!strcmp(name, "vkGetInstanceProcAddr")) return (PFN_vkVoidFunction)vkGetInstanceProcAddr;
    if (!strcmp(name, "vkGetDeviceProcAddr")) return (PFN_vkVoidFunction)vkGetDeviceProcAddr;
    return hook(name, real_gipa(inst, name));
}

PFN_vkVoidFunction vkGetDeviceProcAddr(VkDevice dev, const char *name)
{
    if (!strcmp(name, "vkGetDeviceProcAddr")) return (PFN_vkVoidFunction)vkGetDeviceProcAddr;
    return hook(name, real_gdpa(dev, name));
}

__attribute__((constructor)) static void init(void)
{
    Dl_info di;
    char dir[1024] = ".";
    if (dladdr((void *)init, &di) && di.dli_fname) {
        snprintf(dir, sizeof dir, "%s", di.dli_fname);
        char *s = strrchr(dir, '/');
        if (s) *s = 0;
    }
    for (int d = 0; d < MAX_DEVS; d++)
        for (int i = 0; i < MAX_SHARDS; i++)
            pthread_mutex_init(&devs[d].slock[i], NULL);

    logging = getenv("MVKCACHE_LOG") && atoi(getenv("MVKCACHE_LOG"));
    disabled = getenv("MVKCACHE_OFF") && atoi(getenv("MVKCACHE_OFF"));
    fps_log = getenv("MVKCACHE_FPS") && atoi(getenv("MVKCACHE_FPS"));
    if (getenv("MVKCACHE_SHARDS")) {
        int n = atoi(getenv("MVKCACHE_SHARDS"));
        if (n >= 1 && n <= MAX_SHARDS) nshards = n;
    }
    char mvk[1100];
    snprintf(mvk, sizeof mvk, "%s/libMoltenVK.real.dylib", dir);
    void *h = dlopen(mvk, RTLD_NOW | RTLD_LOCAL);
    if (!h) { fprintf(stderr, "[mvkcache] cannot load %s: %s\n", mvk, dlerror()); abort(); }
    real_gipa = (PFN_GIPA)dlsym(h, "vkGetInstanceProcAddr");
    real_gdpa = (PFN_GDPA)dlsym(h, "vkGetDeviceProcAddr");
    const char *p = getenv("MVKCACHE_FILE");
    if (p && *p) snprintf(cache_path, sizeof cache_path, "%s", p);
#ifdef MVKCACHE_DEFAULT_FILE
    else snprintf(cache_path, sizeof cache_path, "%s", MVKCACHE_DEFAULT_FILE);
#else
    else snprintf(cache_path, sizeof cache_path, "%s/mvkcache.bin", dir);
#endif
}
