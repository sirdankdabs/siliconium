/* Siliconium: pad-mapper.exe, controller support for the Steam Library's games
 * that have none on PC (Call of Duty 1, 2, 4, World at War, Modern Warfare 2
 * and 3, Black Ops). It reads the controller through XInput (Wine's: every
 * controller Siliconium supports, PlayStation ones mapped by configure-ds4.sh)
 * and plays it as keyboard and mouse into the game, with SendInput: the game
 * files are not touched, and the keyboard and mouse keep working alongside.
 *
 * Console layout, with the games' default PC bindings:
 *   left stick     move (W A S D)          right stick   aim (mouse), curved
 *   RT / LT        fire / aim down sights  RB / LB       frag (G) / special (4)
 *   A              jump (Space)            B             crouch (C), hold: prone (Ctrl)
 *   X              reload (R) and use (F)  Y             next weapon (mouse wheel)
 *   L3             sprint (Shift)          R3            melee (V)
 *   D-pad          up: night vision / 1 (N, 1), left 3, right 5, down 2
 *   Start          menu (Esc)              Back          scores / objectives (Tab)
 *   In menus the right stick moves the pointer and RT clicks.
 *
 *   pad-mapper.exe <seconds> [ads-key]   runs that long (the app ends it with the game)
 *
 * ads-key: LT holds numpad 0 (KP_INS), which launch.sh binds to "+speed_throw"
 * (aim while held): the games bind the right mouse button to toggle aiming,
 * which a trigger should not do. ads-toggle (a first start, before the game has
 * saved its bindings): LT clicks the right mouse button on press and on
 * release, so the toggle follows the trigger. Without either LT is the right
 * mouse button.
 *
 * Built with: zig cc -target x86-windows-gnu -O2 -s -Wl,--subsystem,windows -o pad-mapper.exe pad-mapper.c -luser32 -lwinmm
 */
#include <windows.h>
#include <math.h>
#include <stdlib.h>

typedef struct { WORD buttons; BYTE lt, rt; SHORT lx, ly, rx, ry; } PAD;
typedef struct { DWORD packet; PAD pad; } PADSTATE;
typedef DWORD (WINAPI *GETSTATE)(DWORD, PADSTATE *);

#define B_UP 0x0001
#define B_DOWN 0x0002
#define B_LEFT 0x0004
#define B_RIGHT 0x0008
#define B_START 0x0010
#define B_BACK 0x0020
#define B_L3 0x0040
#define B_R3 0x0080
#define B_LB 0x0100
#define B_RB 0x0200
#define B_A 0x1000
#define B_B 0x2000
#define B_X 0x4000
#define B_Y 0x8000

/* scan codes (set 1): DirectInput reads these */
enum { SC_ESC = 0x01, SC_1 = 0x02, SC_2 = 0x03, SC_3 = 0x04, SC_4 = 0x05, SC_5 = 0x06, SC_TAB = 0x0F,
       SC_W = 0x11, SC_R = 0x13, SC_A = 0x1E, SC_S = 0x1F, SC_D = 0x20, SC_F = 0x21, SC_G = 0x22,
       SC_KP0 = 0x52, SC_CTRL = 0x1D, SC_SHIFT = 0x2A, SC_C = 0x2E, SC_V = 0x2F, SC_N = 0x31, SC_SPACE = 0x39 };

static void key(WORD scan, int down)
{
    INPUT in = { 0 };
    in.type = INPUT_KEYBOARD;
    /* the virtual key and the scan code both: Wine's keyboard state, window
       messages and DirectInput then agree (a scan code alone lost releases) */
    in.ki.wVk = (WORD)MapVirtualKeyW(scan, MAPVK_VSC_TO_VK);
    in.ki.wScan = scan;
    in.ki.dwFlags = down ? 0 : KEYEVENTF_KEYUP;
    SendInput(1, &in, sizeof in);
}
static void mouse(DWORD flags, LONG dx, LONG dy, DWORD data)
{
    INPUT in = { 0 };
    in.type = INPUT_MOUSE;
    in.mi.dx = dx; in.mi.dy = dy; in.mi.mouseData = data; in.mi.dwFlags = flags;
    SendInput(1, &in, sizeof in);
}

/* a key held while a condition holds. A release the mapper makes is sent
   once more 150 ms later (Wine could lose it); keys the player presses on the
   keyboard are never touched. */
