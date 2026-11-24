#!/bin/bash
# Siliconium: Black Ops III's Mod Tools (Steam app 455130: the Mod Tools
# launcher, Radiant with its effects editor, the Asset Property Editor, the map
# compiler and linker), from Steam's own downloads, in Steam's prefix
# (prefix-steam). Steam's files are never changed.
#
# The tools work in one folder holding the game and themselves (on Windows
# they were installed into the game's folder; Steam now gives them a folder of
# their own, "Call of Duty Black Ops III 455130", and the launcher no longer
# finds the game). So they run from a workspace in Siliconium's folder,
# bo3-modtools/Call of Duty Black Ops III (tools/steam-copy.sh, as CoD4X's and
# IW7-Mod's copies): at each start the game and the tools are put there as
# APFS clones (no disk space), and a minute after the tools close Steam's
# files leave it again. What stays is the player's work: maps, compiled maps,
# mods, assets, the tools' databases. Uninstalling the game or the tools in
# Steam never deletes it.
#
#   bo3-modtools.sh status          state=installed|downloading|missing
#                                   game=<the game's folder>  tools=<the tools' folder>
#                                   workspace=<the workspace>  work=<the Mac folder>
#   bo3-modtools.sh work [--reveal] the Mac folder of the player's work,
#                                   Documents/Black Ops III Mod Tools: links to
#                                   the workspace's work folders (Finder opens
#                                   them like folders; inside the tools it is
#                                   Documents\Black Ops III Mod Tools, as Wine's
#                                   Documents is the Mac's); --reveal shows it
#   bo3-modtools.sh start           opens the Mod Tools launcher; returns when
#                                   every tool (and a map test it started) is closed
#
# Progress lines start with "==> "; errors with "ERROR: ".
set -uo pipefail
kit=$(cd -- "$(dirname -- "$0")" && pwd)
home=${SIL_HOME:-"$HOME/Library/Application Support/Siliconium"}
. "$kit/tools/migrate.sh"
engine="$home/engine"
export WINEPREFIX="$home/prefix-steam" WINEMSYNC=1 WINEDEBUG=${WINEDEBUG:--all} CX_ROOT="$engine"
# the same Wine server link as Steam's (steam.sh): one server for the prefix
mkdir -p "$home/campaign" "$home/logs"
ln -sfn "$engine/bin/wineserver" "$home/campaign/wineserver"
export WINESERVER="$home/campaign/wineserver"
wine="$engine/lib/wine/x86_64-unix/wine"
app=455130
log="$home/logs/bo3-modtools.log"
step() { printf '==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

game=$(bash "$kit/steam.sh" gamedir 311210)
tools=$(bash "$kit/steam.sh" gamedir "$app")
state=$(bash "$kit/steam.sh" state "$app")
[ -n "$game" ] || state=missing
ws="$home/bo3-modtools/Call of Duty Black Ops III"
# The player's work in the workspace (fixed paths below its root, as the tools
# and the launcher build them): map sources (map_source/<xx>/<map>.map), the
# maps and mods being built (usermaps, mods), the assets made for them
work_dirs="map_source usermaps mods model_export source_data texture_assets sound_assets"
work="$HOME/Documents/Black Ops III Mod Tools"

# The Mac folder: one link per work folder of the workspace (those that
# exist; map_source, usermaps and mods always do). Links only: nothing is
# copied, and anything else the player keeps there is never touched.
make_work() {
  local d
  mkdir -p "$work" "$ws/map_source" "$ws/usermaps" "$ws/mods" || return 1
  for d in $work_dirs; do
    [ -d "$ws/$d" ] || continue
    if [ -L "$work/$d" ]; then
      [ "$(readlink "$work/$d")" = "$ws/$d" ] && continue
      rm -f "$work/$d"
    fi
    [ -e "$work/$d" ] || ln -s "$ws/$d" "$work/$d"
  done
}
# Variables for every program of the prefix: Wine gives them the values in
# its registry (HKCU\Environment) over the ones passed from here (measured
# 2026-11-22), and the tools' own launcher script stores them there with
# setx, which Wine does not have. One import of every value (regedit, UTF-16
# as launch.sh's)
reg_import() {   # [<key>] <name>=<value> | -<name> (removed) ...
  local f kv n v
  f=$(mktemp "$home/cache/sil-reg.XXXXXX") || return 1
  { printf '\xff\xfe'
    { printf 'Windows Registry Editor Version 5.00\r\n\r\n'
      for kv in "$@"; do
        # (a name can be a path: its backslashes escaped as the value's)
        case "$kv" in
          \[*) printf '\r\n%s\r\n' "$kv"; continue ;;
          -*) n=${kv#-}; n=${n//\\/\\\\}; printf '"%s"=-\r\n' "${n//\"/\\\"}"; continue ;;
        esac
        n=${kv%%=*}; n=${n//\\/\\\\}; n=${n//\"/\\\"}
        v=${kv#*=}; v=${v//\\/\\\\}; v=${v//\"/\\\"}
        printf '"%s"="%s"\r\n' "$n" "$v"
      done
    } | iconv -f UTF-8 -t UTF-16LE
  } > "$f"
  "$wine" regedit /S "$(sil_winpath "$f")" > /dev/null 2>&1
  rm -f "$f"
}

case "${1:-}" in
status)
  echo "state=$state"
  echo "game=$game"
  echo "tools=$tools"
  echo "workspace=$ws"
  echo "work=$work"
  ;;
work)
  make_work || die "could not make $work"
  [ "${2:-}" = --reveal ] && open "$work"
  ;;
start)
  [ -x "$wine" ] || die "install the Siliconium engine first"
  [ -n "$game" ] && [ -f "$game/BlackOps3.exe" ] || die "Black Ops III is not downloaded in Steam: the Mod Tools need the game"
  [ "$state" = installed ] && [ -n "$tools" ] || die "the Mod Tools are not downloaded yet: press Mod Tools in the Steam Library"
  launcher=bin/modlauncher.exe
  [ -f "$tools/$launcher" ] || die "the Mod Tools launcher ($launcher) is not in Steam's download: let Steam verify the Mod Tools"
  mkdir -p "$home/cache"
  . "$kit/tools/winpath.sh"
  . "$kit/tools/steam-copy.sh"
  pgrep -f "$(sil_copy_exe bo3-modtools)" > /dev/null && die "the Mod Tools are already open"
  # Steam in the background: the launcher signs in to it (Workshop publishing)
  # and a map test starts the game, which needs it
  step "Starting Steam"
  bash "$kit/steam.sh" start || exit 1
  bash "$kit/steam.sh" wait || exit 1
  step "Preparing the Mod Tools workspace"
  over=; [ "$tools" != "$game" ] && over=$tools
  sil_copy_make bo3-modtools "$game" "$ws" "$over" || {
    [ "$sil_copy_error" = clones ] &&
      die "the Mod Tools need Black Ops III and the Mod Tools in Steam's library on this Mac's disk (APFS): Siliconium puts them together without copying them"
    die "${sil_copy_error:-could not prepare the Mod Tools workspace in $home/bo3-modtools}"; }
  # a minute after the tools close, Steam's files leave the workspace; the
  # game's community fix (below) leaves it at once
  trap '{ declare -F steam_mod_remove > /dev/null && steam_mod_remove "$ws"; }
        ( /bin/bash "$kit/tools/steam-copy.sh" release bo3-modtools "$sil_copy_dir" "$sil_copy_gen" 60 > /dev/null 2>&1 & )' EXIT
  make_work || printf '%s\n' "Warning: could not make $work" >&2
  # The launcher's own script (modtools_launcher.bat): both roots = the
  # workspace, the asset cache in its share\assetconvert. Drawing: Radiant's,
  # the Asset Editor's and the game's Direct3D 11 on Metal (DXMT), new
  # shaders compiled in the background (no stall while flying through a map),
  # frames paced at the display's refresh rate
  # The workspace as a drive of its own (X:\): the tools start each other with
  # unquoted command lines (GdtDBTrayLauncher runs bin\GdtDBTray.N.tmp), which
  # Windows and Wine split at each space and try word by word; under
  # "Application Support" a stray file named ~/Library/Application stopped
  # that search, GdtDBTray never ran, and Radiant's lighting crashed loading
  # the map (2026-11-22). No spaces, and short paths (MAX_PATH) for deep assets
  if letter=$(sil_drive_for "$ws"); then root="$(printf '%s' "$letter" | tr '[:lower:]' '[:upper:]'):\\"
  else root="$(sil_winpath "$ws")\\"; fi
  # (a hold a killed game left behind is undone first, as launch.sh does)
  "$kit/tools/displaymode" restore >> "$home/logs/displaymode.log" 2>&1 || true
  read -r dw dh hz < <("$kit/tools/displaymode" current 2>/dev/null || true)
  # A map test's screen as the Steam Library's Black Ops III (launch.sh,
  # tools/steam-games.sh BOIII_SCREEN): the desktop's size at the rate of the
  # mode the map test's hold (mt_watch) will use, as launch.sh: displaymode
  # plan, the hold's own rule (a scaled 2560x1440 HiDPI desktop at 154 Hz:
  # its 1x mode's 160 Hz; an unscaled HiDPI desktop kept: its own rate)
  [ -n "${DISPLAY_MODE+x}" ] ||
    DISPLAY_MODE=$(sed -n 's/^[[:space:]]*DISPLAY_MODE[[:space:]]*=[[:space:]]*\([0-9]*\).*/\1/p' \
                   "$home/settings.conf" 2> /dev/null | head -n 1)
  # (KEEP_HIDPI, 1 by default as in launch.sh: an unscaled HiDPI desktop stays)
  [ -n "${KEEP_HIDPI+x}" ] ||
    KEEP_HIDPI=$(sed -n 's/^[[:space:]]*KEEP_HIDPI[[:space:]]*=[[:space:]]*\([0-9]*\).*/\1/p' \
                 "$home/settings.conf" 2> /dev/null | head -n 1)
  if [ "${DISPLAY_MODE:-1}" != 0 ] && [ -n "${dw:-}" ] && [ -n "${dh:-}" ]; then
    case "${KEEP_HIDPI:-1}" in 0) mt_keep=0 ;; 2) mt_keep=2 ;; *) mt_keep=1 ;; esac
    read -r _ _ plan_hz _ < <(SIL_KEEP_UNSCALED=$mt_keep "$kit/tools/displaymode" plan "$dw" "$dh" 2> /dev/null || true)
    [[ ${plan_hz:-} =~ ^[1-9][0-9]*$ ]] && hz=$plan_hz
  fi
  dxmt="d3d11.asyncPipelineCompile=True;"
  case "${hz:-}" in [1-9][0-9]*) dxmt="d3d11.preferredMaxFrameRate=$hz;$dxmt" ;; esac
  # The tools' database of assets (gdtdb/gdt.db, the player's own file) keeps
  # the path each source file had: when the workspace's Windows path changes,
  # every asset showed up twice ("Duplicate ... asset"). It is rebuilt then
  # (gdtdb /update, ~20 s at the launcher's start)
  if [ "$(cat "$home/bo3-modtools/.root" 2> /dev/null)" != "$root" ]; then
    rm -f "$ws/gdtdb/gdt.db" "$ws/gdtdb/gdt.db-wal" "$ws/gdtdb/gdt.db-shm"
    printf '%s' "$root" > "$home/bo3-modtools/.root"
  fi
  # Microsoft's Visual C++ 2012 runtime, which Steam downloads with the Mod
  # Tools (Steamworks Shared, _CommonRedist\vcredist\2012) and runs on Windows
  # before their first start: the tools use its Concurrency Runtime, which
  # Wine's msvcr110 leaves unimplemented (Radiant's lighting hung, the linker
  # needs it). Installed once, as Steam does (/quiet /norestart); the other
  # programs of the prefix keep Wine's own (its default load order)
  s32="$WINEPREFIX/drive_c/windows/system32"
  ms_crt() { [ -f "$s32/msvcr110.dll" ] && [ -f "$s32/msvcp110.dll" ] &&
             [ "$(dd if="$s32/msvcr110.dll" bs=1 skip=64 count=16 2> /dev/null)" != "Wine builtin DLL" ] &&
             [ "$(dd if="$s32/msvcp110.dll" bs=1 skip=64 count=16 2> /dev/null)" != "Wine builtin DLL" ]; }
  if ! ms_crt; then
    shared=$(bash "$kit/steam.sh" gamedir 228980)
    redist="$shared/_CommonRedist/vcredist/2012/vcredist_x64.exe"
    [ -f "$redist" ] || die "Microsoft's Visual C++ 2012 runtime is missing from Steam's download: let Steam verify the Mod Tools"
    step "Installing Microsoft's Visual C++ 2012 runtime (from Steam)"
    "$wine" "$(sil_winpath "$redist")" /quiet /norestart > /dev/null 2>&1
    ms_crt || die "Microsoft's Visual C++ 2012 runtime did not install"
  fi
  # Beside the tools in the workspace: msvcr110.dll = ours, forwarding every
  # export to Microsoft's (here as msvcr110_ms.dll) but _resetstkoflw
  # (tools/msvcr110-forward.c). Radiant calls that at start; Microsoft's and
  # Wine's put a guard page in the stack in use, every page below it then
  # faulted once as the stack grew, and under Rosetta 2 one of those faults (a
  # push inside translated code) ended Radiant before its window ("rosetta
  # error: unexpectedly need to EmulateForward on a synchronous exception").
  # It also makes the Concurrency Runtime call FlushProcessWriteBuffers one
  # thread at a time: Wine on macOS reads every thread's registers there, and
  # two threads doing it at once froze for good (the runtime's workers all
  # asleep; Radiant's light bake stopped at random, 2026-11-22). And it lets
  # the asset database's folder watch work (filter 0x1ff includes a change
  # kind Wine refuses: two of Radiant's threads spun, and Radiant never
  # finished closing, so the launcher's Build stopped after Light)
  cmp -s "$kit/payload/bo3-modtools/msvcr110.dll" "$ws/bin/msvcr110.dll" ||
    cp "$kit/payload/bo3-modtools/msvcr110.dll" "$ws/bin/msvcr110.dll" || die "could not prepare the Mod Tools' runtime"
  cmp -s "$s32/msvcr110.dll" "$ws/bin/msvcr110_ms.dll" ||
    cp "$s32/msvcr110.dll" "$ws/bin/msvcr110_ms.dll" || die "could not prepare the Mod Tools' runtime"
  # The asset database's tray program (bin\GdtDBTray.exe, which the tools
  # start as bin\GdtDBTray.<n>.tmp) is 32-bit: Microsoft's 32-bit runtime too
  # (Steam runs both installers), and our 32-bit msvcr110 in its place in
  # Steam's prefix (syswow64; the tray finds the tools' 64-bit one in bin
  # first and passes it by), Microsoft's beside it as msvcr110_ms.dll
  # (tools/msvcr110-forward.c, 32-bit build; Microsoft's file kept as
  # msvcr110.dll.sil-original). Only the tray uses it (overrides below):
  # Wine's own msvcr110 does not defer to another file there, so every other
  # program of the prefix keeps Wine's. It makes the tray's folder watch work
  # (as Radiant's above) and fixes how a read of gdtDb's output that fails
  # (gdtDb has ended) reports itself: Wine signalled it as finished, the
  # tray's log line for that case crashed it, and "GdtDBTray.0.tmp has
  # encountered a serious problem" showed at every start of the tools
  # (2026-11-22)
  s64="$WINEPREFIX/drive_c/windows/syswow64"
  wine_dll() { [ "$(dd if="$1" bs=1 skip=64 count=16 2> /dev/null)" = "Wine builtin DLL" ]; }
  x86=$kit/payload/bo3-modtools/msvcr110-x86.dll
  if ! { [ -f "$s64/msvcr110_ms.dll" ] && ! wine_dll "$s64/msvcr110_ms.dll" &&
         [ -f "$s64/msvcp110.dll" ] && ! wine_dll "$s64/msvcp110.dll"; }; then
    # ours there but Microsoft's missing: its file back first (or Wine's)
    cmp -s "$x86" "$s64/msvcr110.dll" && [ -f "$s64/msvcr110.dll.sil-original" ] &&
      cp -p "$s64/msvcr110.dll.sil-original" "$s64/msvcr110.dll"
    if wine_dll "$s64/msvcr110.dll" || wine_dll "$s64/msvcp110.dll"; then
      redist="$(bash "$kit/steam.sh" gamedir 228980)/_CommonRedist/vcredist/2012/vcredist_x86.exe"
      [ -f "$redist" ] || die "Microsoft's Visual C++ 2012 runtime (32-bit) is missing from Steam's download: let Steam verify the Mod Tools"
      step "Installing Microsoft's Visual C++ 2012 runtime, 32-bit (from Steam)"
      "$wine" "$(sil_winpath "$redist")" /quiet /norestart > /dev/null 2>&1
    fi
    { ! wine_dll "$s64/msvcr110.dll" && ! cmp -s "$x86" "$s64/msvcr110.dll" &&
      cp -p "$s64/msvcr110.dll" "$s64/msvcr110_ms.dll"; } ||
      die "Microsoft's Visual C++ 2012 runtime (32-bit) did not install"
  fi
  if ! cmp -s "$x86" "$s64/msvcr110.dll"; then
    [ -e "$s64/msvcr110.dll.sil-original" ] || cp -p "$s64/msvcr110.dll" "$s64/msvcr110.dll.sil-original"
    cp "$x86" "$s64/msvcr110.dll" || die "could not prepare the Mod Tools' runtime (32-bit)"
  fi
  # Textures: the tools convert their TIFF images to 64-bit RGBA through WIC,
  # which Wine could not do from 16-bit gray, 24-bit BGR or 32-bit BGRA (no
  # texture loaded; Radiant crashed loading a map). Our windowscodecs.dll
  # (patches/wine-windowscodecs-64bpprgba.patch) goes where COM loads it from,
  # Steam's prefix system32 (Wine's own kept as windowscodecs.dll.sil-original);
  # only the tools below use it (per-exe overrides), every other program keeps
  # the engine's builtin one (Wine's default load order)
  if ! cmp -s "$kit/payload/bo3-modtools/windowscodecs.dll" "$s32/windowscodecs.dll"; then
    [ -e "$s32/windowscodecs.dll.sil-original" ] || cp -p "$s32/windowscodecs.dll" "$s32/windowscodecs.dll.sil-original"
    cp "$kit/payload/bo3-modtools/windowscodecs.dll" "$s32/windowscodecs.dll" || die "could not prepare the Mod Tools' image converter"
  fi
  # Radiant's Direct3D 11 beside it (bin\d3d11.dll; Radiant only, the other
  # tools keep the engine's: overrides below): the engine's DXMT with
  # patches/dxmt-discard-flush, which sends DXMT's pending work to the GPU
  # after 1024 buffers renamed by DISCARD maps (DXMT's own profile for
  # Radiant_modtools.exe). Radiant's light bake without a window (the
  # launcher's Light) maps one constant buffer with DISCARD ~80,000 times a
  # second and never flushes or presents; DXMT reuses a renamed buffer only
  # once the GPU has finished the work it was renamed in, which was never
  # sent, so Radiant took a new Metal buffer every few maps (+250-400 MB/s;
  # once 74 GB with the swap full, 2026-11-22). The games keep the engine's DXMT
  cmp -s "$kit/payload/bo3-modtools/d3d11.dll" "$ws/bin/d3d11.dll" ||
    cp "$kit/payload/bo3-modtools/d3d11.dll" "$ws/bin/d3d11.dll" || die "could not prepare Radiant's Direct3D 11"
  # Radiant's lighting ray-traces with Intel Embree (bin\embree64r.dll), which
  # pins each of its worker threads with SetThreadIdealProcessorEx and gives
  # up after the first one when that fails; Wine's is a stub that fails, and
  # Embree's scene build then waited for the missing workers for good (the
  # bake stopped at "Probes...."). bin\embree64r.dll = ours
  # (tools/embree-forward.c): every export forwarded to Steam's, here as
  # embree64r_steam.dll (an APFS clone), with that one call made to work
  cmp -s "$kit/payload/bo3-modtools/embree64r.dll" "$ws/bin/embree64r.dll" ||
    cp "$kit/payload/bo3-modtools/embree64r.dll" "$ws/bin/embree64r.dll" || die "could not prepare Radiant's ray tracer"
  cmp -s "$tools/bin/embree64r.dll" "$ws/bin/embree64r_steam.dll" ||
    { rm -f "$ws/bin/embree64r_steam.dll"; cp -c "$tools/bin/embree64r.dll" "$ws/bin/embree64r_steam.dll" 2> /dev/null ||
      cp "$tools/bin/embree64r.dll" "$ws/bin/embree64r_steam.dll"; } || die "could not prepare Radiant's ray tracer"
  # A map's sounds: the linker builds its sound zone with sound\snd_convert.exe
  # (.NET; Wine Mono here). Its classes are marked beforefieldinit, which lets
  # a runtime run their static constructors early: Mono's JIT ran them while
  # compiling Main, before Main had read the folders from its command line,
  # SoundData's then combined a null folder (ArgumentNullException), no sound
  # zone was written, the link ended with an error (80/208) and maps had none
  # of their own sounds (2026-11-22). Microsoft's runtime runs them at first
  # use. The workspace's copy has that flag cleared on the 16 classes with a
  # static constructor (one bit each), so Mono runs them at first use too: for
  # the Steam release the kit knows (SHA-256), any other stays as Steam's
  snd=$ws/sound/snd_convert.exe
  snd_steam=03ee891962a3e57b120f932a31b6a504b9ce4455f2755497db40cc3db59acb06
  snd_ours=9288d792de695786b603a0526479df6a8626c4d78750451b640d26e6ac0d3c42
  if [ "$(shasum -a 256 "$snd" 2> /dev/null | cut -d' ' -f1)" = "$snd_steam" ]; then
    rm -f "$snd.sil" && cp "$snd" "$snd.sil" &&
      for o in 140204 140358 140680 140876 141240 141268 141380 141450 141506 \
               142136 142178 142290 142374 142430 142458 142682; do
        printf '\000' | dd of="$snd.sil" bs=1 seek="$o" count=1 conv=notrunc 2> /dev/null || break
      done
    if [ "$(shasum -a 256 "$snd.sil" 2> /dev/null | cut -d' ' -f1)" = "$snd_ours" ]; then mv -f "$snd.sil" "$snd"
    else rm -f "$snd.sil"; printf '%s\n' "Warning: could not prepare the sound converter (maps keep no sounds of their own)" >> "$log"; fi
  elif [ "$(shasum -a 256 "$snd" 2> /dev/null | cut -d' ' -f1)" != "$snd_ours" ]; then
    printf '%s\n' "Warning: unknown sound converter in Steam's Mod Tools: left as it is" >> "$log"
  fi
  # Radiant's layered-material library (bin\t7_layered_material_library.txt:
  # t7_modtools.prj.json names it, Radiant opens it from its own folder) is not
  # in Steam's download. Without it Radiant took the library as changed, and
  # after the launcher's Light (no window) it asked "...has unsaved changes.
  # Would you like to save?" instead of closing, so the Build never reached
  # Link (2026-11-22). An empty library, as Radiant itself saves one (format
  # version 1, no entries), once: from then on it is the player's file, where
  # Radiant's Layered Material Editor saves (an empty file is "corrupt")
  [ -e "$ws/bin/t7_layered_material_library.txt" ] ||
    printf 'LayeredMaterialLibrary 1\n' > "$ws/bin/t7_layered_material_library.txt" ||
    die "could not prepare Radiant's layered-material library"
  # The community fix the player chose for Black Ops III in the Steam Library
  # (tools/steam-mods.sh, STEAM_MOD_BO3), when it also suits a map test
  # (md_tools: Clean Ops): a map test is the game started from the workspace
  # (the launcher's Run), so the fix goes there while the tools run, as into
  # Steam's folder for Play, and leaves with them (the exit trap above). None
  # or another fix: the game as before (what an earlier start left goes)
  [ -n "${STEAM_MOD_BO3+x}" ] ||
    STEAM_MOD_BO3=$(sed -n 's/^[[:space:]]*STEAM_MOD_BO3[[:space:]]*=[[:space:]]*\([A-Za-z0-9_]*\).*/\1/p' \
                    "$home/settings.conf" 2> /dev/null | head -n 1)
  reg_pending=()
  reg() {   # steam-mods.sh's registry calls (as launch.sh's): into the import below
    local op=$1 key=$2 name= data=
    shift 2
    while [ $# -gt 0 ]; do case "$1" in /v) name=$2; shift 2 ;; /d) data=$2; shift 2 ;; *) shift ;; esac; done
    reg_pending+=("[HKEY_CURRENT_USER\\${key#HKCU\\}]")
    if [ "$op" = add ]; then reg_pending+=("$name=$data"); else reg_pending+=("-$name"); fi
  }
  s_id=bo3 s_part=sp s_exe=BlackOps3.exe s_pad=native s_argv=() steam_x87_programs= m_tools=1
  . "$kit/tools/steam-mods.sh"
  m_record="$home/bo3-modtools/mod-installed.list"
  steam_mod_prepare "$ws" || die "$m_error"
  steam_mod_args "$ws"
  [ "$m_mod" = none ] || printf '%s\n' "Community fix for map tests: $m_mod" >> "$log"
  # A map test runs as the launcher's Steam app: the launcher starts
  # BlackOps3.exe with its own environment (as on Windows), where Steam's
  # sign-in leaves its app ID. A fix whose server checks the game's Steam
  # ticket (md_appid: Clean Ops takes Black Ops III's only, and closed the
  # game) needs the game's: the launcher then runs as that app (Steam shows the
  # tools as Black Ops III). Tried first (2026-11-23): the launcher from bin\
  # with a steam_appid.txt naming the tools and one naming Black Ops III where
  # the map test starts; Steam still counted the game as the tools' (455130)
  # and Clean Ops refused it again. None or another fix: the tools' app
  mt_app=$app
  if [ "$m_mod" != none ] && steam_mod_def "$m_mod" && [ -n "$md_appid" ]; then mt_app=$md_appid; fi
  # The Steam Library's cursor fix (launch.sh: an invisible Mac cursor, the Dock
  # and menu bar hidden) stays in the prefix after a game and reached the
  # tools the launcher starts (logs: "[Si14]: BO2 cursor workaround enabled"):
  # an editor needs the Mac's own pointer. The next game sets it again.
  # Per tool (AppDefaults): Microsoft's runtime (msvcr110 = ours, above) for
  # those that use its Concurrency Runtime; the image converter for those that
  # load textures; Radiant also with Microsoft's dbghelp.dll from bin (Wine's
  # destroyed one heap twice when Radiant's lighting threads used it at once)
  # and with its own Direct3D 11 (above; the other tools: the engine's); the
  # tray program with our 32-bit runtime (above), under each name it runs as
  # A map test's fullscreen through the window compositor, not by capturing
  # the display (the Steam Library's Play sets its own before each start): a
  # captured display left everything black behind a windowed game and the
  # player could not record the screen (2026-11-23)
  # A map test hides on Cmd-Tab like the Steam Library's games (launch.sh
  # SIL_HIDE_ON_DEACTIVATE: only a window that covers the screen, so the
  # tools' own windows never hide); HIDE_ON_CMDTAB=0: off
  # (the desktop's HiDPI mode while it is hidden, SIL_DISPLAYMODE_RECORD: only
  # with CMDTAB_DESKTOP_MODE=1, as in launch.sh; the game stays at 1x)
  unset SIL_HIDE_ON_DEACTIVATE SIL_DISPLAYMODE_RECORD
  if [ "${HIDE_ON_CMDTAB:-1}" != 0 ] && [ "${CMDTAB_DESKTOP_MODE:-0}" = 1 ]; then
    hide_env=(__CX_UNIX_SIL_HIDE_ON_DEACTIVATE=1 "__CX_UNIX_SIL_DISPLAYMODE_RECORD=$home/cache/displaymode-desktop")
    export SIL_HIDE_ON_DEACTIVATE=1 SIL_DISPLAYMODE_RECORD="$home/cache/displaymode-desktop"
  elif [ "${HIDE_ON_CMDTAB:-1}" != 0 ]; then
    hide_env=(__CX_UNIX_SIL_HIDE_ON_DEACTIVATE=1 -__CX_UNIX_SIL_DISPLAYMODE_RECORD)
    export SIL_HIDE_ON_DEACTIVATE=1
  else hide_env=(-__CX_UNIX_SIL_HIDE_ON_DEACTIVATE -__CX_UNIX_SIL_DISPLAYMODE_RECORD); fi
  ov='HKEY_CURRENT_USER\Software\Wine\AppDefaults'
  tray=("[$ov\\GdtDBTray.exe\\DllOverrides]" msvcr110=native,builtin)
  for n in 0 1 2 3 4 5 6 7 8 9; do tray+=("[$ov\\GdtDBTray.$n.tmp\\DllOverrides]" msvcr110=native,builtin); done
  reg_import "${tray[@]}" '[HKEY_CURRENT_USER\Environment]' \
             "TA_GAME_PATH=$root" "TA_TOOLS_PATH=$root" "TA_LOCAL_ASSET_CACHE=${root}share\\assetconvert\\" \
             CX_GRAPHICS_BACKEND=dxmt "DXMT_CONFIG=$dxmt" -__CX_UNIX_SIL_BO2_TRANSPARENT_CURSOR \
             "${hide_env[@]}" \
             "[$ov\\Radiant_modtools.exe\\DllOverrides]" msvcr110=native,builtin msvcp110=native,builtin \
               windowscodecs=native,builtin dbghelp=native,builtin d3d11=native,builtin \
             "[$ov\\asseteditor_modtools.exe\\DllOverrides]" msvcr110=native,builtin msvcp110=native,builtin \
               windowscodecs=native,builtin d3d11=builtin \
             "[$ov\\cod2map64.exe\\DllOverrides]" msvcr110=native,builtin msvcp110=native,builtin \
               windowscodecs=native,builtin d3d11=builtin \
             "[$ov\\linker_modtools.exe\\DllOverrides]" msvcr110=native,builtin msvcp110=native,builtin d3d11=builtin \
             "[$ov\\umbraconvert.exe\\DllOverrides]" windowscodecs=native,builtin \
             "[$ov\\BlackOps3.exe\\Mac Driver]" CaptureDisplaysForFullscreen=n \
             ${reg_pending[@]+"${reg_pending[@]}"}
  unset SIL_BO2_TRANSPARENT_CURSOR __CX_UNIX_SIL_BO2_TRANSPARENT_CURSOR
  # The linker hung for good after its first image with all 10 cores of an
  # M1 Pro shown to it (0 % CPU; ProtonDB reports the same on Linux): with the
  # performance cores only (8 there) it links (mp_cube: 16.9 s; 4 cores:
  # 23.2 s). Every tool started from here inherits it
  pcores=$(sysctl -n hw.perflevel0.logicalcpu 2> /dev/null || sysctl -n hw.ncpu)
  case "$pcores" in
    [1-9]|[1-9][0-9]) cpus=$(seq -s, 0 $((pcores - 1))); export WINE_CPU_TOPOLOGY="$pcores:${cpus%,}" ;;
  esac
  # A map test starts Black Ops III: Media Foundation's video decoders through
  # the engine's GStreamer, as for the Steam Library's Black Ops III
  export GST_PLUGIN_SYSTEM_PATH_1_0="$engine/lib64/gstreamer-1.0" GST_PLUGIN_PATH_1_0= \
         GST_REGISTRY_1_0="$home/cache/gstreamer-registry.bin"
  # macOS Game Mode, as for the games (tools/game-bundle.sh; GAME_MODE=0 in
  # settings.conf: off): the launcher runs on the "Siliconium Game" loader
  # (WINELOADER), and so does a map test. Wine starts every program another
  # one starts on its own loader, whatever the parent runs on (tested
  # 2026-11-23: the map test ran on it, no Game Mode); the one hook it has
  # per program (X87_SIDECAR_PROGRAMS, read from the launcher's environment)
  # starts BlackOps3.exe through payload/bo3-modtools/bundle-exec, which puts
  # the game on WINELOADER's loader (no x87 sidecar: a 64-bit game). The other
  # tools stay windowed on Wine's loader; Steam and the setup above stay on
  # the engine's own loader
  [ -n "${GAME_MODE+x}" ] ||
    GAME_MODE=$(sed -n 's/^[[:space:]]*GAME_MODE[[:space:]]*=[[:space:]]*\([0-9]*\).*/\1/p' \
                "$home/settings.conf" 2> /dev/null | head -n 1)
  . "$kit/tools/game-bundle.sh"
  mt_wine=$wine gm_env=(-u WINELOADER -u X87_SIDECAR_PATH -u X87_SIDECAR_PROGRAMS)
  # The map test's hook is on (the player's choice, 2026-11-24: the map test
  # runs as "Siliconium Game", in Game Mode, as the Steam Library's games);
  # MODTOOLS_GAME_MODE=0 in settings.conf: the game on Wine's own loader
  [ -n "${MODTOOLS_GAME_MODE+x}" ] ||
    MODTOOLS_GAME_MODE=$(sed -n 's/^[[:space:]]*MODTOOLS_GAME_MODE[[:space:]]*=[[:space:]]*\([0-9]*\).*/\1/p' \
                         "$home/settings.conf" 2> /dev/null | head -n 1)
  if [ "${GAME_MODE:-1}" != 0 ] && gb=$(game_bundle "$wine"); then
    mt_wine=$gb
    gm_env=(-u X87_SIDECAR_PATH -u X87_SIDECAR_PROGRAMS WINELOADER="$gb")
    if [ "${MODTOOLS_GAME_MODE:-1}" != 0 ] && [ -x "$kit/payload/bo3-modtools/bundle-exec" ]; then
      gm_env=(WINELOADER="$gb" X87_SIDECAR_PATH="$kit/payload/bo3-modtools/bundle-exec" X87_SIDECAR_PROGRAMS=BlackOps3.exe)
    fi
  fi
  # A map test's screen as the Steam Library's Black Ops III (BOIII_SCREEN):
  # fullscreen at the desktop's size and rate, written before each start, in
  # the workspace's own settings (players/config.ini, Key = "value" // range).
  # A map test at another size (1920x1080 on a 2560x1440 desktop) made Wine
  # switch the display's mode: seconds of black screen at each Cmd-Tab
  mt_ini() {   # <key> <value>
    local f="$ws/players/config.ini" tmp
    [ -f "$f" ] && tmp=$(mktemp "$f.XXXXXX") || return 0
    K="$1" V="$2" awk '
      BEGIN { k = ENVIRON["K"]; v = ENVIRON["V"] }
      !done && index($0, k " = \"") == 1 {
        rest = substr($0, length(k) + 5); q = index(rest, "\"")
        if (q) { print k " = \"" v "\"" substr(rest, q + 1); done = 1; next }
      }
      { print }
      END { if (!done) printf "%s = \"%s\"\r\n", k, v }
    ' "$f" > "$tmp" && mv -f "$tmp" "$f" || rm -f "$tmp"
  }
  [ -n "${BOIII_SCREEN+x}" ] ||
    BOIII_SCREEN=$(sed -n 's/^[[:space:]]*BOIII_SCREEN[[:space:]]*=[[:space:]]*\([0-9]*\).*/\1/p' \
                   "$home/settings.conf" 2> /dev/null | head -n 1)
  if [ "${BOIII_SCREEN:-1}" != 0 ] && [ -n "${dw:-}" ] && [ -n "${dh:-}" ]; then
    mt_ini FullScreenMode 1
    mt_ini WindowSize "${dw}x$dh"
    [ -n "${hz:-}" ] && { mt_ini RefreshRate "$hz"; mt_ini MaxFPS "$hz"; }
  fi
  # While a map test runs, as for the Steam Library's games (launch.sh): the
  # display held as for the Steam Library's games (launch.sh hold_1x_size: an
  # unscaled HiDPI desktop kept, a scaled one at 1x), and the focus helper
  # (payload/iw6/iw6-focus), which restores the game's window at once after
  # Cmd-Tab. Each map test gets its own; they end with it
  [ -n "${KEEP_HIDPI+x}" ] ||
    KEEP_HIDPI=$(sed -n 's/^[[:space:]]*KEEP_HIDPI[[:space:]]*=[[:space:]]*\([0-9]*\).*/\1/p' \
                 "$home/settings.conf" 2> /dev/null | head -n 1)
  mt_watch() {
    local g keep
    # (as launch.sh's hold_1x_size: a scaled desktop held at 1x; KEEP_HIDPI=2 keeps it)
    case "${KEEP_HIDPI:-1}" in 0) keep=0 ;; 2) keep=2 ;; *) keep=1 ;; esac
    while :; do
      g=$(pgrep -f '\\BlackOps3\.exe' | head -n 1)
      if [ -z "$g" ]; then
        pgrep -f "$tools_re" > /dev/null || return 0
        sleep 1; continue
      fi
      ( while pgrep -qf '\\BlackOps3\.exe'; do sleep 2; done ) > /dev/null 2>&1 &
      local waiter=$!
      if [ "${DISPLAY_MODE:-1}" != 0 ] && [ -n "${dw:-}" ] && [ -n "${dh:-}" ]; then
        SIL_KEEP_UNSCALED=$keep "$kit/tools/displaymode" "$dw" "$dh" "$waiter" >> "$home/logs/displaymode.log" 2>&1 &
      fi
      if [ -x "$kit/payload/iw6/iw6-focus" ] && [ -f "$kit/payload/iw6/iw6-restore.exe" ]; then
        SIL_FOCUS_FROM="io.github.siliconium:Steam.exe:modlauncher.exe" \
          "$kit/payload/iw6/iw6-focus" 0 "$wine" "$kit/payload/iw6/iw6-restore.exe" BlackOps3.exe >> "$log" 2>&1 &
        local fp=$!
      fi
      wait "$waiter"
      [ -n "${fp:-}" ] && kill "$fp" 2> /dev/null
      fp=
    done
  }
  printf '%s\n' "--- $(date) Mod Tools: $ws ($root)${gb:+ [Game Mode loader]}" >> "$log"
  step "Opening the Mod Tools"
  # Started directly with Steam's app ID (the tools', or a fix's: above), as
  # the Steam Library starts its games, by its path on the workspace's drive:
  # the process then names it, as the tools it starts do (with "./bin/…" the
  # wait below did not see it)
  (cd "$ws" && env "${gm_env[@]}" SteamAppId=$mt_app SteamGameId=$mt_app "$mt_wine" "${root}bin\\modlauncher.exe" >> "$log" 2>&1 &)
  # Every tool runs from the workspace (bin\…), and a map test is the game
  # from there: wait until none of them is left
  tools_re=$(sil_copy_exe bo3-modtools)
  for _ in $(seq 1 60); do pgrep -f "$tools_re" > /dev/null && break; sleep 1; done
  pgrep -f "$tools_re" > /dev/null || die "the Mod Tools did not start (see logs/bo3-modtools.log)"
  # (mt_watch matches the game by its process name, "P:\\BlackOps3.exe": the helpers name it without a folder)
  mt_watch &
  # The launcher's own window as a game's (launch.sh focus_helper): in front
  # when it appears (if Siliconium or Steam still is) and restored at once
  # after Cmd-Tab; it ends with the launcher
  lfp=
  if [ -x "$kit/payload/iw6/iw6-focus" ] && [ -f "$kit/payload/iw6/iw6-restore.exe" ]; then
    SIL_FOCUS_FROM="io.github.siliconium:Steam.exe" \
      "$kit/payload/iw6/iw6-focus" 0 "$wine" "$kit/payload/iw6/iw6-restore.exe" modlauncher.exe >> "$log" 2>&1 &
    lfp=$!
  fi
  while pgrep -f "$tools_re" > /dev/null; do sleep 2; done
  [ -n "$lfp" ] && kill "$lfp" 2> /dev/null
  # The tray program stays on after the tools (on Windows it sits in the
  # notification area; the next start of the tools ends it and starts a new
  # one): ended with them, as Windows ends a program (TerminateProcess)
  pgrep -fl 'GdtDBTray\.[0-9]+\.tmp' 2> /dev/null | grep -o 'GdtDBTray\.[0-9]*\.tmp' | sort -u |
    while IFS= read -r t; do "$wine" taskkill /F /IM "$t" > /dev/null 2>&1; done
  printf '%s\n' "--- $(date) Mod Tools closed" >> "$log"
  ;;
*)
  die "usage: bo3-modtools.sh status | work [--reveal] | start"
  ;;
esac