#define MAXKEYS 32
static struct { WORD scan; DWORD at; } again[MAXKEYS];
static void release_again(WORD scan)
{
    for (int i = 0; i < MAXKEYS; i++)
        if (!again[i].scan || again[i].scan == scan) { again[i].scan = scan; again[i].at = GetTickCount() + 150; return; }
}
static void hold(int *was, int now, WORD scan)
{
    if (now == *was) return;
    key(scan, now);
    *was = now;
    if (!now) release_again(scan);
}
static void releases_due(const int *held_w, const int *held_a, const int *held_s, const int *held_d)
{
    (void)held_w; (void)held_a; (void)held_s; (void)held_d;
    DWORD now = GetTickCount();
    for (int i = 0; i < MAXKEYS; i++)
        if (again[i].scan && (LONG)(now - again[i].at) >= 0) { key(again[i].scan, 0); again[i].scan = 0; }
}

static double axis(SHORT v, double dead)
{
    double a = v / 32767.0;
    if (a > 1) a = 1;
    if (a < -1) a = -1;
    double m = fabs(a);
    if (m < dead) return 0;
    m = (m - dead) / (1 - dead);
    return a < 0 ? -m : m;
}

int WINAPI WinMain(HINSTANCE instance, HINSTANCE previous, LPSTR command_line, int show)
{
    (void)instance; (void)previous; (void)show;
    HMODULE x = LoadLibraryA("xinput1_4.dll");
    if (!x) x = LoadLibraryA("xinput1_3.dll");
    if (!x) return 1;
    GETSTATE get = (GETSTATE)GetProcAddress(x, "XInputGetState");
    if (!get) return 1;
    int seconds = atoi(command_line);
    int ads_key = strstr(command_line, "ads-key") != NULL;
    int ads_toggle = !ads_key && strstr(command_line, "ads-toggle") != NULL;
    if (seconds <= 0) seconds = 21600;
    const DWORD end = GetTickCount() + (DWORD)seconds * 1000;
    timeBeginPeriod(1);

    int w = 0, a = 0, s = 0, d = 0, jump = 0, crouch = 0, prone = 0, reload = 0, sprint = 0, melee = 0;
    int frag = 0, special = 0, esc = 0, tab = 0, up = 0, left = 0, right = 0, down = 0, fire = 0, ads = 0, next = 0;
    DWORD b_down_at = 0, edge_since = 0, still_since = GetTickCount();
    int last_rx = 0, last_ry = 0, rest_x = 0, rest_y = 0;
    int connected = 0;
    DWORD connected_at = 0;
    double fx = 0, fy = 0, vx = 0, vy = 0;
    /* XInput through Wine is not free: 125 updates a second while the
       controller is in use, 30 while it rests (sticks centred, nothing held) */
    const int tick = 8;
    DWORD last_packet = 0, idle_since = GetTickCount();

    while ((LONG)(end - GetTickCount()) > 0) {
        PADSTATE st;
        DWORD pad = 0;
        for (; pad < 4; pad++) if (get(pad, &st) == 0) break;
        if (pad == 4) {   /* no controller: let go of everything */
            memset(&st, 0, sizeof st);
            Sleep(250);
        }
        /* a controller that has just connected reports stale sticks for a
           moment (a jolt of the view): ignore it for half a second */
        if (pad != 4 && !connected) { connected = 1; connected_at = GetTickCount(); }
        if (pad == 4) connected = 0;
        if (connected && GetTickCount() - connected_at < 500) { memset(&st.pad, 0, sizeof st.pad); still_since = GetTickCount(); }
        PAD p = st.pad;
        WORD bt = p.buttons;

        /* movement: the left stick as W A S D (a quarter of the way) */
        double lx = axis(p.lx, 0.24), ly = axis(p.ly, 0.24);
        hold(&w, ly > 0.25, SC_W); hold(&s, ly < -0.25, SC_S);
        hold(&a, lx < -0.25, SC_A); hold(&d, lx > 0.25, SC_D);
        releases_due(&w, &a, &s, &d);

        /* aim: the right stick as mouse movement, curved for precision */
        /* drift: a stick resting off centre (worn sticks) would turn the view
           by itself. When it has stayed still, a little off centre, for 3 s,
           that point becomes its centre; then a radial dead zone. */
        DWORD tnow = GetTickCount();
        if (abs(p.rx - last_rx) > 700 || abs(p.ry - last_ry) > 700) { last_rx = p.rx; last_ry = p.ry; still_since = tnow; }
        double rawx = (p.rx - rest_x) / 32767.0, rawy = (p.ry - rest_y) / 32767.0;
        if (tnow - still_since > 3000 && sqrt((p.rx / 32767.0) * (p.rx / 32767.0) + (p.ry / 32767.0) * (p.ry / 32767.0)) < 0.15) {
            rest_x = p.rx; rest_y = p.ry; rawx = rawy = 0;
        }
        double rmag = sqrt(rawx * rawx + rawy * rawy), rx = 0, ry = 0;
        if (rmag > 0.16) {
            double scaled = fmin(1.0, (rmag - 0.16) / (1 - 0.16));
            rx = rawx / rmag * scaled; ry = rawy / rmag * scaled;
        }
        double cx = rx * fabs(rx), cy = ry * fabs(ry);
        /* acceleration as on the consoles: the aim speed builds up to the
           stick's instead of jumping to it (about 0.15 s), slows down at once,
           and held at full tilt the turn speeds up by half over 0.4 s */
        DWORD now = GetTickCount();
        double mag = sqrt(rx * rx + ry * ry);
        if (mag > 0.93) { if (!edge_since) edge_since = now; } else edge_since = 0;
        double boost = edge_since ? 1.0 + 0.5 * fmin(1.0, (now - edge_since) / 400.0) : 1.0;
        double tx = cx * boost, ty = cy * boost;
        vx += (fabs(tx) > fabs(vx) && tx * vx >= 0) ? (tx - vx) * 0.12 : (tx - vx) * 0.6;
        vy += (fabs(ty) > fabs(vy) && ty * vy >= 0) ? (ty - vy) * 0.12 : (ty - vy) * 0.6;
        if (!rx && fabs(vx) < 0.01) vx = 0;
        if (!ry && fabs(vy) < 0.01) vy = 0;
        fx += vx * 22.0;          /* counts per 8 ms tick at full tilt (~260 degrees/s at sensitivity 5) */
        fy += -vy * 11.0;         /* up/down slower, as on the consoles */
        LONG mx = (LONG)fx, my = (LONG)fy;
        if (mx || my) { mouse(MOUSEEVENTF_MOVE, mx, my, 0); fx -= mx; fy -= my; }

        int rt = p.rt > 40, lt = p.lt > 40;
        if (rt != fire) { mouse(rt ? MOUSEEVENTF_LEFTDOWN : MOUSEEVENTF_LEFTUP, 0, 0, 0); fire = rt; }
        if (lt != ads) {
            if (ads_key) { key(SC_KP0, lt); if (!lt) release_again(SC_KP0); }
            else if (ads_toggle) { mouse(MOUSEEVENTF_RIGHTDOWN, 0, 0, 0); Sleep(20); mouse(MOUSEEVENTF_RIGHTUP, 0, 0, 0); }
            else mouse(lt ? MOUSEEVENTF_RIGHTDOWN : MOUSEEVENTF_RIGHTUP, 0, 0, 0);
            ads = lt;
        }

        hold(&jump, !!(bt & B_A), SC_SPACE);
        /* B: crouch on a tap, prone when held */
        int bnow = !!(bt & B_B);
        if (bnow && !b_down_at) b_down_at = GetTickCount();
        if (bnow && b_down_at && !prone && GetTickCount() - b_down_at > 350) { key(SC_CTRL, 1); key(SC_CTRL, 0); prone = 1; }
        if (!bnow && b_down_at) {
            if (!prone) { key(SC_C, 1); Sleep(15); key(SC_C, 0); }
            b_down_at = 0; prone = 0;
        }
        (void)crouch;
        int xnow = !!(bt & B_X);
        if (xnow != reload) { key(SC_R, xnow); key(SC_F, xnow); reload = xnow; }
        int ynow = !!(bt & B_Y);
        if (ynow && !next) mouse(MOUSEEVENTF_WHEEL, 0, 0, (DWORD)-WHEEL_DELTA);
        next = ynow;
        hold(&sprint, !!(bt & B_L3), SC_SHIFT);
        hold(&melee, !!(bt & B_R3), SC_V);
        hold(&frag, !!(bt & B_RB), SC_G);
        hold(&special, !!(bt & B_LB), SC_4);
        hold(&esc, !!(bt & B_START), SC_ESC);
        hold(&tab, !!(bt & B_BACK), SC_TAB);
        int unow = !!(bt & B_UP);
        if (unow != up) { key(SC_N, unow); key(SC_1, unow); up = unow; }
        hold(&left, !!(bt & B_LEFT), SC_3);
        hold(&right, !!(bt & B_RIGHT), SC_5);
        hold(&down, !!(bt & B_DOWN), SC_2);

        if (pad != 4) {
            int busy = bt || p.lt > 40 || p.rt > 40 || lx || ly || rx || ry || st.packet != last_packet;
            last_packet = st.packet;
            if (busy) idle_since = GetTickCount();
            Sleep(GetTickCount() - idle_since > 500 ? 33 : tick);
        }
    }
    timeEndPeriod(1);
    return 0;
}
