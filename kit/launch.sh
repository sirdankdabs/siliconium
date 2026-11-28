#!/bin/bash
# Siliconium: start World at War (t4), Black Ops (t5), Black Ops II (t6) or
# Modern Warfare 3 (iw5) through Plutonium, and Modern Warfare 2 (iw4) through
# IW4X, on the Siliconium engine (install-engine.sh) in its prefix (setup-prefix.sh).
#
#   launch.sh waw|bo1|bo2|iw5 online      Open Plutonium to manage its session
#   launch.sh waw|bo1|bo2|iw5 <mode> [name] [--lan]
#                                         Use the saved Plutonium session by default
#   launch.sh bo2 declassified [name]          offline Zombies with the Zombies
#                                         Declassified mod (zombies-declassified.sh)
#   launch.sh iw4 play|launcher [name]    Modern Warfare 2 through the IW4X launcher
#   launch.sh iw6 play                     Ghosts campaign in its own prefix
#   launch.sh stop                         stop everything
#
# Settings come from $SIL_HOME/settings.conf (NAME=value lines; the
# environment wins):
#   BO1_DIR, BO2_DIR, IW5_DIR, IW4_DIR   game folders
#   MAXFPS             frame-rate cap (default: the display's refresh rate; 0: none)
#   X87=0              no x87 acceleration
#   CONSOLE_AIM=0      leave the games' controller aim settings as they are
#   SDL_STICKS=0       keep individual stick reports for SDL gamepads
#   SWITCH_STICKS=0    legacy equivalent of SDL_STICKS=0
#   BO1_SWITCH_STICKS=0 disable SDL stick batching for Black Ops only
#   STICK_DEADZONE     stick deadzone (default 0.08)
#   RAW_INPUT=0        keep the games' raw_input (default: on)
#   STREAM=1           keep BO1's texture streaming (default: off)
#   Patches (on unless set to the value shown):
#   EXEC_ON_DEMAND=0   DEP-off code made executable all at once (BO2 slow motion)
#   RUMBLE_FIX=0       CrossOver's xinput (vibration stalls controller input)
#   CAPTURE_DISPLAY=0  borderless instead of real fullscreen (the games never
#                      capture the display: fullscreen goes through the window
#                      compositor, so the screen can be recorded; owner 2026-11-24)
#   DISPLAY_MODE=0     keep the desktop's display mode while in fullscreen
#   KEEP_HIDPI=0       fullscreen games are held in a 1x mode on an unscaled HiDPI
#                      desktop too (default: an unscaled one, e.g. "looks like
#                      1920x1080" on a 4K panel, keeps its mode; a scaled one goes
#                      to the 1x mode of its size); KEEP_HIDPI=2: scaled ones kept too
#   HIDE_ON_CMDTAB=0   a fullscreen game is not hidden when another app comes to
#                      the front (Cmd-Tab)
#   CMDTAB_DESKTOP_MODE=1  while a game is hidden after Cmd-Tab, a HiDPI desktop
#                      gets its own mode back (two display switches per Cmd-Tab;
#                      default: the game's 1x mode stays until it quits)
#   D3D9_MTLD3D=0      use DXVK + MoltenVK instead of mtld3d (Direct3D 9 -> Metal)
#   MSAA_FIX=0         allow the games' 8x+ MSAA (not supported by Apple GPUs)
#   BO1_ASYNC=0        BO1 shaders compile while drawing (stutters)
#   BO1_ASYNC_LEVEL=1  BO1 compiles a newly drawn surface's shaders on the render
#                      thread (1.3.0: longer first loads, short freezes on new maps)
#   BO1_WARM=0         BO1 shaders compile during play instead of on the loading screen
#   BO1_SHADER_CACHE=0 BO1 keeps no shader caches between runs
#   BO1_MP_FAST_LOAD=0 restore the original T5 Multiplayer shader preparation
#   BO1_METAL_PARALLEL=0  Metal compiles a few shaders at a time
#   BO1_NO_SHADOWS=0   BO1 shadow setting left to the game
#   WAW_SCREEN=0       WaW keeps its own fullscreen resolution and the
#                      game's "Set Optimal Settings?" video detection
#   WAW_WARM=0         WaW compiles shaders while playing instead of warming
#                      them (drawing every material) on the loading screen
#   WAW_XAUDIO=0       WaW uses Wine's XAudio2 2.0 instead of its own (music,
#                      power-ups and the Mystery Box are silent with Wine's)
#   WAW_PIPELINES=0    WaW does not merge the pipeline list shipped for its maps
#   BO1_XAUDIO=0       Wine's XAudio2 (BO1 gunfire is silent)
#   BO1_VIDMEM=0       BO1 sees 128 MB of video memory (low-res textures)
#   BO2_ASYNC=0        BO2 shaders compile while drawing
#   BO2_FRAME_PACING=0 no DXMT frame pacing at the frame-rate cap
#   BO2_MOUSE_LAG_FIX=0 disable Plutonium's high-polling-rate mouse fix in BO2
#   BO2_HW_PROFILE=0   BO2 keeps its own hardware profile
#   BO2_XAUDIO=0       Wine's XAudio2 for BO2 Zombies/MP, Plutonium and Steam (on
#                      some Macs its gunfire and most weapon sounds are silent)
#   BO2_MODS="..."     extra arguments for BO2 offline, e.g. "+set fs_game mods/dlc5"
#   IW5_GRAPHICS=0     Modern Warfare 3 keeps its own first-start video defaults
#   IW5_ASYNC=0        MW3 shaders compile while drawing
#   IW5_SHADER_CACHE=0 MW3 keeps no shader caches between runs
#   IW5_PRELOAD=0      MW3 compiles a new map's shaders as play begins (short
#                      freezes) instead of on its loading screen (Plutonium, Steam)
#   IW5_METAL_PARALLEL=0  Metal compiles a few shaders at a time
#   IW4_GRAPHICS=0     Modern Warfare 2 keeps its own first-start video defaults
#   IW4_SCREEN=0       MW2 keeps the resolution set in the game
#   IW4_PRELOAD=1      MW2 preloads a map's shaders while it loads: the first
#                      visit takes longer to load and nothing appears late
#   WW2_PRELOAD=1      WWII's campaign preloads a mission's shaders while it loads
#                      (~45 s longer; under DXMT nothing appears sooner in play)
#   STEAM_SCREEN=0     Steam Library games keep a windowed mode chosen in their
#                      options (default: fullscreen at the desktop's size every start)
#   WW2_SCREEN=0       the same for WWII only
#   WW2_NETSTATE=0     WWII multiplayer / Zombies ask Wine's network state on
#                      every frame online (~10 ms each) instead of a cached answer
#   AW_PRELOAD=1       Advanced Warfare's campaign preloads a mission's shaders (as WWII's)
#   AW_MP_MAXFPS=0     AW multiplayer keeps the frame cap saved in its profile
#   AW_NETSTATE=0      AW multiplayer / Exo Zombies get Wine's own network-state answer
#   IW6_TUNE=0         Ghosts keeps its own tessellation/motion blur and may
#                      load NVIDIA's HBAO+/TXAA/APEX libraries
#   CURSOR_FIX=0       on macOS 26+, keep the transparent-cursor fix (a fast
#                      mouse no longer lowers the frame rate) to Black Ops II
#   SKIP_INTRO=0       play the logo movies when WaW, BO2 and MW3 start
#   BO1_SKIP_INTRO=1   skip Black Ops' startup intro movie (default: play it)
#   BOIII_SCREEN=0     Black Ops III keeps its own window mode, size and frame cap
#   IW7_SCREEN=0       Infinite Warfare (Steam) keeps the resolution and refresh
#                      rate saved in its profile
#   IW7_ASYNC=0        Infinite Warfare shaders compile while drawing
#   IW7_FRAME_PACING=0 no DXMT frame pacing at the frame-rate cap (Infinite Warfare)
#   IW7_DXMT_FIX=0     Infinite Warfare on the engine's DXMT instead of Advanced
#                      Warfare's fixed one (its tessellation crashes it there)
#   SETTINGS_GUARD=0   "Set Optimal Settings?" may apply the game's own guesses
#   GAME_ARGS="..."    extra game arguments (offline modes)
set -uo pipefail
kit=$(cd -- "$(dirname -- "$0")" && pwd)
home=${SIL_HOME:-"$HOME/Library/Application Support/Siliconium"}
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/tools/migrate.sh"   # an install of the previous name
if [ -f "$home/settings.conf" ]; then
  while IFS='=' read -r k v; do
    case "$k" in ''|\#*) continue ;; esac
    k=${k//[[:space:]]/}
    # Folder values are taken as written: a "#" or a trailing space can be
    # part of a Mac folder's name.
    case "$k" in *_DIR) ;; *) v=${v%%#*}; v=${v%"${v##*[![:space:]]}"} ;; esac
    [[ "$k" =~ ^[A-Z_][A-Z0-9_]*$ ]] && [ -z "${!k+x}" ] && export "$k=$v"
  done < "$home/settings.conf"
fi
engine="$home/engine"
export WINEPREFIX="$home/prefix" CX_ROOT="$engine" WINESERVER="$engine/bin/wineserver"
# Black Ops II's offline campaign had its own prefix (removed in 1.2.1;
# `bo2c` only stops with a message now)
if [ "${1:-}" = bo2c ] || [ "${1:-}" = bo2s ] || [ "${1:-}" = steam ] || [ "${1:-}" = cod4x ] || [ "${1:-}" = iw7mod ] || [ "${1:-}" = own ]; then
  # bo2s and the Steam Library (steam): Steam for Windows in its own prefix
  # (steam.sh), which starts the game. CoD4X (cod4x), IW7-Mod (iw7mod) and
  # Your Own Game Files (own): the same prefix and Steam's game setup, without Steam
  if [ "${1:-}" = bo2c ]; then export WINEPREFIX="$home/prefix-bo2c"; else export WINEPREFIX="$home/prefix-steam"; fi
  # its Wine server runs through a link outside the engine folder, so the app
  # doesn't count the campaign's prefix as a game running
  mkdir -p "$home/campaign"; ln -sfn "$engine/bin/wineserver" "$home/campaign/wineserver"
  export WINESERVER="$home/campaign/wineserver"
elif [ "${1:-}" = iw6 ]; then
  export WINEPREFIX="$home/prefix-iw6"
elif [ "${1:-}" = battlenet ]; then
  # the Battle.net section (battlenet.sh): Battle.net in its own prefix, which
  # starts the game; its Wine server through the same link as Steam's
  export WINEPREFIX="$home/prefix-battlenet"
  mkdir -p "$home/campaign"; ln -sfn "$engine/bin/wineserver" "$home/campaign/wineserver"
  export WINESERVER="$home/campaign/wineserver"
fi
export WINEDLLPATH="$engine/lib/wine/x86_64-windows:$engine/lib/wine/x86_64-unix"
export WINEMSYNC=1 WINEDEBUG=${WINEDEBUG:--all} WINEDLLOVERRIDES="mscoree,mshtml,winemenubuilder.exe="
plain_wine="$engine/lib/wine/x86_64-unix/wine"
wine="$plain_wine"
plutonium="$WINEPREFIX/drive_c/users/crossover/AppData/Local/Plutonium"
mkdir -p "$home/logs" "$home/cache"

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
# log_cap <log>: the logs every start appends to (Steam Library games, CoD4X,
# IW7-Mod, the display mode helper) keep only their newest 1 MB once they pass
# 2 MB (Advanced Warfare's had reached 23 MB of DXMT messages); called before
# a start writes to it, so the start's own lines are always there in full.
# The file stays the same file, so a program still appending to it goes on.
log_cap() {
  local f=$1 t
  [ -f "$f" ] && [ "$(stat -f %z "$f" 2>/dev/null || echo 0)" -gt 2097152 ] || return 0
  t=$(mktemp "${TMPDIR:-/tmp}/siliconium-log.XXXXXX") || return 0
  { printf '%s\n' "--- $(date) (older lines removed: Siliconium keeps the newest 1 MB of this log)"
    tail -c 1048576 "$f" | tail -n +2; } > "$t" && cat "$t" > "$f"
  rm -f "$t"
}
# Cap any oversized logs (> 2 MB) during idle prewarm/stop so logs/ never bloats.
log_cap_sweep() {
  local f
  for f in "$home/logs"/*.log; do
    [ -f "$f" ] && log_cap "$f"
  done
}
# Match a running Wine executable while ignoring Siliconium's own helpers
# (iw6-focus receives the target exe name as its final argument).
sil_wine_running() {   # <eregex>
  ps -axo args= | awk -v pat="$1" 'BEGIN{rc=1; p=tolower(pat)} {l=tolower($0)} l ~ p && l !~ /iw6-focus|iw6-restore\.exe|launch\.sh|awk/ {rc=0; exit} END{exit rc}'
}
. "$kit/tools/dl-progress.sh"
# A community client's copy of a Steam game (CoD4X, IW7-Mod: tools/steam-copy.sh):
# Steam's files leave it a minute after this start ends, however it ends (the
# game quit, Stop, an error); a start in that minute keeps them
copy_release() {
  [ -n "${sil_copy_dir:-}" ] || return 0
  ( /bin/bash "$kit/tools/steam-copy.sh" release "$s_client" "$sil_copy_dir" "$sil_copy_gen" 60 > /dev/null 2>&1 & )
}
. "$kit/tools/winpath.sh"
. "$kit/tools/game-bundle.sh"
use_wine "$wine"   # macOS Game Mode for every game (tools/game-bundle.sh)
# focus_helper <program> [pid]: payload/iw6/iw6-focus (tools/iw6-focus.swift)
# for the game's Mac process (that pid, or 0: found by its program name once
# its window is up, when a launcher or another Windows program starts it):
# the game is made the active app when its window appears, if Siliconium,
# Steam, Battle.net or the game's launcher is still in front (macOS does not
# bring forward a program a background process starts: the menu bar stayed
# over the game until a click, and Game Mode stayed off), and its window is
# restored at once after Cmd-Tab (a restore helper kept running in Wine). It
# ends with the game; never over another app the player switched to.
sil_focus_from="io.github.siliconium:Steam.exe:Battle.net.exe:plutonium-launcher-win32.exe:iw4x-launcher.exe"
focus_pid=
focus_helper() {
  [ -x "$kit/payload/iw6/iw6-focus" ] && [ -f "$kit/payload/iw6/iw6-restore.exe" ] || return 1
  SIL_FOCUS_FROM="$sil_focus_from" "$kit/payload/iw6/iw6-focus" "${2:-0}" "$wine" "$kit/payload/iw6/iw6-restore.exe" "$1" \
    >> "${log:-/dev/null}" 2>&1 &
  focus_pid=$!
}
reap_orphan_winedevices() {   # <prefix>
  local pfx=${1:-$WINEPREFIX} pid cwd
  [ -n "$pfx" ] || return 0
  for pid in $(pgrep -if 'winedevice\.exe|plugplay\.exe' 2>/dev/null || true); do
    cwd=$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -1)
    case "$cwd/" in "$pfx/"*) kill -KILL "$pid" 2>/dev/null || true ;; esac
  done
}
stop_all() { "$WINESERVER" -k 2>/dev/null; "$WINESERVER" -w 2>/dev/null; reap_orphan_winedevices "$WINEPREFIX"; }
# A display mode hold (hold_1x_size) that was killed before it could put the
# desktop's mode back: put it back now, unless the player chose another mode
# since (tools/displaymode restore). A hold that is still on is left alone: it
# restores the mode itself once its game has ended.
restore_display() { "$kit/tools/displaymode" restore >> "$home/logs/displaymode.log" 2>&1 || true; }

game=${1:-}; mode=${2:-}
[ "$game:$mode" = stop:iw6 ] && { WINEPREFIX="$home/prefix-iw6" stop_all; restore_display; exit 0; }
[ "$game" = stop ] && { rm -f "$home/cache/.sil-prewarmed"; stop_all
  for pfx in "$home/prefix-bo2c" "$home/prefix-steam" "$home/prefix-battlenet" "$home/prefix-iw6"; do
    WINEPREFIX="$pfx" "$WINESERVER" -k 2>/dev/null
    reap_orphan_winedevices "$pfx"
  done
  log_cap_sweep
  restore_display; exit 0; }
if [ "$game" = prewarm ]; then
  log_cap_sweep
  if [ "$mode" = steam ]; then
    export WINEPREFIX="$home/prefix-steam"
    pgrep -if 'steam\.exe' >/dev/null 2>&1 && exit 0
  fi
  [ -x "$plain_wine" ] && [ -x "$WINESERVER" ] && [ -d "$WINEPREFIX/drive_c" ] || exit 0
  # Only pre-warm when idle (no game running and no wineserver already up).
  sil_wine_running 't4mp\.exe|t4sp\.exe|t5mp\.exe|t5sp\.exe|t6mp\.exe|t6zm\.exe|t6sp\.exe|t6sp-mod\.exe|iw3sp\.exe|iw3sp_mod\.exe|iw3mp\.exe|iw4sp\.exe|iw4mp\.exe|iw5mp\.exe|iw5sp\.exe|boiii(-[[:alnum:]._-]+)?\.exe|blackops3\.exe|blackops4\.exe|iw4x(-launcher)?\.exe|iw6sp64_ship\.exe|plutonium-launcher-win32\.exe|plutonium-bootstrapper-win32\.exe' && exit 0
  pgrep -f "$engine/bin/wineserver" >/dev/null 2>&1 && exit 0
  "$WINESERVER" -p 120 >/dev/null 2>&1 </dev/null || exit 0
  env -u WINELOADER "$plain_wine" cmd /c exit 0 >/dev/null 2>&1 </dev/null || true
  [ "$mode" != steam ] && : > "$home/cache/.sil-prewarmed"
  exit 0
fi
# Wait for the game to exit. When reusing a pre-warmed persistent wineserver
# (wineserver -p 120), poll the game process instead of blocking 120 s on
# wineserver -w, then cleanly stop wineserver so its registry flushes to disk.
wait_wine_exit() {   # wait_wine_exit <eregex> [wait_for_spawn:0|1]
  local pat=$1 spawn=${2:-0} i
  if [ "${prewarm_active:-0}" = 1 ]; then
    if [ "$spawn" = 1 ]; then
      for i in $(seq 20); do sil_wine_running "$pat" && break; sleep 0.25; done
    fi
    while sil_wine_running "$pat"; do sleep 1; done
    declare -F mtld3d_save_cache >/dev/null 2>&1 && mtld3d_save_cache
    "$WINESERVER" -k 2>/dev/null; "$WINESERVER" -w 2>/dev/null
  else
    "$WINESERVER" -w 2>/dev/null
  fi
  [ -n "${focus_pid:-}" ] && { kill "$focus_pid" 2>/dev/null; wait "$focus_pid" 2>/dev/null; } || true
}
[ -x "$wine" ] || die "the engine is not installed"
# CoD4X, IW7-Mod or Your Own Game Files without the Steam Library set up yet:
# Steam's prefix, without Steam (Steam for Windows can be added to it later)
if { [ "$game" = cod4x ] || [ "$game" = iw7mod ] || [ "$game" = own ]; } && [ ! -f "$WINEPREFIX/system.reg" ]; then
  case "$game" in
    cod4x)  own_init_label="CoD4X" ;;
    iw7mod) own_init_label="IW7-Mod" ;;
    *)      own_init_label="offline games" ;;
  esac
  printf '==> %s\n' "Preparing Wine for $own_init_label"
  "$wine" wineboot --init > "$home/logs/steam-wineboot.log" 2>&1
  "$WINESERVER" -w 2>/dev/null
fi
[ -d "$WINEPREFIX/drive_c" ] || die "the Wine prefix is not set up"
# Engines installed by a quarantined (browser-downloaded) Siliconium carry the
# quarantine flag, and Gatekeeper refuses to load them ("winemetal.so Not
# Opened"). Checking two files is cheap; clear the engine when one has it.
for f in "$wine" "$engine/lib/wine/x86_64-unix/winemetal.so" "$engine/lib/wine/x86_64-unix/winemac.so"; do
  if xattr -p com.apple.quarantine "$f" > /dev/null 2>&1; then
    xattr -dr com.apple.quarantine "$engine" "$kit" 2>/dev/null; break
  fi
done
case "$game:$mode" in
  plutonium:online)
    pl_root="$WINEPREFIX/drive_c/users/crossover/AppData/Local/Plutonium"
    pl_bin="$pl_root/bin"
    [ -f "$pl_bin/plutonium-launcher-win32.exe" ] || die "Plutonium is not installed in the prefix. Run Install first."
    # Refresh saved game paths with short Windows drive letters before opening
    # the launcher so previously linked long Steam Library paths (issue #3) work
    # even when launched directly from Plutonium's own window.
    for pl_pair in "t4:${WAW_DIR:-}" "t5:${BO1_DIR:-}" "t6:${BO2_DIR:-${OWN_BO2_DIR:-}}" "iw5:${IW5_DIR:-${OWN_MW3_DIR:-}}"; do
      pl_id=${pl_pair%%:*} pl_dir=${pl_pair#*:}
      if [ -n "$pl_dir" ] && [ -d "$pl_dir/zone" ]; then
        /usr/bin/python3 -I "$kit/tools/plutonium-config.py" link "$pl_root/config.json" "$pl_id" "$(sil_winpath "$pl_dir")" || true
      fi
    done
    cd "$pl_bin" || exit 1
    exec "$wine" "$pl_bin/plutonium-launcher-win32.exe" > "$home/logs/plutonium-online.log" 2>&1 ;;
  waw:online|waw:zombies|waw:campaign|waw:mp) dir=${WAW_DIR:-} t=t4 ;;
  bo1:online|bo1:zombies|bo1:campaign|bo1:mp) dir=${BO1_DIR:-} t=t5 ;;
  bo2:online|bo2:zombies|bo2:mp|bo2:declassified) dir=${BO2_DIR:-${OWN_BO2_DIR:-}} t=t6 ;;
  iw5:online|iw5:mp) dir=${IW5_DIR:-${OWN_MW3_DIR:-}} t=iw5 ;;
  iw4:play|iw4:launcher) dir=${IW4_DIR:-${OWN_MW2_DIR:-}} t=iw4 ;;
  iw6:play) dir=${IW6_DIR:-} t=iw6 ;;
  boiii:play) dir=${BOIII_DIR:-} t=t7 GAME_ARGS=${GAME_ARGS---launch} ;;
  boiii:launcher) dir=${BOIII_DIR:-} t=t7 ;;
  # (the offline Black Ops II campaign was removed in 1.2.1: its setup took
  # Steam's DRM off t6sp.exe; Steam's campaign plays from the Steam Library)
  bo2c:play) die "the offline Black Ops II campaign was removed in Siliconium 1.2.1: play its campaign from the Steam Library" ;;
  bo2s:play) dir=$(bash "$kit/bo2-steam.sh" gamedir) t=t6s
    [ -f "$dir/t6sp.exe" ] || die "Black Ops II is not downloaded in Steam yet: press Download (or install it in Steam), then Play Campaign" ;;
  steam:*)   # the Steam Library: Steam's own files, started by Steam
    . "$kit/tools/steam-games.sh"
    s_id=${mode%-*} s_part=${mode#*-}
    steam_title "$s_id" "$s_part" || die "unknown Steam Library game: $mode"
    # STEAM_APPLAUNCH=1 (settings.conf, for testing): let Steam start parts
    # through Steam, as its Play button does (only for parts with their own app)
    [ "${STEAM_APPLAUNCH:-}" = 1 ] && s_own=1
    dir=$(bash "$kit/steam.sh" gamedir "$s_app") t=steam s_client=
    [ -n "$dir" ] && [ -f "$dir/$s_exe" ] ||
      die "$s_name is not downloaded in Steam yet: press Download in the Steam Library, then Play"
    # Infinite Warfare with IW7-Mod chosen in its Fixes menu (STEAM_MOD_IW=iw7mod):
    # this Steam download through IW7-Mod, exactly as the IW7-Mod tab plays it
    # (its own copy; None: Steam's game as it is)
    if [ "$s_id" = iw ] && [ "${STEAM_MOD_IW:-}" = iw7mod ]; then
      . "$kit/tools/iw7mod.sh"
      sil_iw7mod_use "$dir" || die "$i7_error"
      dir=$i7_dir
    fi ;;
  # CoD4X (tools/cod4x.sh): Call of Duty 4 multiplayer with the Steam Library's
  # setup for it (steam cod4-mp) from CoD4X's own folder (a copy of Steam's
  # download, or the folder the player chose), started without Steam
  cod4x:play)
    . "$kit/tools/steam-games.sh"
    s_id=cod4 s_part=mp
    steam_title cod4 mp || die "unknown Steam Library game: cod4-mp"
    s_own=0 s_client=cod4x s_name=CoD4X
    . "$kit/tools/cod4x.sh"
    sil_cod4x_prepare "${COD4X_DIR:-${OWN_COD4_DIR:-}}" || die "$c4_error"
    dir=$c4_dir t=steam ;;
  # IW7-Mod (tools/iw7mod.sh): Infinite Warfare with the Steam Library's setup
  # for it (steam iw-sp: AW's DXMT fixes, 1x display mode, resolution and
  # refresh rate in its profile) from the folder the player chose, or from its
  # own APFS copy of Steam's download (Steam's files are never changed),
  # started without Steam. The game runs inside iw7-mod.exe: every
  # per-executable setting follows that name. Its own switches (IW7MOD_*, the
  # IW7-Mod tab's patches) stand in for the Steam Library's IW7_* and the shared
  # DISPLAY_MODE
  iw7mod:play)
    . "$kit/tools/steam-games.sh"
    . "$kit/tools/iw7mod.sh"
    sil_iw7mod_use "${IW7MOD_DIR:-}" || die "$i7_error"
    dir=$i7_dir t=steam ;;
  # Offline -> "Your Own Game Files" (disc / retail / offline Windows folders
  # chosen by the player, started directly without Steam with the same
  # Siliconium patches as Plutonium and the Steam Library). Auto-detects 32-bit
  # vs 64-bit PE binaries for retail MW2/MW3 so 32-bit copies automatically use
  # mtld3d (D3D9 -> Metal) + Smart HiDPI + x87sidecar, while 64-bit copies keep
  # 64-bit DXVK.
  own:*)
    . "$kit/tools/steam-games.sh"
    s_id=${mode%-*} s_part=${mode#*-}
    case "$s_id:$s_part" in
      cod4:sp|cod4:mp) dir=${OWN_COD4_DIR:-} ;;
      mw2:sp|mw2:mp)   dir=${OWN_MW2_DIR:-} ;;
      mw3:sp|mw3:mp)   dir=${OWN_MW3_DIR:-} ;;
      bo2:sp|bo2:mp|bo2:zm) dir=${OWN_BO2_DIR:-} ;;
      ghosts:sp)       dir=${OWN_GHOSTS_DIR:-${IW6_DIR:-}} ;;
      *) die "unknown offline game: $mode" ;;
    esac
    steam_title "$s_id" "$s_part" || die "unknown offline game: $mode"
    [ -n "$dir" ] && [ -d "$dir" ] ||
      die "Choose your $s_name folder in Your Own Game Files first"
    if [ ! -f "$dir/$s_exe" ]; then
      own_match=$(find "$dir" -maxdepth 1 -iname "$s_exe" -print -quit 2>/dev/null || true)
      [ -n "$own_match" ] && s_exe=${own_match##*/}
    fi
    [ -f "$dir/$s_exe" ] ||
      die "$s_exe was not found in the chosen $s_name folder"
    if [ "$s_api" = d3d9x64 ] && file -b "$dir/$s_exe" 2>/dev/null | grep -qiE 'PE32 executable|Intel 80386'; then
      s_api=d3d9
    fi
    s_own=0 s_client=own t=steam ;;
  # The Battle.net section (battlenet.sh, tools/battlenet-games.sh): Battle.net's
  # own files, started by Battle.net (bnet_play, below)
  battlenet:*)
    . "$kit/tools/battlenet-games.sh"
    bnet_title "$mode" || die "unknown Battle.net game: $mode"
    dir=$(bnet_gamedir "$b_id") t=bnet
    [ -n "$dir" ] || die "$b_name is not installed in Battle.net yet: press Install in the Battle.net section, then Play" ;;
  *) die "usage: launch.sh waw|bo1|bo2|iw5 online|zombies|campaign|mp [name], launch.sh iw4 play|launcher, launch.sh iw6 play, launch.sh boiii play|launcher, launch.sh steam <game>-<sp|mp|zm>, launch.sh own <cod4|mw2|mw3|bo2|ghosts>-<sp|mp|zm>, launch.sh cod4x play, launch.sh iw7mod play, launch.sh battlenet <game>, or launch.sh stop" ;;
esac
# (a client's copy was made above: Steam's files leave it after this start)
[ -n "${sil_copy_dir:-}" ] && trap copy_release EXIT
# The community fix the player chose for this Steam or offline game, if any
# (tools/steam-mods.sh; none: nothing here changes). CoD4X / IW7-Mod skip this.
if [ "$t" = steam ]; then
  . "$kit/tools/steam-mods.sh"
  if [ -z "${s_client:-}" ] || [ "${s_client:-}" = own ]; then
    steam_mod_prepare "$dir" || die "$m_error"
  fi
fi
if [ "$t" = t7 ]; then
  [ -n "$dir" ] && [ -d "$dir" ] || die "the Black Ops III (Windows) folder is not set"
  # boiii.exe (Ezz's client): downloaded here the first time, checked against
  # its published SHA-256; Ezz's launcher updates it afterwards
  if [ ! -f "$dir/boiii.exe" ]; then
    BOIII_DIR="$dir" bash "$kit/boiii.sh" download ||
      die "Could not download boiii.exe: check your internet connection and press Play again."
  fi
elif [ "$t" = t6 ] || [ "$t" = t6c ] || [ "$t" = t6s ] || [ "$t" = steam ] || [ "$t" = bnet ]; then
  :   # BO2 keeps the desktop's mode (see the t6:mp note above); Steam's and Battle.net's games were checked above
elif [ "$t" = iw5 ]; then
  [ -n "$dir" ] && [ -d "$dir/main" ] && [ -d "$dir/zone" ] ||
    die "the Modern Warfare 3 game folder is not set (or has no main/ and zone/ folders)"
  [ -f "$dir/mss32.dll" ] ||
    die "this Modern Warfare 3 is not the 32-bit version Plutonium needs (Steam's September 2026 update made it 64-bit): choose a 32-bit game folder (main/, zone/ and mss32.dll)"
  compgen -G "$dir/main/iw_*.iwd" > /dev/null ||
    die "the Modern Warfare 3 folder's main/ has no iw_00.iwd (only the localized files): the game's data is missing, copy the whole main folder of Modern Warfare 3"
elif [ "$t" = iw4 ]; then
  [ -n "$dir" ] && [ -d "$dir/main" ] && [ -d "$dir/zone" ] ||
    die "Choose the Modern Warfare 2 game folder (the one with main/ and zone/)."
  # IW4X's launcher: downloaded when missing, then it keeps itself and the
  # game up to date (kit/tools/iw4x.sh)
  . "$kit/tools/iw4x.sh"
  sil_iw4x_prepare "$dir" || [ -f "$dir/iw4x.exe" ] ||
    die "Could not download the IW4X launcher: check your internet connection and press Play again."
elif [ "$t" = iw6 ]; then
  [ -n "$dir" ] && [ -f "$dir/iw6sp64_ship.exe" ] && [ -f "$dir/zone/prologue.ff" ] &&
    [ -f "$dir/bink2w64.dll" ] && [ -f "$dir/steam_api64.dll" ] ||
    die "Choose the Ghosts campaign folder with iw6sp64_ship.exe, zone/prologue.ff, bink2w64.dll and steam_api64.dll."
else
  [ -n "$dir" ] && [ -d "$dir/zone" ] || die "the $game game folder is not set (or has no zone folder)"
  [ "$t" != t6c ] || [ -f "$dir/t6sp.exe" ] || die "the Black Ops II campaign folder has no t6sp.exe"
fi
# Auto-upgrade bundled patched x87sidecar (PR #54/#57 fixes) on existing engines
# unless a strictly newer official release is already installed.
if [ -x "$kit/payload/x87/x87sidecar" ] && [ -f "$kit/payload/x87/VERSION" ] && [ -d "$engine/bin" ]; then
  x87_want=$(tr -d '\r\n' < "$kit/payload/x87/VERSION")
  x87_cur=$(awk -F= '/^x87sidecar=/{print $2; exit}' "$engine/siliconium.version" 2>/dev/null || true)
  [ -n "$x87_cur" ] || x87_cur=$(tr -d '\r\n' < "$engine/x87sidecar.version" 2>/dev/null || true)
  if [ "$x87_cur" != "$x87_want" ] && { [ "$x87_cur" = "v1.9.1" ] || [ -z "$x87_cur" ]; } &&
     "$kit/payload/x87/x87sidecar" --probe >/dev/null 2>&1; then
    if cp -pf "$kit/payload/x87/x87sidecar" "$engine/bin/x87sidecar.new" &&
       mv -f "$engine/bin/x87sidecar.new" "$engine/bin/x87sidecar"; then
      printf '%s\n' "$x87_want" > "$engine/x87sidecar.version" 2>/dev/null || true
      if [ -f "$engine/siliconium.version" ]; then
        if grep -q '^x87sidecar=' "$engine/siliconium.version" 2>/dev/null; then
          sed -i '' -E "s|^x87sidecar=.*|x87sidecar=$x87_want|" "$engine/siliconium.version" 2>/dev/null || true
        else
          printf 'x87sidecar=%s\n' "$x87_want" >> "$engine/siliconium.version" 2>/dev/null || true
        fi
      fi
    else
      rm -f "$engine/bin/x87sidecar.new"
    fi
  fi
fi
# Reuse a pre-warmed wineserver (started silently when Siliconium opened) when
# launching Plutonium/IW4X play modes and no engine module updates are pending (~4 s faster).
prewarm_active=0
need_stop=1
if [ -f "$home/cache/.sil-prewarmed" ] && [ "$mode" != online ] &&
   case "$t" in t4|t5|t6|iw5|iw4) true ;; *) false ;; esac; then
  if pgrep -f "$engine/bin/wineserver" >/dev/null 2>&1 &&
     ! pgrep -if 't4mp\.exe|t4sp\.exe|t5mp\.exe|t5sp\.exe|t6mp\.exe|t6zm\.exe|t6sp\.exe|iw5mp\.exe|iw5sp\.exe|iw4x(-launcher)?\.exe|plutonium-launcher-win32\.exe|plutonium-bootstrapper-win32\.exe' >/dev/null 2>&1; then
    mods_match=1
    for m in ntdll.so winebus.so winecoreaudio.so winemac.so; do
      [ ! -f "$kit/payload/x86_64-unix/$m" ] || cmp -s "$engine/lib/wine/x86_64-unix/$m" "$kit/payload/x86_64-unix/$m" || { mods_match=0; break; }
    done
    [ ! -f "$kit/payload/lib64/libMoltenVK.dylib" ] || [ ! -f "$engine/lib64/libMoltenVK.real.dylib" ] ||
      cmp -s "$engine/lib64/libMoltenVK.dylib" "$kit/payload/lib64/libMoltenVK.dylib" || mods_match=0
    if [ "$mods_match" = 1 ]; then
      need_stop=0
      prewarm_active=1
    fi
  fi
fi
rm -f "$home/cache/.sil-prewarmed"
[ "$need_stop" = 1 ] && stop_all
# Clients' copies nobody is using (an earlier start that never got to clean
# up): Steam's files leave them (tools/steam-copy.sh; this start's own copy is
# in use and stays), in the background
( /bin/bash "$kit/tools/steam-copy.sh" tidy > /dev/null 2>&1 & )
# The Direct3D 9 games run on MoltenVK: make sure the engine has the build for
# this macOS (1.4.0 left Black Ops unable to start on macOS 15).
case "$t" in
  t4|t5|iw4|iw5|steam)
    . "$kit/tools/moltenvk.sh"
    sil_moltenvk_ensure "$engine" "$home/downloads" ||
      printf '%s\n' 'Warning: could not update MoltenVK; the game may not start (check your internet connection).' >&2 ;;
esac
# Wine keeps per-loader copies in $TMPDIR/winetemp-*, with ntdll.so linked by
# its absolute path. When the engine moves (the data folder was renamed, or a
# reinstall elsewhere) that link points nowhere and Wine cannot start ("could
# not load ntdll.so"). Wine is stopped here: drop folders with a broken link,
# Wine makes them again.
for wt in "$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null || echo "${TMPDIR:-/tmp}")"/winetemp-*; do
  [ -L "$wt/ntdll.so" ] && [ ! -e "$wt/ntdll.so" ] && rm -rf -- "$wt"
done
# One-time-settings markers and backups of the previous name (once): every
# prefix, Plutonium's profiles, the engine and every game folder
if [ ! -f "$home/.sil-migrated" ]; then
  sil_migrate_markers 1 "$home"/prefix*
  sil_migrate_markers 3 "$home"/prefix*/drive_c/windows
  sil_migrate_markers 6 "$home"/prefix/drive_c/users/crossover/AppData/Local/Plutonium/storage
  sil_migrate_markers 2 "$engine/lib/wine"
  sil_migrate_markers 3 ${WAW_DIR:+"$WAW_DIR"} ${BO1_DIR:+"$BO1_DIR"} ${BO2_DIR:+"$BO2_DIR"} \
    ${IW4_DIR:+"$IW4_DIR"} ${IW5_DIR:+"$IW5_DIR"} ${IW6_DIR:+"$IW6_DIR"} ${BOIII_DIR:+"$BOIII_DIR"} \
    ${BO2C_DIR:+"$BO2C_DIR"}
  : > "$home/.sil-migrated"
fi
# A game folder below a folder Windows cannot name ("CoD " with its trailing
# space) gets a drive letter in this prefix before Wine starts, so the game's
# working directory and every path handed to it are ones Windows can use.
[ -n "${dir:-}" ] && sil_winpath "$dir" > /dev/null

# Update a known Siliconium 0.2.3 module after Wine has stopped.
install_own_engine_module() {
  local driver="$engine/lib/wine/x86_64-unix/$1"
  local patched="$kit/payload/x86_64-unix/$1" digest staged
  shift
  [ -f "$patched" ] && grep -Fxq 'base=own 0.2.3' "$engine/siliconium.version" 2>/dev/null || return 0
  cmp -s "$driver" "$patched" && return 0
  digest=$(shasum -a 256 < "$driver") || return 1
  case " $* " in
    *" ${digest%% *} "*) ;;
    *) return 0 ;;
  esac
  staged=$(mktemp "$driver.XXXXXX") || return 1
  if ! cp -p "$patched" "$staged" ||
     { [ ! -e "$driver.sil-original" ] && ! ln "$driver" "$driver.sil-original"; } ||
     ! mv -f "$staged" "$driver"; then
    rm -f "$staged"
    return 1
  fi
}
# Our MoltenVK wrapper (payload/lib64/libMoltenVK.dylib, tools/mvkcache.c) for
# engines installed with an earlier one (install-engine.sh signs its copy
# again, so both digests of each earlier build are listed): since 2026-11-24
# it reads its 8 saved caches in parallel (MoltenVK compiles their Metal
# libraries while reading them; one at a time, Black Ops' intro and menu
# stayed black for minutes when Metal had not kept them). Running games keep
# the file they loaded (a new file is moved over the old one).
install_own_moltenvk() {
  local lib="$engine/lib64/libMoltenVK.dylib" new="$kit/payload/lib64/libMoltenVK.dylib" digest staged
  [ -f "$new" ] && [ -f "$lib" ] && [ -f "$engine/lib64/libMoltenVK.real.dylib" ] || return 0
  cmp -s "$lib" "$new" && return 0
  digest=$(shasum -a 256 < "$lib") || return 1
  case " $* " in
    *" ${digest%% *} "*) ;;
    *) return 0 ;;
  esac
  staged=$(mktemp "$lib.XXXXXX") || return 1
  if ! cp -p "$new" "$staged" || ! mv -f "$staged" "$lib"; then rm -f "$staged"; return 1; fi
}
install_own_moltenvk \
  a7524c6e8691c4b54d9450d7441c89f12614ada76731b9d311c32d3902ba334d \
  c9f3818ae802cc2ea20c37260edfba0190dd9632ad3df23c63c07b085ffdd343 \
  c1ac59e3290653e9a8c2e22c98682b2ec5c6904478f3c9131d8ca0f7906df733 \
  af8dd8ec76e9e45f1aaff10ae0179495d3b74b3fa10f8fe1224f5edf57cc174b ||
  printf '%s\n' 'Warning: could not install the shader cache update (MoltenVK).' >&2
# ntdll.so with the renamed SIL_ variables (the 0.9.x builds read the old ones)
install_own_engine_module ntdll.so \
  d3cbebc31c425a6edeb275f1fa1dc43af6db66af452febafb799e42a534bad6f \
  ecd38a1b1eb54e8626b02916dc0c8ad670f9c73d01b2c349d251469297e0d720 ||
  printf '%s\n' 'Warning: could not install the ntdll update.' >&2
unset SIL_BATCH_SDL_STICKS SIL_BO1_BATCH_SWITCH_STICKS
if [ "${SDL_STICKS:-${SWITCH_STICKS:-1}}" != 0 ] && { [ "$t" != t5 ] || [ "${BO1_SWITCH_STICKS:-1}" != 0 ]; }; then
  # Wine can fall behind when a 1 kHz receiver generates one SDL event per
  # changed axis. Batch closely spaced stick events for SDL gamepads.
  export SIL_BATCH_SDL_STICKS=1
  [ "$t" = iw6 ] || install_own_engine_module winebus.so \
    b6790857a870c4fb717b048f9524e9754548c21ccd89a30c1b04a8c4d68b64da \
    3c859730eaf6256ce2fac5fae0641d9db00bbf70ff591661b62fca7e26a82bca \
    dcebc1e398e2a2ea96d8a481391aca5c7329f2b9de613032ea46c7cc3f7d0d71 \
    84af9eed34201aedb4a7fb76a890c87031696ac35f28e6bff29a5b0d9342763f \
    1e8e5e30b24ff999a97d97cd5733f59c694dc1e01d1f66bbd7c5aa6e3d1b60a0 ||
    printf '%s\n' 'Warning: could not install the SDL controller update.' >&2
fi
# CoreAudio render period matching the output device's HAL block (prevents
# crackling/fluttering on 44.1 kHz / Bluetooth / 512-frame devices for every game).
install_own_engine_module winecoreaudio.so \
  570a756b9f72d4e26769431ea419719cebfbd14c9f1c52ddcd8abd2b61510883 \
  fb6c9d52aefb1180e4c716c52f873929f91e6e0290a6955f23fe69cf7ab85c8d \
  ac720fac925251b1d22065cca7c7f7c73e16d4610edc4ec6c393e3d16f7f4744 ||
  printf '%s\n' 'Warning: could not install the audio driver update.' >&2
# Unified DXMT winemetal.so (v0.80 + patches/dxmt-airconv-ts-workloads-v0.80.patch):
# eliminates the duplicate 32 MB AW/IW translator and persistent aw-engine clone.
# Verifies v0.80 ABI via winemetal.dll and checks Mach-O LC_UUID (survives
# codesign -fs - across macOS versions, zero Xcode CLT dependency).
# WINEMETAL_FIX=0 restores .sil-original if present.
install_own_winemetal() {
  local driver="$engine/lib/wine/x86_64-unix/winemetal.so"
  local patched="$kit/payload/dxmt/x86_64-unix/winemetal.so"
  local want_dll="$kit/payload/dxmt/x86_64-windows/winemetal.dll"
  local have_dll="$engine/lib/wine/x86_64-windows/winemetal.dll"
  local have_uuid staged
  [ -f "$patched" ] && [ -f "$driver" ] && [ -f "$want_dll" ] && cmp -s "$have_dll" "$want_dll" || return 0
  if [ "${WINEMETAL_FIX:-1}" = 0 ]; then
    if [ -f "$driver.sil-original" ] && ! cmp -s "$driver" "$driver.sil-original"; then
      staged=$(mktemp "$driver.XXXXXX") || return 1
      cp -p "$driver.sil-original" "$staged" && mv -f "$staged" "$driver" || { rm -f "$staged"; return 1; }
    fi
    return 0
  fi
  cmp -s "$driver" "$patched" && return 0
  have_uuid=$(/usr/bin/python3 -I - "$driver" <<'PY' 2>/dev/null
import struct, sys
try:
    b = open(sys.argv[1], "rb").read(8192)
    if struct.unpack_from("<I", b, 0)[0] != 0xfeedfacf: sys.exit(0)
    ncmds = struct.unpack_from("<I", b, 16)[0]
    off = 32
    for _ in range(ncmds):
        if off + 8 > len(b): break
        cmd, sz = struct.unpack_from("<II", b, off)
        if cmd == 0x1b and sz >= 24:
            print(b[off + 8:off + 24].hex()); break
        off += sz
except Exception:
    pass
PY
  )
  case "$have_uuid" in
    dcb7ddb5ac5937bfbd4005a8f8c416b6|97b23dea742633d680d5b929673bd44a) ;;
    *) return 0 ;;
  esac
  staged=$(mktemp "$driver.XXXXXX") || return 1
  if ! cp -p "$patched" "$staged" ||
     { ! codesign -v "$staged" 2>/dev/null && ! codesign -fs - "$staged" 2>/dev/null; } ||
     { [ ! -e "$driver.sil-original" ] && ! ln "$driver" "$driver.sil-original"; } ||
     ! mv -f "$staged" "$driver"; then
    rm -f "$staged"
    return 1
  fi
}
install_own_winemetal ||
  printf '%s\n' 'Warning: could not install the unified DXMT translator update.' >&2
# 32-bit DirectSound FIR resampler with SSE2 + SIMD (patches/wine-dsound-sse2-mixer.patch):
# ~7x faster audio mixing on Rosetta (-86% CPU, 0 dropouts even without x87sidecar).
# DSOUND_SSE=0 restores CrossOver's stock i386 dsound.dll (.sil-original).
install_own_dsound() {
  local dll="$engine/lib/wine/i386-windows/dsound.dll"
  local patched="$kit/payload/i386-windows/dsound.dll" digest staged
  [ -f "$patched" ] && [ -f "$dll" ] || return 0
  if [ "${DSOUND_SSE:-1}" = 0 ]; then
    if [ -f "$dll.sil-original" ] && ! cmp -s "$dll" "$dll.sil-original"; then
      staged=$(mktemp "$dll.XXXXXX") || return 1
      cp -p "$dll.sil-original" "$staged" && mv -f "$staged" "$dll" || { rm -f "$staged"; return 1; }
    fi
    return 0
  fi
  cmp -s "$dll" "$patched" && return 0
  digest=$(shasum -a 256 < "$dll") || return 1
  case " $* " in
    *" ${digest%% *} "*) ;;
    *) return 0 ;;
  esac
  staged=$(mktemp "$dll.XXXXXX") || return 1
  if ! cp -p "$patched" "$staged" ||
     { [ ! -e "$dll.sil-original" ] && ! ln "$dll" "$dll.sil-original"; } ||
     ! mv -f "$staged" "$dll"; then
    rm -f "$staged"
    return 1
  fi
}
install_own_dsound \
  c3bd733e6956709dfe8f6ebefd014a42ae862391e7292016de814dd9165258da ||
  printf '%s\n' 'Warning: could not install the SSE2 DirectSound update.' >&2
# The cursor fix (see SIL_BO2_TRANSPARENT_CURSOR below): Black Ops II always;
# on macOS 26 and later every game, since there the stall it fixes (a fast
# mouse dropping the frame rate) is the system's, not BO2's. CURSOR_FIX=0
# keeps it to Black Ops II.
macos_major=$(sw_vers -productVersion 2>/dev/null); macos_major=${macos_major%%.*}
cursor_fix=0
case "$t" in
  t6|t6c|t6s) cursor_fix=1 ;;
  iw6) cursor_fix=1 ;;   # Ghosts turns it on itself; it needs the module too
  # the Battle.net section's games: as the Steam Library's (CURSOR_FIX=0: off)
  bnet) [ "${CURSOR_FIX:-1}" != 0 ] && cursor_fix=1 ;;
  steam)
    # every game of the Steam Library: they draw their own pointer, and Wine's
    # re-centred Mac cursor showed in the middle of the screen whenever the
    # mouse stopped (MW2); CURSOR_FIX=0 keeps it to BO2, Ghosts and AW
    case "$s_id" in
      bo2|ghosts|aw) cursor_fix=1 ;;
      *) [ "${CURSOR_FIX:-1}" != 0 ] && cursor_fix=1 ;;
    esac ;;
  *) [ "${macos_major:-0}" -ge 26 ] 2>/dev/null && [ "${CURSOR_FIX:-1}" != 0 ] && cursor_fix=1 ;;
esac
# Our winemac.so carries the mouse-look input fix (ADS+shoot jumping & 1000 Hz
# coalescing), cursor fix, and Cmd-Tab hide for every game; optional changes
# stay off unless their variables are set.
# Accept the original and earlier modules so existing engines can update.
install_own_engine_module winemac.so \
  9e1546c897a168aec2387f771a058a9afae0eea0c392a98339137e6fc464bf9f \
  db3332fdf57b72dda60dfdaf59ef978fdd55a7a7e0596455195b7edbdd4e350a \
  c44cf8ab1819267438299b0ce2573ffa015ca77260fbbb63e26823b26d3a639c \
  6afccb6313e968b4ba6d8ba9346f1d33f36be14b32967eb9af4079376fdea1c2 \
  60213e14b7d1c501219605d9d523b9f1888ca946565d9dc0c4069db1ccd038cb \
  9b5bb6fc39ff94d1020576e3155f79a6afc81dcc91b4b3b70c60e6841553b4a0 \
  5624f8cc1a09006bbb3f6c57938ef76ac48e566d820ca1e0f39d216da85d5a69 \
  f3a79c3d8d1f09588e78726263bab22f6acd045849de2a479bfae25150b04045 \
  6be7a63ece9504e8f4a7d8e8f4b2409f5bb683ea281cdd39509eef105eff380e \
  2509d6c5a391e5da36a1c97a9cc61bfbffa5b2275f36e197bc4c777ca1e27dd0 \
  5412976bc72c5b4843eed6fac2048910befbebef21abf50ebf5627a44386547a \
  0724dd99b4ad120402a956b9b1836647ccc9431201916c77938ac69f9e55ac95 \
  eb5eb337107f33cf3fe728e2abd6b3ee6b84bc000768ff0f9d790e045b00108e \
  2af530d00139527d319ddf3821c1c849029842b2b02c9490453eab610066debd \
  4e621b5de62d1f4e9f26d3c6219693298ec4edb23f3a693ab793232bb2106137 \
  96033465f2e08f71281d46e7a97b44545a05b182290e3992c47945c17b8a09b7 \
  c730b0cefc86a1654bea4c42a18a537a18dbf134b904d4536c2cdab5078e427e \
  23f4edc1dd8364a7a20c63a51a3c361a9404ab8d846ef6536bfb073057200ae9 ||
  printf '%s\n' 'Warning: could not install the Mac window driver update (mouse, cursor, Cmd-Tab).' >&2
# (exported here for the games started from this script, Ghosts included; the
# prefix's copy for programs that a launcher starts is set further down)
unset SIL_HIDE_ON_DEACTIVATE SIL_DISPLAYMODE_RECORD
if [ "${HIDE_ON_CMDTAB:-1}" != 0 ]; then
  export SIL_HIDE_ON_DEACTIVATE=1
  [ "${CMDTAB_DESKTOP_MODE:-0}" = 1 ] && export SIL_DISPLAYMODE_RECORD="$home/cache/displaymode-desktop"
fi

. "$kit/tools/configure-ds4.sh"
configure_ds4_xinput || printf '%s\n' 'Warning: could not set up PlayStation controller XInput mapping.' >&2

# Fullscreen (1) or fullscreen window (2): a 1x display mode of the game's
# resolution while it runs, so a HiDPI-scaled desktop does not make macOS
# scale every frame (WindowServer at 100%, dropped frames, heavy-feeling aim).
# - Before any Wine process: Wine records the desktop's mode when it starts
#   and, for a fullscreen game at that size, switches back to it (the scaled
#   one) if it recorded the scaled mode.
# - Until the game ends, not this script: in online mode this process becomes
#   Plutonium's launcher, which closes as soon as it has started the game.
held_1x=
display_1x_unavailable=0
# A display mode held for an earlier launch (the game closed to start another
# mode) restores the desktop's mode when it ends, which can land after this
# launch switched to 1x and undo it: end it first and let it restore.
stop_displaymode() {
  pkill -TERM -f '/tools/displaymode [0-9]' 2>/dev/null || return 0
  local i
  for i in $(seq 25); do pgrep -qf '/tools/displaymode [0-9]' || return 0; sleep 0.2; done
}
# Direct fullscreen: the fullscreen window mode (2) becomes fullscreen (1)
# Not for Black Ops II (t6): its display mode is the player's (fullscreen,
# fullscreen window or windowed, as chosen in its options); the game starts
# with the one in its binary hardware profile, and a different r_fullscreen
# in the .cfg only applied once the game restarted its renderer, so it
# switched modes while it ran (2026-11-24).
fullscreen_cfg() { [ "$t" = t6 ] && return 0; [ "${CAPTURE_DISPLAY:-1}" != 0 ] && [ -f "$1" ] && sed -i '' 's/^seta r_fullscreen "2"/seta r_fullscreen "1"/' "$1"; return 0; }
# bo2_hw_screen <players folder> <cfg|-> <chp>...: Black Ops II starts with the
# resolution in its binary hardware profile, not the .cfg's r_mode (that one
# only applies when the game restarts its renderer): after the Mac's
# resolution changed it opened at the previous game's resolution and switched
# the display's mode while it ran (2026-11-24). Each start, when the game is
# fullscreen (its .cfg's r_mode is the desktop's: common_cvars; "-": Steam,
# fullscreen every start), the profiles get the desktop's resolution
# (tools/bo2-hwprofile.py: only that text field changes; a profile it cannot
# read is left alone). BO2_SCREEN=0: left to the game.
bo2_hw_screen() {
  local cfg=$2 f size=${dw:+${dw}x${dh:-}}; shift 2
  on BO2_SCREEN && [[ $size =~ ^[0-9]+x[0-9]+$ ]] || return 0
  if [ "$cfg" != - ]; then
    grep -Fxq "seta r_mode \"$size\"" "$cfg" 2>/dev/null && ! grep -q '^seta r_fullscreen "0"' "$cfg" || return 0
  fi
  for f in "$@"; do
    [ -f "$f" ] && /usr/bin/python3 -I "$kit/tools/bo2-hwprofile.py" "$f" "$size" >&2
  done
  return 0
}
hold_1x() { # <game cfg>
  fullscreen_cfg "$1"
  [ -f "$1" ] && grep -qE '^seta r_fullscreen "[12]"' "$1" || return 0
  hold_1x_size "$(sed -n -E 's/^seta r_mode "([0-9]+)x([0-9]+)"/\1 \2/p' "$1")"
}
# Patches and settings are on unless set to 0 (used before the display block).
on() { [ "${!1:-1}" != 0 ]; }
# Determine early whether mtld3d (Direct3D 9 -> Metal) will render this title,
# so Smart HiDPI can keep macOS HiDPI active without switching to 1x.
macos_major=${macos_major:-$(sw_vers -productVersion 2>/dev/null)}
macos_major=${macos_major%%.*}
mtld3d_active=0
mtld3d_engine=
mtld3d_cache_file=
mtld3d_plut_bin=
if on D3D9_MTLD3D && [ "${macos_major:-15}" -ge 15 ] 2>/dev/null &&
   [ -f "$kit/payload/mtld3d/x86_64-unix/mtld3d.so" ] &&
   [ "${s_own:-0}" = 0 ]; then
  case "$t:${s_id:-}" in
    t4:*|t5:*|iw5:*|iw4:*|steam:cod4|steam:waw|steam:bo1)
      mtld3d_active=1 ;;
    steam:mw2|steam:mw3)
      # 32-bit retail/offline MW2 & MW3 use the verified IW4/IW5 mtld3d D3D9 path;
      # 64-bit Steam copies keep verified DXVK64 defaults unless D3D9_MTLD3D=2.
      if [ "${s_api:-}" = d3d9 ] || [ "${D3D9_MTLD3D:-1}" = 2 ]; then mtld3d_active=1; fi ;;
    steam:cod2)
      # Uninstalled D3D9 Steam titles keep verified DXVK defaults; D3D9_MTLD3D=2 opts into mtld3d.
      [ "${D3D9_MTLD3D:-1}" = 2 ] && mtld3d_active=1 ;;
    steam:cod1|steam:uo)
      # CoD 1 / UO via GLDirect 5 -> D3D9: keep verified DXVK default; D3D9_MTLD3D=2 opts into mtld3d.
      [ "${D3D9_MTLD3D:-1}" = 2 ] && steam_gldirect && mtld3d_active=1 ;;
  esac
fi
# displaymode's SIL_KEEP_UNSCALED for KEEP_HIDPI (0, 1 = Smart HiDPI default, 2):
# On mtld3d (D3D9->Metal) and BO2 (lightweight DXMT), presenting a 1x drawable
# over a scaled 5K HiDPI desktop holds 160 FPS flat with zero 5K stall — return
# 3 so macOS stays razor-sharp HiDPI whenever 1x does not offer a higher Hz.
# Heavy GPU-bound D3D11 titles (BO3/Ghosts/AW/IW/WWII/BO4) and DXVK/MoltenVK
# fallback keep mode 1 (unscaled HiDPI kept; scaled 5K switched to 1x).
keep_hidpi() {
  case "${KEEP_HIDPI:-1}" in
    0) echo 0 ;;
    2) echo 2 ;;
    *)
      if [ "$mtld3d_active" = 1 ] || [ "$t" = t6 ] || [ "$t" = t6s ] ||
         { [ "$t" = steam ] && [ "${s_kind:-}" = t6 ]; }; then
        echo 3
      else
        echo 1
      fi ;;
  esac
}
hold_1x_size() { # "<width> <height>"
  [ -z "$held_1x" ] && [ "${DISPLAY_MODE:-1}" != 0 ] && [ -n "$1" ] || return 0
  local res=$1 log="$home/logs/displaymode.log" size i launch_pid=$$ keep=0
  # A HiDPI desktop that is not scaled (its pixels are the panel's own, e.g.
  # "looks like 1920x1080" on a 4K panel) stays as it is when no 1x mode of
  # its size has a higher refresh rate (displaymode SIL_KEEP_UNSCALED=1): no
  # mode switch, a sharp desktop after Cmd-Tab. Black Ops, 2026-11-23 (Kino,
  # 40 s): 159.0 FPS held at 1x, 158.9 in the HiDPI mode; owner, 2026-11-24:
  # BO1 and BO2 "excelente" in that mode at 160 Hz. A scaled desktop ("looks
  # like 2560x1440" on a 4K panel, drawn at 5K) is held at the 1x mode of its
  # size: kept, every frame cost a 5K composition (BO1 ~75 FPS, Black Ops 4
  # 52; Plutonium BO2 lost its steady 160 FPS to spikes). Either way the
  # games' refresh rate and frame cap are the rate of the mode the display
  # ends up in (hz, read after restore_display has settled).
  # KEEP_HIDPI=0: every HiDPI desktop at 1x; KEEP_HIDPI=2: scaled ones kept too.
  keep=$(keep_hidpi)
  ( while kill -0 "$launch_pid" 2>/dev/null; do sleep 2; done
    sleep 3   # the launcher may close a moment before the game window is up
    while pgrep -qf 'plutonium-bootstrapper-win32\.exe|t6sp\.exe|iw4x(-launcher)?\.exe'; do sleep 2; done
  ) > /dev/null 2>&1 &
  stop_displaymode
  log_cap "$log"
  size=$(stat -f %z "$log" 2>/dev/null || echo 0)
  # shellcheck disable=SC2086
  SIL_KEEP_UNSCALED=$keep "$kit/tools/displaymode" $res $! >> "$log" 2>&1 &
  held_1x=1
  for i in $(seq 50); do   # wait (up to 5 s) for the switch
    if [ "$(stat -f %z "$log" 2>/dev/null || echo 0)" != "$size" ]; then
      case "$(tail -n 1 "$log")" in
        "displaymode: no 1x "*|"displaymode: could not switch mode") display_1x_unavailable=1 ;;
      esac
      break
    fi
    sleep 0.1
  done
}
# Controller aim as on the consoles: turn acceleration, the console turn
# rates (260/90 degrees/s left-right/up-down, 90/55 aiming down sights) and
# aim assist (slowdown and lock-on over targets). Mouse aim is not affected.
# Single-pass awk replacement (avoids 24 grep/sed forks per .cfg file).
console_aim() { # <game cfg>
  [ "${CONSOLE_AIM:-1}" != 0 ] && [ -f "$1" ] || return 0
  local tmp
  tmp=$(mktemp "$1.sil.XXXXXX") || return 0
  if awk '
    BEGIN {
      n = split("aim_accel_turnrate_enabled=1 aim_accel_turnrate_lerp=1200 aim_input_graph_enabled=1 aim_input_graph_index=3 aim_scale_view_axis=1 aim_turnrate_yaw=260 aim_turnrate_pitch=90 aim_turnrate_yaw_ads=90 aim_turnrate_pitch_ads=55 aim_autoaim_enabled=1 aim_lockon_enabled=1 aim_slowdown_enabled=1", a, " ")
      for (i = 1; i <= n; i++) {
        p = index(a[i], "=")
        k = substr(a[i], 1, p - 1); v = substr(a[i], p + 1)
        order[i] = k; want[k] = v
      }
    }
    $1 == "seta" && ($2 in want) {
      k = $2; seen[k] = 1
      if (sub(/^seta [^ ]+ "[^"]*"/, "seta " k " \"" want[k] "\"")) { print; next }
      printf "seta %s \"%s\"\n", k, want[k]; next
    }
    { print }
    END {
      for (i = 1; i <= n; i++) {
        k = order[i]
        if (!(k in seen)) printf "seta %s \"%s\"\n", k, want[k]
      }
    }
  ' "$1" > "$tmp"; then
    cmp -s "$tmp" "$1" && rm -f "$tmp" || mv -f "$tmp" "$1"
  else
    rm -f "$tmp"
  fi
}
# The desktop's logical size and refresh rate. Read before the display block:
# hold_1x_size starts the body from there, and on a first run there is no game
# profile to read the size from. (After restore_display: never the size a
# killed hold left the display in.) A hold of an earlier launch that is still
# on (its game has just closed and this one starts) is ended first, as
# hold_1x_size would do: it puts the desktop's mode back, and read before that
# the desktop's mode was the old hold's 1x one.
case "$t" in t4|t5|t6|iw4|iw5|t7|steam|bnet|iw6) stop_displaymode ;; esac
restore_display
desktop_rate=0
case "$t:${s_kind:-}" in iw6:*|steam:iw6) desktop_rate=1 ;; esac
# Single displaymode call replaces separate current + plan invocations.
read -r dw dh hz _ _ plan_hz plan_kind < <(SIL_KEEP_UNSCALED=$(keep_hidpi) "$kit/tools/displaymode" plan-full 2>/dev/null || true)
if [ "$desktop_rate" = 0 ] && on DISPLAY_MODE && [ -n "${dw:-}" ] && [ -n "${dh:-}" ]; then
  [[ ${plan_hz:-} =~ ^[1-9][0-9]*$ ]] && hz=$plan_hz
  printf 'Siliconium: display %sx%s, %s Hz while the game runs (%s)\n' "$dw" "$dh" "${hz:-?}" "${plan_kind:-?}" >&2
fi
maxfps=${MAXFPS:-${hz:-0}}
# DXVK's shader compiler threads: one per performance core, at most 8 (what an
# M1 Pro/Max uses). On a 4-performance-core Mac (M1, M2, M3) 8 threads competed
# with the game's own threads on the efficiency cores and made hitches longer.
dxvk_threads=$(sysctl -n hw.perflevel0.logicalcpu 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 8)
[[ $dxvk_threads =~ ^[0-9]+$ ]] || dxvk_threads=8
[ "$dxvk_threads" -gt 8 ] && dxvk_threads=8
[ "$dxvk_threads" -lt 2 ] && dxvk_threads=2
# Universal Apple Silicon hardware probes (M1-M5+, 8-128 GB RAM) used by
# first-start graphics defaults for heavy D3D11 titles (BO3, BO4, WWII).
sil_ram_gb=$(( $(sysctl -n hw.memsize 2>/dev/null || echo 17179869184) / 1073741824 ))
sil_gpu_cores=$(ioreg -rd1 -c IOAccelerator 2>/dev/null | awk -F'= ' '/gpu-core-count/{print $2; exit}')
[[ ${sil_gpu_cores:-} =~ ^[0-9]+$ ]] || sil_gpu_cores=10
export SIL_RAM_GB="$sil_ram_gb" SIL_GPU_CORES="$sil_gpu_cores" SIL_P_CORES="$dxvk_threads"
case "$t:$mode" in
  t6c:*|t6s:*)   # the campaign: its own folder; fullscreen at the desktop's size
    # No fullscreen or display-mode change for BO2 (see the t6:mp note below).
    for c in "$dir"/players/*.cfg; do console_aim "$c"; done ;;
  # BO2 keeps its own fullscreen mode and the desktop's display mode (HiDPI on a
  # 4K panel). Forcing real fullscreen made Wine switch the display to a 1x mode
  # of the game's size, which was slower here and left the window without frames.
  t6:*) : ;;
  # Steam Library: the fullscreen games (Direct3D 9, OpenGL) are held in a 1x
  # mode of the desktop's size; Ghosts runs borderless. Advanced Warfare is
  # held too (its own setup, s1; not Ghosts'), and Black Ops III (t7) as
  # BOIII is (DISPLAY_MODE: on a HiDPI desktop it otherwise switches to the
  # panel's full pixel size). Infinite Warfare (iw7) too: it is an exclusive-
  # fullscreen game like AW, and the hold puts the desktop's mode back when it
  # ends (Wine does not when a game is killed).
  # Black Ops II too, as Plutonium's BO2 is (hold_1x of its profile, further
  # down): on the scaled desktop (a 4K panel mode at 153 Hz) Steam's BO2 Zombies
  # missed 13-33 % of the refreshes; Plutonium's, held at 1x 160 Hz, none.
  # The Battle.net section's games (Black Ops 4: exclusive fullscreen, as
  # Black Ops III): held at the 1x mode of the desktop's size too
  # WWII (s2) too: exclusive fullscreen; left alone it switched the display
  # to the 1280x720 60 Hz mode of its first profile (2026-11-22)
  bnet:*) [ -n "${dw:-}" ] && [ -n "${dh:-}" ] && hold_1x_size "$dw $dh" ;;
  steam:*)
    case "$s_api:$s_kind" in
      gl:*|d3d9:*|d3d9x64:*|d3d11:t6|d3d11x64:s1|d3d11x64:t7|d3d11x64:iw7|d3d11x64:s2) [ -n "${dw:-}" ] && [ -n "${dh:-}" ] && hold_1x_size "$dw $dh" ;;
    esac ;;
  # Black Ops (t5) is held further down (hold_1x "$gamecfg"), as Black Ops II
  # is: after common_cvars has fitted its profile's r_mode to the desktop.
  # Held from the profile here, a desktop made smaller since the last game
  # (2560x1440 -> 1920x1080) got a 2560x1440 mode for the whole game, with the
  # game drawn 1920x1080 inside it and the Mac's windows rearranged.
  t4:*)
    # World at War: hold the mode it will run at from the desktop's *logical*
    # size, not from the profile. A first run has no profile yet, and the
    # game's own "Set Optimal Settings?" detection can leave one fullscreen at
    # the panel's pixel size (3840x2160 on a 1920x1080 desktop here): Wine then
    # makes a 4K window on a 1080p display, which looks hidden/black until the
    # game is minimized and reopened (that re-captures the display). Fitting
    # the profile to the desktop below keeps the window and the display mode
    # the same size, so minimizing cannot leave it off screen.
    waw_pcfg="$plutonium/storage/t4/players/profiles/\$\$\$"
    waw_cfg="$waw_pcfg/config.cfg"; [ "$mode" = mp ] && waw_cfg="$waw_pcfg/config_mp.cfg"
    if [ -n "${dw:-}" ] && [ -n "${dh:-}" ] && ! grep -q '^seta r_fullscreen "0"' "$waw_cfg" 2>/dev/null; then
      waw_res="$dw $dh"
      if ! on WAW_SCREEN; then
        # WAW_SCREEN=0: keep the size the player picked, as hold_1x used to.
        waw_saved=$(sed -n -E 's/^seta r_mode "([0-9]+)x([0-9]+)"/\1 \2/p' "$waw_cfg" 2>/dev/null | tail -1)
        [ -n "$waw_saved" ] && waw_res=$waw_saved
      fi
      fullscreen_cfg "$waw_cfg"
      hold_1x_size "$waw_res"
    fi ;;
esac

# --- Environment for the games ---------------------------------------------
# Plutonium starts the games with an environment built from HKCU\Environment.
# Clean any temp .reg files left behind by an interrupted earlier run.
rm -f "$home/cache"/sil-reg.* 2>/dev/null
# stop_all has flushed Wine's registry to disk (or prewarm left it unchanged),
# so reg_flush can diff queued changes against user.reg / system.reg and skip
# spawning wine regedit /S completely when every setting already matches (~3-9 s saved).
reg_disk_synced=1
[ "${prewarm_active:-0}" = 1 ] && reg_disk_synced=0
reg_pending=()
reg() {   # reg add|delete <key> /v <name> [/d <data>] /f
  local op=$1 key=$2 name= data= s
  shift 2
  while [ $# -gt 0 ]; do
    case "$1" in /v) name=$2; shift 2 ;; /d) data=$2; shift 2 ;; *) shift ;; esac
  done
  case "$key" in
    HKCU\\*) key="HKEY_CURRENT_USER\\${key#HKCU\\}" ;;
    HKLM\\*) key="HKEY_LOCAL_MACHINE\\${key#HKLM\\}" ;;
  esac
  s=${name//\\/\\\\}; name=${s//\"/\\\"}
  if [ "$op" = add ]; then
    s=${data//\\/\\\\}; data=${s//\"/\\\"}
    reg_pending+=("[$key]" "\"$name\"=\"$data\"")
  else
    reg_pending+=("[$key]" "\"$name\"=-")
  fi
}
reg_flush() {
  [ ${#reg_pending[@]} -gt 0 ] || return 0
  local file rc=0
  file=$(mktemp "$home/cache/sil-reg.XXXXXX") || return 0
  # Diff queued changes against Wine's on-disk registry (when Wine is stopped,
  # reg_disk_synced=1). If every setting already matches -> exit 10 (no-op).
  # If changes are needed while Wine is stopped -> atomically patch user.reg /
  # system.reg directly in ~15 ms (exit 11), skipping a 3-4 s cold wine regedit
  # boot on every game switch. Falls back to plain-loader wine regedit /S (exit 0)
  # if Wine is running or a hive cannot be patched directly.
  /usr/bin/python3 -I - "$WINEPREFIX" "$reg_disk_synced" "${prewarm_active:-0}" "$file" "${reg_pending[@]}" <<'PY'
import os, sys, tempfile, time

prefix, synced, prewarm, out_path = sys.argv[1], sys.argv[2] == "1", sys.argv[3] == "1", sys.argv[4]
pairs = sys.argv[5:]

def parse_val_line(line):
    if not line.startswith('"'):
        return None
    i, n = 1, len(line)
    while i < n:
        c = line[i]
        if c == '\\' and i + 1 < n:
            i += 2
            continue
        if c == '"':
            if i + 1 < n and line[i + 1] == '=':
                return line[1:i], line[i + 2:]
            return None
        i += 1
    return None

def load_wine_reg(path):
    if not os.path.isfile(path):
        return None
    try:
        with open(path, "r", encoding="utf-8", errors="surrogateescape") as f:
            lines = f.read().splitlines()
    except OSError:
        return None
    if not lines or lines[0] != "WINE REGISTRY Version 2":
        return None
    data = {}
    sec = None
    for line in lines:
        if line.startswith("["):
            r = line.rfind("]")
            if r > 1:
                sec = line[1:r].replace("\\\\", "\\").lower()
        elif sec is not None and line.startswith('"'):
            parsed = parse_val_line(line)
            if parsed is not None:
                data[(sec, parsed[0].lower())] = parsed[1]
    return data, lines

def patch_hive(path, lines, changes):
    """Apply (sub_orig, sub_low, nlow, vline, val) ops to a Wine v2 hive file."""
    by_sec = {}
    sec_order = []
    for sub_orig, sub_low, nlow, vline, val in changes:
        if sub_low not in by_sec:
            by_sec[sub_low] = (sub_orig, {})
            sec_order.append(sub_low)
        by_sec[sub_low][1][nlow] = (vline, val)

    out = []
    cur_sec = None
    handled_secs = set()
    pending_add = {}

    def flush_pending():
        nonlocal pending_add
        if not pending_add:
            return
        # Insert before trailing blank lines of the section
        blanks = []
        while out and out[-1] == "":
            blanks.append(out.pop())
        for nlow, (vline, val) in pending_add.items():
            if val != "-":
                out.append(vline)
        out.extend(reversed(blanks))
        pending_add = {}

    for line in lines:
        if line.startswith("["):
            flush_pending()
            r = line.rfind("]")
            cur_sec = line[1:r].replace("\\\\", "\\").lower() if r > 1 else None
            out.append(line)
            if cur_sec in by_sec and cur_sec not in handled_secs:
                handled_secs.add(cur_sec)
                pending_add = dict(by_sec[cur_sec][1])
            continue
        if cur_sec is not None and pending_add and line.startswith('"'):
            parsed = parse_val_line(line)
            if parsed is not None:
                nlow = parsed[0].lower()
                if nlow in pending_add:
                    vline, val = pending_add.pop(nlow)
                    if val != "-":
                        out.append(vline)
                    continue
        out.append(line)
    flush_pending()

    ts = str(int(time.time()))
    for sub_low in sec_order:
        if sub_low in handled_secs:
            continue
        sub_orig, kv = by_sec[sub_low]
        adds = [vline for vline, val in kv.values() if val != "-"]
        if not adds:
            continue
        if out and out[-1] != "":
            out.append("")
        out.append("[%s] %s" % (sub_orig.replace("\\", "\\\\"), ts))
        out.extend(adds)
        out.append("")

    payload = ("\n".join(out) + "\n").encode("utf-8", errors="surrogateescape")
    folder = os.path.dirname(os.path.abspath(path))
    fd, tmp = tempfile.mkstemp(prefix=".sil-hive-", dir=folder)
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(payload)
        try:
            os.chmod(tmp, os.stat(path).st_mode & 0o777)
        except OSError:
            pass
        os.replace(tmp, path)
    except OSError:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise

# Collapse pending ops in order (last write wins per (section, value)).
ops = {}
order = []
for i in range(0, len(pairs) - 1, 2):
    hdr, vline = pairs[i], pairs[i + 1]
    if not (hdr.startswith("[") and hdr.endswith("]")):
        continue
    key = hdr[1:-1]
    parsed = parse_val_line(vline)
    if parsed is None:
        continue
    name, val = parsed
    uk = key.upper()
    if uk.startswith("HKEY_CURRENT_USER\\"):
        hive, sub_orig = "user.reg", key[len("HKEY_CURRENT_USER\\"):]
    elif uk.startswith("HKEY_LOCAL_MACHINE\\"):
        hive, sub_orig = "system.reg", key[len("HKEY_LOCAL_MACHINE\\"):]
    else:
        hive, sub_orig = None, key
    sub = sub_orig.lower()
    slot = (hive, sub, name.lower())
    if slot not in ops:
        order.append(slot)
    ops[slot] = (hdr, sub_orig, vline, val)

hives = {}
kept = []
diff_disk = synced or prewarm
direct_ok = synced
per_hive_changes = {}
for slot in order:
    hive, sub, nlow = slot
    hdr, sub_orig, vline, val = ops[slot]
    if hive is None:
        direct_ok = False
    if diff_disk and hive is not None:
        if hive not in hives:
            hives[hive] = load_wine_reg(os.path.join(prefix, hive))
        loaded = hives[hive]
        if loaded is not None:
            reg_map = loaded[0]
            cur = reg_map.get((sub, nlow))
            if val == "-":
                if cur is None:
                    continue
            else:
                if cur == val:
                    continue
            per_hive_changes.setdefault(hive, []).append((sub_orig, sub, nlow, vline, val))
        else:
            direct_ok = False
    kept.append((hdr, vline))

if not kept:
    sys.exit(10)

if direct_ok and per_hive_changes:
    try:
        for hive, changes in per_hive_changes.items():
            patch_hive(os.path.join(prefix, hive), hives[hive][1], changes)
        sys.exit(11)
    except OSError:
        pass

out = ["Windows Registry Editor Version 5.00", ""]
last_hdr = None
for hdr, vline in kept:
    if hdr != last_hdr:
        out.append(hdr)
        last_hdr = hdr
    out.append(vline)
payload = ("\r\n".join(out) + "\r\n").encode("utf-16-le")
with open(out_path, "wb") as f:
    f.write(b"\xff\xfe" + payload)
PY
  rc=$?
  if [ "$rc" = 10 ] || [ "$rc" = 11 ]; then
    rm -f "$file"
    reg_pending=()
    return 0
  elif [ "$rc" != 0 ]; then
    # Fallback to direct UTF-16LE write if Python failed unexpectedly
    local line
    { printf '\xff\xfe'
      { printf 'Windows Registry Editor Version 5.00\r\n\r\n'
        for line in "${reg_pending[@]}"; do printf '%s\r\n' "$line"; done
      } | iconv -f UTF-8 -t UTF-16LE
    } > "$file"
  fi
  env -u WINELOADER "$plain_wine" regedit /S "$(sil_winpath "$file")" > /dev/null 2>&1 || true
  rm -f "$file"
  reg_pending=()
  reg_disk_synced=0
}
set_env() {
  export "$1=$2"
  reg add 'HKCU\Environment' /v "$1" /d "$2" /f
}
clear_env() {
  unset "$1"
  reg delete 'HKCU\Environment' /v "$1" /f
}
# Fast mtime+size stamp wrapper around statecache-merge.py: avoids spawning
# Python and SHA-1 hashing 20k+ entries on every launch when nothing changed.
merge_statecache() {   # merge_statecache <target> <source>...
  local target=$1 stamp sig= f st
  shift
  stamp="${target}.sil-merge.stamp"
  for f in "$target" "$@"; do
    if [ -f "$f" ]; then
      st=$(stat -f '%m:%z' "$f" 2>/dev/null || echo 0:0)
      sig+="${f}=${st};"
    fi
  done
  [ -f "$target" ] && [ -f "$stamp" ] && [ "$(cat "$stamp" 2>/dev/null)" = "$sig" ] && return 0
  mkdir -p "$(dirname -- "$target")" 2>/dev/null || true
  /usr/bin/python3 -I "$kit/tools/statecache-merge.py" "$target" "$@" 2>/dev/null || return 0
  sig=
  for f in "$target" "$@"; do
    if [ -f "$f" ]; then
      st=$(stat -f '%m:%z' "$f" 2>/dev/null || echo 0:0)
      sig+="${f}=${st};"
    fi
  done
  printf '%s' "$sig" > "$stamp" 2>/dev/null || true
}
# Variables an install of the previous name left in the prefix's environment
legacy_env=$(printf 'B%sM_' O)
while IFS= read -r v; do [ -n "$v" ] && clear_env "$v"; done \
  < <(grep -oE "^\"(__CX_UNIX_)?${legacy_env}[A-Z0-9_]+\"=" "$WINEPREFIX/user.reg" 2>/dev/null | tr -d '"=')

# The D3D11 games share DXMT's shader and frame-pacing settings.
dxmt_config() {
  local settings=$1 cap=$2 config
  if on "${settings}_ASYNC"; then config="d3d11.asyncPipelineCompile=True;"
  else config="d3d11.asyncPipelineCompile=False;"; fi
  if [ "$cap" != 0 ] && on "${settings}_FRAME_PACING"; then
    config="d3d11.preferredMaxFrameRate=$cap;$config"
  fi
  # Optional DXMT spatial upscale factor (opt-in only via DXMT_UPSCALE_FACTOR,
  # e.g. 1.3334 when running a game at 1080p on a 1440p monitor; DXMT upscales
  # the swapchain UP from the game's resolution, unlike mtld3d's render.scale).
  if [ -n "${DXMT_UPSCALE_FACTOR:-}" ]; then
    local fx_factor
    fx_factor=$(awk -v f="$DXMT_UPSCALE_FACTOR" 'BEGIN { if (f > 1.0 && f <= 2.0) printf "%.4f", f }')
    [ -n "$fx_factor" ] && config="${config}d3d11.metalSpatialUpscaleFactor=${fx_factor};"
  fi
  # <GAME>_TESS_FACTOR=4..64: d3d11.maxTessFactor (upstream ef11653); only
  # DXMT builds that have it read it (none shipped now; DXMT ignores unknown
  # options)
  local tf="${settings}_TESS_FACTOR"
  case "${!tf:-}" in [4-9]|[1-5][0-9]|6[0-4]) config="${config}d3d11.maxTessFactor=${!tf};" ;; esac
  printf '%s' "$config"
}

if [ "$t" = iw6 ]; then
  # Ghosts reads these values from config.cfg before opening its swap chain.
  # Existing windowed choices are kept. Move exclusive profiles to borderless
  # too, so Wine stops switching the physical display (often to 60 Hz).
  profile="$dir/players2/config.cfg"
  if ! grep -Eiq '^[[:space:]]*seta[[:space:]]+r_displayMode[[:space:]]+"windowed( \(no border\))?"' "$profile" 2>/dev/null; then
    mkdir -p "$(dirname -- "$profile")" || die "Could not create the Ghosts profile folder."
    original=/dev/null
    [ ! -f "$profile" ] || original="$profile"
    staged=$(mktemp "$profile.XXXXXX") || die "Could not stage the Ghosts video settings."
    if ! awk -v width="${dw:-}" -v height="${dh:-}" -v hz="${hz:-}" '
      BEGIN {
        mode = width ~ /^[1-9][0-9]*$/ && height ~ /^[1-9][0-9]*$/ ? width "x" height : ""
        refresh = hz ~ /^[1-9][0-9]*$/ ? hz " Hz" : ""
      }
      tolower($1) == "seta" {
        name = tolower($2)
        if (name == "r_displaymode" || name == "r_monitor" || name == "com_recommendedset" ||
            (mode && name == "r_mode") || (refresh && name == "r_displayrefresh")) next
      }
      { print }
      END {
        print "seta com_recommendedSet \"1\""
        print "seta r_displayMode \"windowed (no border)\""
        print "seta r_monitor \"0\""
        if (mode) printf "seta r_mode \"%s\"\n", mode
        if (refresh) printf "seta r_displayRefresh \"%s\"\n", refresh
      }
    ' "$original" > "$staged" || ! mv -f -- "$staged" "$profile"; then
      rm -f -- "$staged"
      die "Could not save the Ghosts video settings."
    fi
  fi

  # Apple-GPU tuning (IW6_TUNE=0 leaves the profile alone):
  # - every launch: never load NVIDIA's HBAO+/TXAA libraries nor run APEX
  #   turbulence (GPU PhysX): they are NVIDIA-only and only cost start-up time
  #   and memory under Wine;
  # - once per profile: tessellation off (Direct3D 11 hull/domain shaders are
  #   emulated on Metal and were the heaviest part of a frame) and motion blur
  #   off. What the player changes in the game's options afterwards is kept.
  if on IW6_TUNE && [ -f "$profile" ]; then
    tune_once=0; [ -f "$dir/players2/.sil-defaults-iw6" ] || tune_once=1
    iw6_picmip=0; [ "${sil_ram_gb:-16}" -le 8 ] && iw6_picmip=1
    staged=$(mktemp "$profile.XXXXXX") || die "Could not stage the Ghosts video settings."
    if awk -v once="$tune_once" -v picmip="$iw6_picmip" '
      BEGIN {
        # r_subdiv: subdivision surfaces stream their vertices out of a
        # shader into several buffers; DXMT emulates only the first ("only
        # slot 0 supported") and the GPU faulted (page fault, then every
        # command buffer ignored: the game froze after a few minutes).
        # r_ssao: its compute shader read far outside its buffer under DXMT
        # (Metal shader validation: "Invalid device load at offset
        # 18446743983515238400, executing kernel function cs_...") and the
        # GPU faulted: every command buffer ignored, the game froze.
        # r_subdivLimit 0: Catmull-Clark subdivision of characters and weapons
        # runs through the tessellation emulation of DXMT, which wrote outside its
        # threadgroup memory ~800 000 times in a few minutes ("Invalid
        # threadgroup store ... vshs_..."): heavy lag. Both every launch.
        n = split("cl_loadHBAODLL=0 cl_loadTXAADLL=0 r_apex_turbulence=0 r_ssao=0_Off r_tessellation=0_Off r_subdivLimit=0", a, " ")
        for (i = 1; i <= n; i++) { split(a[i], kv, "="); want[tolower(kv[1])] = kv[2]; name[tolower(kv[1])] = kv[1] }
        if (once) {
          # textures at full resolution on 16+ GB Macs (8 GB Macs use picmip=1
          # to avoid swap thrashing on Ghosts 6.7 GB footprint); VSync off so
          # DXMT preferredMaxFrameRate paces cleanly.
          n = split("r_vsync=0 r_mbEnable=0 r_mbEnableA=0 r_fur_shader=0 r_picmip_manual=1 r_picmip=" picmip " r_picmip_bump=" picmip " r_picmip_spec=" picmip " r_picmip_water=0", a, " ")
          for (i = 1; i <= n; i++) { split(a[i], kv, "="); want[tolower(kv[1])] = kv[2]; name[tolower(kv[1])] = kv[1] }
        }
      }
      tolower($1) == "seta" && (tolower($2) in want) { next }
      { print }
      END { for (k in want) printf "seta %s \"%s\"\n", name[k], want[k] }
    ' "$profile" > "$staged" && mv -f -- "$staged" "$profile"; then
      [ "$tune_once" = 1 ] && : > "$dir/players2/.sil-defaults-iw6"
    else
      rm -f -- "$staged"
    fi
  fi

  # Ghosts sizes its texture streaming for the GPU vendor it sees, and Apple's
  # (0x106b) is unknown to it: it streamed low-resolution textures however the
  # picmip settings were set. Present the GPU as an AMD Radeon (IW6_GPU_ID=0
  # keeps Apple's IDs); Metal does the drawing either way.
  iw6_ids=
  on IW6_GPU_ID && iw6_ids="dxgi.customVendorId=1002;dxgi.customDeviceId=67df;"
  export CX_GRAPHICS_BACKEND=dxmt DXMT_CONFIG="$iw6_ids$(dxmt_config IW6 "${IW6_MAXFPS:-${hz:-0}}")"
  if [ "${SIL_BO2_TRANSPARENT_CURSOR:-1}" = 0 ]; then unset SIL_BO2_TRANSPARENT_CURSOR
  else export SIL_BO2_TRANSPARENT_CURSOR=1; fi
  log="$home/logs/iw6-play.log"
  : > "$log"
  reg add 'HKCU\Software\Wine\AppDefaults\iw6sp64_ship.exe\Mac Driver' /v CaptureDisplaysForFullscreen /d n /f
  reg_flush
  cd -- "$dir" || die "Could not open the Ghosts game folder."
  # Ghosts writes __iw6sp64_ship while it runs and removes it when it quits.
  # A game stopped from the app (or that crashed) leaves it, and the next start
  # asks "Run In Safe Mode?", whose "Yes" lowers every video setting. The app
  # only starts Ghosts when it is not running, so the marker is stale here.
  rm -f -- __iw6sp64_ship

  # Keep Wine's cursor attached for Ghosts' menu. On Mac app reactivation,
  # restore the Win32 window if Ghosts still has it minimized.
  # shellcheck disable=SC2086
  iw6_args=
  # Catmull-Clark subdivision streams vertices out to several buffers; DXMT
  # emulates only the first and the GPU faulted (the game froze). Not a saved
  # setting, so it goes on the command line.
  on IW6_TUNE && iw6_args="+set r_subdiv 0 +set r_adaptiveSubdiv 0"
  WINE_MAC_MOUSELOOK=0 "$wine" ./iw6sp64_ship.exe $iw6_args ${GAME_ARGS:-} >> "$log" 2>&1 &
  game_pid=$!
  SIL_FOCUS_FROM="$sil_focus_from" "$kit/payload/iw6/iw6-focus" "$game_pid" "$wine" "$kit/payload/iw6/iw6-restore.exe" >> "$log" 2>&1 &
  focus_pid=$!
  trap 'kill "$focus_pid" 2>/dev/null || true' EXIT
  wait "$game_pid" || die "Ghosts exited with an error (see logs/iw6-play.log)"
  exit 0
fi

# Black Ops II (all of it: Plutonium MP/Zombies and the campaign): two of our
# winemac changes are gated by these, so the other games keep Wine's behaviour.
# - SIL_BO2_TRANSPARENT_CURSOR: on macOS 26+ hiding the native cursor makes
#   frame presentation wait on cursor movement, so a 1000 Hz mouse dropped the
#   game from its 160 FPS cap to 90-100 whenever it moved (Wine MR !11880). Use
#   an invisible cursor instead, and hide the Dock/menu bar so the pointer
#   cannot reveal them at the screen edges (BO2's menus are not captured).
# (A pixel-perfect 1x display mode was tried too; on this 4K panel it made the
# game slower, so it is not applied. Do not set SIL_PIXEL_PERFECT_FULLSCREEN.)
case "$cursor_fix" in
  1)
    if [ "${SIL_BO2_TRANSPARENT_CURSOR:-1}" = 0 ]; then
      unset SIL_BO2_TRANSPARENT_CURSOR
      clear_env __CX_UNIX_SIL_BO2_TRANSPARENT_CURSOR
    else
      export SIL_BO2_TRANSPARENT_CURSOR=1
      # CrossOver promotes __CX_UNIX_ variables for Windows-launched children.
      set_env __CX_UNIX_SIL_BO2_TRANSPARENT_CURSOR 1
    fi
    ;;
  *)
    unset SIL_BO2_TRANSPARENT_CURSOR
    if [ -n "${__CX_UNIX_SIL_BO2_TRANSPARENT_CURSOR:-}" ] ||
       grep -q '^"__CX_UNIX_SIL_BO2_TRANSPARENT_CURSOR"=' "$WINEPREFIX/user.reg" 2>/dev/null; then
      clear_env __CX_UNIX_SIL_BO2_TRANSPARENT_CURSOR
    fi
    ;;
esac
# - SIL_REAPPLY_GAMMA (Call of Duty, Steam): Wine gives the displays back to
#   macOS when a fullscreen game loses focus, which also restores macOS's gamma;
#   Call of Duty sets its ramp once (its overbright lighting doubles the picture
#   through it), so after Cmd+Tab or minimize it came back at half brightness.
#   winemac applies the game's last ramp again when it is active (as Windows
#   keeps it). United Offensive: the same engine.
if [ "$t" = steam ] && { [ "${s_id:-}" = cod1 ] || [ "${s_id:-}" = uo ]; } && [ "$cursor_fix" = 1 ]; then
  export SIL_REAPPLY_GAMMA=1
  set_env __CX_UNIX_SIL_REAPPLY_GAMMA 1
else
  unset SIL_REAPPLY_GAMMA
  if [ -n "${__CX_UNIX_SIL_REAPPLY_GAMMA:-}" ] ||
     grep -q '^"__CX_UNIX_SIL_REAPPLY_GAMMA"=' "$WINEPREFIX/user.reg" 2>/dev/null; then
    clear_env __CX_UNIX_SIL_REAPPLY_GAMMA
  fi
fi
# - SIL_HIDE_ON_DEACTIVATE (every game; HIDE_ON_CMDTAB=0 in settings.conf: off):
#   without display capture (so the screen can be recorded) macOS handles
#   Cmd-Tab itself and the game was only deactivated: its fullscreen window
#   stayed on screen, black, behind the other app (2026-11-24). winemac now
#   hides the game when another regular app comes to the front, as Wine did on
#   Cmd-Tab while the displays were captured (1.0.0) and as Windows does on
#   Alt-Tab (wine-winemac-hide-on-deactivate.patch); Cmd-Tab back shows it.
#   Only a window that covers the screen, never in the game's first 3 s in
#   front. iw6-focus's own hide could not do it (macOS hides another app
#   asynchronously, and the helper is throttled while Game Mode is on).
#   With it, a program the player left neither activates nor unhides itself
#   until the player brings it back (Windows' foreground lock): Black Ops II,
#   after its display mode was changed in its options, came back in front by
#   itself 17-29 ms after each Cmd-Tab and then took no click (2026-11-24).
#   Whatever the game does with its window then (fullscreen, fullscreen
#   window, windowed) cannot pull it in front.
# - SIL_DISPLAYMODE_RECORD (only with CMDTAB_DESKTOP_MODE=1, off by default):
#   while the game is hidden, the desktop has its own mode back (HiDPI, sharp)
#   and the game's 1x mode returns when the player comes back. Off since
#   2026-11-24 (owner: "TODOS LOS JUEGOS en 1x, en su mejor performance"):
#   each Cmd-Tab then reconfigured the display twice (the monitor resyncs, black,
#   on every return) and Wine told the game the display changed each time
#   (DisplayModeChanged -> WM_DISPLAYCHANGE), not shown to be harmless for
#   exclusive-fullscreen D3D9 / DXMT games (6 switches in the owner's black
#   Black Ops run). The game stays at 1x until it quits; the hold then puts the
#   desktop's mode back.
unset SIL_HIDE_ON_DEACTIVATE SIL_DISPLAYMODE_RECORD
clear_vars=
if [ "${HIDE_ON_CMDTAB:-1}" != 0 ]; then
  export SIL_HIDE_ON_DEACTIVATE=1
  set_env __CX_UNIX_SIL_HIDE_ON_DEACTIVATE 1
  if [ "${CMDTAB_DESKTOP_MODE:-0}" = 1 ]; then
    export SIL_DISPLAYMODE_RECORD="$home/cache/displaymode-desktop"
    set_env __CX_UNIX_SIL_DISPLAYMODE_RECORD "$home/cache/displaymode-desktop"
  else clear_vars=__CX_UNIX_SIL_DISPLAYMODE_RECORD; fi
else
  clear_vars="__CX_UNIX_SIL_HIDE_ON_DEACTIVATE __CX_UNIX_SIL_DISPLAYMODE_RECORD"
fi
for v in $clear_vars; do
  if [ -n "${!v:-}" ] || grep -q "^\"$v\"=" "$WINEPREFIX/user.reg" 2>/dev/null; then clear_env "$v"; fi
done
# Mouse look (winemac): keep Wine's cursor position while mouse look is active
# (WINE_MAC_MOUSELOOK=2; wine-winemac-mouselook-position.patch +
# wine-winemac-mouselook-input.patch) across every game and launcher (Plutonium,
# IW4X, CoD4X, BOIII/Ezz, Steam, Battle.net), except Ghosts and Advanced Warfare.
case "$t:${s_kind:-}" in
  iw6:*|steam:iw6|steam:s1) ml_mode="${WINE_MAC_MOUSELOOK:-0}" ;;
  *)                        ml_mode="${WINE_MAC_MOUSELOOK:-2}" ;;
esac
export WINE_MAC_MOUSELOOK="$ml_mode"
set_env __CX_UNIX_WINE_MAC_MOUSELOOK "$ml_mode"

if [ "${X87:-1}" = 1 ] && [ -x "$engine/bin/x87sidecar" ]; then
  # Through payload/x87/x87-bundle (tools/x87-bundle.c) when the Game Mode
  # bundle is in use: Wine starts these programs under the sidecar from a bare
  # link of its loader, so they had no Game Mode and macOS would not make them
  # the active app (the menu bar stayed over the game until a click); the
  # shim hands the sidecar the bundle's copy of the loader instead
  if [ -x "$kit/payload/x87/x87-bundle" ] && [ -n "${WINELOADER:-}" ]; then
    set_env X87_SIDECAR_PATH "$kit/payload/x87/x87-bundle"
    set_env SIL_X87_SIDECAR "$engine/bin/x87sidecar"
  else
    set_env X87_SIDECAR_PATH "$engine/bin/x87sidecar"
  fi
  # Plutonium's games, the campaign's t6sp.exe (it crashed under an older
  # sidecar; with x87sidecar 1.9 it runs, and is CPU-bound without it),
  # Modern Warfare 3's iw5mp.exe and Modern Warfare 2's iw4x.exe
  if [ "$t" = steam ]; then
    x87_list="t6sp.exe:$steam_x87_programs"
    # 32-bit retail/offline MW2 & MW3 (or mixed-case 32-bit exes) also run under x87sidecar
    if [ "${s_api:-}" = d3d9 ] || [ "${s_api:-}" = d3d11 ]; then
      case ":$x87_list:" in *":$s_exe:"*) ;; *) x87_list="$x87_list:$s_exe" ;; esac
    fi
    set_env X87_SIDECAR_PROGRAMS "$x87_list"
  else set_env X87_SIDECAR_PROGRAMS plutonium-bootstrapper-win32.exe:t6sp.exe:iw5mp.exe:iw4x.exe:iw4x-sp.exe; fi
else
  # X87=0: Rosetta's own x87 emulation (exact, if slower)
  clear_env X87_SIDECAR_PATH; clear_env X87_SIDECAR_PROGRAMS; clear_env SIL_X87_SIDECAR
fi
if on EXEC_ON_DEMAND; then clear_env BO_EXEC_ON_DEMAND; else set_env BO_EXEC_ON_DEMAND 0; fi
xi="$engine/lib/wine/i386-windows"
if on RUMBLE_FIX; then xsrc="$xi/xinput1_3.sil.dll"; else xsrc="$xi/xinput1_3.cx.dll"; fi
[ -f "$xsrc" ] && ! cmp -s "$xsrc" "$xi/xinput1_3.dll" && cp "$xsrc" "$xi/xinput1_3.dll"
wb="$engine/lib/wine/x86_64-windows"
if on RUMBLE_FIX; then wsrc="$wb/winebus.sil.sys"; else wsrc="$wb/winebus.cx.sys"; fi
[ -f "$wsrc" ] && ! cmp -s "$wsrc" "$wb/winebus.sys" && cp "$wsrc" "$wb/winebus.sys"
# Black Ops 1 (DXVK): background pipeline compilation and a persistent
# pipeline list; MoltenVK's translated shaders are kept by the engine's shim.
# Our DXVK also compiles in the background during BO1's one-frame shader
# warming pass (it reads the game's warming flag), so warming only queues.
dxvk_cache="$home/cache"
if [ "$t" = iw5 ] || [ "$t" = iw4 ] || [ "$t" = steam ]; then
  # Both Modern Warfare clients use the patched D3D9 renderer. The shader
  # warming flag and wait in that renderer are specific to Black Ops.
  shader_settings=BO1
  dxvk_config_dir="$dxvk_cache/$t"
  if [ "$t" = iw5 ]; then
    shader_settings=IW5
    # Plutonium runs both BO1 and MW3 as plutonium-bootstrapper-win32.exe.
    # Keep MW3's pipeline list separate from the BO1 list we ship and merge.
    dxvk_cache="$dxvk_config_dir"
  elif [ "$t" = steam ]; then
    # Steam Library / Your Own Game Files: each game its own pipeline list and settings
    shader_settings=STEAM
    steam_cache_tag="steam-$s_id"
    [ "${s_client:-}" = own ] && steam_cache_tag="own-$s_id"
    dxvk_config_dir="$dxvk_cache/$steam_cache_tag"
    dxvk_cache="$dxvk_config_dir"
  fi
  mkdir -p "$dxvk_config_dir" || die "Could not create the $game graphics cache directory."
  dxvk_config="$dxvk_config_dir/dxvk.conf"
  {
    printf '%s\n' 'd3d9.numBackBuffers = 3' "dxvk.numCompilerThreads = $dxvk_threads" "dxvk.numAsyncThreads = $dxvk_threads"
    if [ "$maxfps" != 0 ]; then printf 'd3d9.maxFrameRate = %s\n' "$maxfps"; fi
  } > "$dxvk_config" || die "Could not write the $game graphics configuration."
  set_env DXVK_CONFIG_FILE "Z:${dxvk_config//\//\\}"
  # IW4X: compile every missing pipeline in the background, even for a render
  # target bound for the first time this frame (DXVK_ASYNC=2). Its new areas
  # and effects otherwise compile on the render thread for the first frames
  # and freeze the game; with 2 they are queued and appear a frame later.
  if on "${shader_settings}_ASYNC"; then
    if [ "$t" = iw4 ]; then set_env DXVK_ASYNC "${IW4_ASYNC_LEVEL:-2}"
    elif [ "$t" = steam ]; then set_env DXVK_ASYNC "${STEAM_ASYNC_LEVEL:-$s_async}"
    else set_env DXVK_ASYNC "${IW5_ASYNC_LEVEL:-1}"; fi
  else set_env DXVK_ASYNC 0; fi
  set_env DXVK_WARM_ASYNC 0; set_env DXVK_WARM_WAIT 0
  # Black Ops on Steam: its BlackOps.exe is the executable Plutonium runs (the
  # warming tag our DXVK reads is at the same address), so its one-frame
  # shader warming pass compiles in the background and the load screen waits
  # for it, as with Plutonium (BO1_WARM=0: off)
  if { [ "$t:${s_exe:-}" = steam:BlackOps.exe ] || [ "$t:${s_exe:-}" = steam:BlackOpsMP.exe ]; } && on BO1_WARM; then
    clear_env DXVK_WARM_ASYNC; clear_env DXVK_WARM_WAIT
  fi
  if on "${shader_settings}_SHADER_CACHE"; then clear_env MVKCACHE_OFF; clear_env DXVK_STATE_CACHE
  else set_env MVKCACHE_OFF 1; set_env DXVK_STATE_CACHE 0; fi
  if on "${shader_settings}_METAL_PARALLEL"; then set_env MVK_CONFIG_SHOULD_MAXIMIZE_CONCURRENT_COMPILATION 1
  else clear_env MVK_CONFIG_SHOULD_MAXIMIZE_CONCURRENT_COMPILATION; fi
else
  # Plutonium can build a fresh environment from the registry for its child.
  # Drop the managed Modern Warfare config before starting another game.
  registry_cache_path="Z:${dxvk_cache//\//\\\\}"
  if grep -Fq -e "\"DXVK_CONFIG_FILE\"=\"${registry_cache_path}\\\\iw4\\\\dxvk.conf\"" \
               -e "\"DXVK_CONFIG_FILE\"=\"${registry_cache_path}\\\\iw5\\\\dxvk.conf\"" "$WINEPREFIX/user.reg" 2>/dev/null; then
    reg delete 'HKCU\Environment' /v DXVK_CONFIG_FILE /f
  fi
  # BO1 runs inside Plutonium's bootstrapper, where DXVK's warming-flag
  # detection (a fixed address in t5sp.exe) never matches: the warming pass
  # compiled on the render thread, so the first visit to a multiplayer map
  # took a minute and new effects hitched (and crackled the audio). Compile
  # every missing pipeline in the background instead, as for IW4X
  # (DXVK_ASYNC=2); the map's pipelines queue while it loads and a new effect
  # appears a frame later instead of stopping the frame that draws it.
  # T5 had gone back to 1 (with 2 and a cold MoltenVK cache on a fresh engine,
  # new in-game materials stayed black until their pipeline finished). Measured
  # again 2026-11-23 on maps never loaded before (warm engine): with 1 the
  # render thread compiled every pipeline of a newly bound render target, so a
  # new multiplayer map loaded in 38 s and froze 0.4-1 s in play and on the
  # class menu; with 2: 12 s, worst frame 56-69 ms in Multiplayer, Zombies and
  # the campaign, every material drawn from the first frames. Both T4 and T5
  # use 2; BO1_ASYNC_LEVEL / WAW_ASYNC_LEVEL=1 bring back the render-thread
  # compiles.
  if on BO1_ASYNC; then
    if [ "$t" = t4 ]; then set_env DXVK_ASYNC "${WAW_ASYNC_LEVEL:-2}"; else set_env DXVK_ASYNC "${BO1_ASYNC_LEVEL:-2}"; fi
    clear_env DXVK_WARM_ASYNC
  else set_env DXVK_ASYNC 0; set_env DXVK_WARM_ASYNC 0; fi
  if on BO1_WARM; then clear_env DXVK_WARM_WAIT; else set_env DXVK_WARM_WAIT 0; fi
  # Let Metal compile on every core at once (by default macOS runs only a few
  # shader compilations at a time, and BO1's first shader warming took minutes),
  # and skip MoltenVK's timing of every call.
  if on BO1_METAL_PARALLEL; then set_env MVK_CONFIG_SHOULD_MAXIMIZE_CONCURRENT_COMPILATION 1
  else clear_env MVK_CONFIG_SHOULD_MAXIMIZE_CONCURRENT_COMPILATION; fi
  if on BO1_SHADER_CACHE; then clear_env MVKCACHE_OFF; clear_env DXVK_STATE_CACHE
  else set_env MVKCACHE_OFF 1; set_env DXVK_STATE_CACHE 0; fi
fi
set_env MVK_CONFIG_PERFORMANCE_TRACKING 0
# Silence MoltenVK info extension spam (360+ lines per VkInstance) and DXVK
# info log file creation by default; explicit caller overrides still win.
set_env MVK_CONFIG_LOG_LEVEL "${MVK_CONFIG_LOG_LEVEL:-1}"
set_env DXVK_LOG_LEVEL "${DXVK_LOG_LEVEL:-none}"
# Never leak BO1 MP's DXVK_T5MP_WARM into other Plutonium / Steam / IW games.
if [ "$t" != t5 ] && grep -q '^"DXVK_T5MP_WARM"=' "$WINEPREFIX/user.reg" 2>/dev/null; then
  clear_env DXVK_T5MP_WARM
fi
if [ "$mtld3d_active" = 1 ]; then
  mtld3d_logs="$home/logs/mtld3d"
  mkdir -p "$mtld3d_logs" 2>/dev/null || true
  mtld3d_cfg="log.dir=\"Z:${mtld3d_logs//\//\\}\";present.maxFps=$maxfps;color.hdr.enable=false;query.eventImmediate=true"
  # WaW and BO1 (Treyarch T4/T5 engine) poll occlusion queries with
  # D3DGETDATA_FLUSH (sun flares, spotlights, fire); answering immediately avoids
  # mid-frame Metal command-buffer flushes and periodic sawtooth frame spikes.
  if [ "$t" = t4 ] || [ "$t" = t5 ] || { [ "$t" = steam ] && { [ "${s_id:-}" = waw ] || [ "${s_id:-}" = bo1 ]; }; }; then
    mtld3d_cfg+=";query.flushImmediate=true"
  fi
  if [ "$t" = iw5 ]; then
    on IW5_SHADER_CACHE || mtld3d_cfg+=";shaderCache.enable=false"
    on IW5_ASYNC || mtld3d_cfg+=";shader.asyncCompile=false"
  elif [ "$t" = steam ]; then
    on STEAM_SHADER_CACHE || mtld3d_cfg+=";shaderCache.enable=false"
    on STEAM_ASYNC || mtld3d_cfg+=";shader.asyncCompile=false"
  else
    on BO1_SHADER_CACHE || mtld3d_cfg+=";shaderCache.enable=false"
    on BO1_ASYNC || mtld3d_cfg+=";shader.asyncCompile=false"
  fi
  # Optional MetalFX spatial scaling (METALFX_SCALE in [0.5, 0.99], default native 1.0).
  if [ -n "${METALFX_SCALE:-}" ]; then
    mtld3d_scale=$(awk -v s="$METALFX_SCALE" 'BEGIN { if (s >= 0.5 && s < 0.99) printf "%.2f", s }')
    [ -n "$mtld3d_scale" ] && mtld3d_cfg+=";render.scale=$mtld3d_scale"
  fi
  [ -n "${MTLD3D_EXTRA:-}" ] && mtld3d_cfg+=";$MTLD3D_EXTRA"
  set_env MTLD3D_CONFIG "$mtld3d_cfg"
  set_env RUST_LOG "${RUST_LOG:-mtld3d=warn}"
else
  grep -q '^"MTLD3D_CONFIG"=' "$WINEPREFIX/user.reg" 2>/dev/null && clear_env MTLD3D_CONFIG
  grep -q '^"RUST_LOG"=' "$WINEPREFIX/user.reg" 2>/dev/null && clear_env RUST_LOG
fi
bo1_cache="$home/cache/bo1"
bo1_mp_cache="$home/cache/bo1-mp"
t4_cache="$home/cache/t4"
if [ "$t:$mode" = t5:mp ]; then
  mkdir -p "$bo1_mp_cache" || die "Could not create the Black Ops Multiplayer graphics cache directory."
  dxvk_cache="$bo1_mp_cache"
elif [ "$t" = t5 ]; then
  mkdir -p "$bo1_cache" || die "Could not create the Black Ops graphics cache directory."
  dxvk_cache="$bo1_cache"
elif [ "$t" = t4 ]; then
  mkdir -p "$t4_cache" || die "Could not create the World at War graphics cache directory."
  dxvk_cache="$t4_cache"
fi
set_env DXVK_STATE_CACHE_PATH "Z:${dxvk_cache//\//\\}"
# Keep every D3D9 game's MoltenVK shader cache isolated so games never share or
# bloat one another's pipeline shards (T4 WaW, T5 BO1 SP/ZM, T5 MP, IW4X, IW5).
iw4_mvk_cache="$home/cache/iw4/mvkcache.bin"
iw5_mvk_cache="$home/cache/iw5/mvkcache.bin"
bo1_mvk_cache="$bo1_cache/mvkcache.bin"
bo1_mp_mvk_cache="$bo1_mp_cache/mvkcache.bin"
t4_mvk_cache="$t4_cache/mvkcache.bin"
if [ "$t" = iw4 ]; then
  set_env MVKCACHE_FILE "${MVKCACHE_FILE:-$iw4_mvk_cache}"
elif [ "$t:$mode" = iw5:mp ]; then
  set_env MVKCACHE_FILE "${MVKCACHE_FILE:-$iw5_mvk_cache}"
elif [ "$t:$mode" = t5:mp ]; then
  set_env MVKCACHE_FILE "${MVKCACHE_FILE:-$bo1_mp_mvk_cache}"
elif [ "$t" = t5 ]; then
  set_env MVKCACHE_FILE "${MVKCACHE_FILE:-$bo1_mvk_cache}"
elif [ "$t" = t4 ]; then
  set_env MVKCACHE_FILE "${MVKCACHE_FILE:-$t4_mvk_cache}"
elif [ "$t" = steam ]; then
  # Black Ops Multiplayer keeps its own, as with Plutonium (bo1-mp)
  if [ "${s_exe:-}" = BlackOpsMP.exe ]; then mkdir -p "$home/cache/$steam_cache_tag/mp"; set_env MVKCACHE_FILE "${MVKCACHE_FILE:-$home/cache/$steam_cache_tag/mp/mvkcache.bin}"
  else set_env MVKCACHE_FILE "${MVKCACHE_FILE:-$home/cache/$steam_cache_tag/mvkcache.bin}"; fi
elif grep -Fxq -e "\"MVKCACHE_FILE\"=\"$iw4_mvk_cache\"" \
                -e "\"MVKCACHE_FILE\"=\"$iw5_mvk_cache\"" \
                -e "\"MVKCACHE_FILE\"=\"$bo1_mvk_cache\"" \
                -e "\"MVKCACHE_FILE\"=\"$bo1_mp_mvk_cache\"" \
                -e "\"MVKCACHE_FILE\"=\"$t4_mvk_cache\"" "$WINEPREFIX/user.reg" 2>/dev/null; then
  reg delete 'HKCU\Environment' /v MVKCACHE_FILE /f
fi
# Black Ops III (BOIII and Steam BO3): always run at native desktop WindowSize
# (using BO3's own ResolutionPercent for crisp native-resolution HUD/menus;
# DXMT's swapchain-level metalSpatialUpscaleFactor zooms/clips 1x fullscreen
# menus and supersamples to 3413x1920 after Cmd+Tab or display-mode changes).
# Advanced/dev callers can still set DXMT_UPSCALE_FACTOR explicitly.
bo3_win_w=${dw:-} bo3_win_h=${dh:-} bo3_metalfx_active=0
export SIL_BO3_WIN_W="$bo3_win_w" SIL_BO3_WIN_H="$bo3_win_h" SIL_BO3_METALFX="$bo3_metalfx_active"
set_env DXMT_CONFIG "$(dxmt_config BO2 "$maxfps")"
if [ "$t" = steam ] && [ "$s_kind" = iw6 ]; then
  steam_ids=; on IW6_GPU_ID && steam_ids="dxgi.customVendorId=1002;dxgi.customDeviceId=67df;"
  set_env DXMT_CONFIG "$steam_ids$(dxmt_config IW6 "${IW6_MAXFPS:-$maxfps}")"
fi
# Advanced Warfare: DXMT's defaults (async pipelines, pacing at the refresh
# rate) without Ghosts' AMD GPU id; AW_ASYNC / AW_FRAME_PACING=0 turn them off
[ "$t" = steam ] && [ "${s_kind:-}" = s1 ] && set_env DXMT_CONFIG "$(dxmt_config AW "$maxfps")"
# Infinite Warfare: the same defaults under its own switches (IW7_ASYNC /
# IW7_FRAME_PACING=0), no GPU id change (it reads the Apple GPU as is)
[ "$t" = steam ] && [ "${s_kind:-}" = iw7 ] && set_env DXMT_CONFIG "$(dxmt_config IW7 "$maxfps")"
# WWII: the same defaults under its own switches (WW2_ASYNC /
# WW2_FRAME_PACING=0), no GPU id change
[ "$t" = steam ] && [ "${s_kind:-}" = s2 ] && set_env DXMT_CONFIG "$(dxmt_config WW2 "$maxfps")"
# The Battle.net section's games: DXMT's defaults under their own switches
# (Black Ops 4: BO4_ASYNC / BO4_FRAME_PACING=0 turn them off)
[ "$t" = bnet ] && set_env DXMT_CONFIG "$(dxmt_config "$b_dxmt" "$maxfps")"
# IW7-Mod's Metal folder = Steam's Infinite Warfare's (DXMT keeps Metal's
# compiled shaders in dxmt/<executable>/com.apple.metal and has no setting for
# it): a link, made once; translations IW7-Mod had made on its own are merged
# into Steam's game's databases first (insert or ignore: same keys, same
# shaders)
iw7_shared_metal() {   # <DXMT's cache folder>
  local dxmt=$1 shared own db
  case "$dxmt" in /?*/dxmt) ;; *) return 0 ;; esac
  shared="$dxmt/iw7_ship.exe" own="$dxmt/$s_exe"
  mkdir -p "$shared/com.apple.metal" "$own" || return 0
  [ -L "$own/com.apple.metal" ] && return 0
  for db in "$own"/shaders_*.db "$own"/airconv-aw5/shaders_*.db; do
    [ -f "$db" ] || continue
    mkdir -p "$(dirname "$shared/${db#"$own"/}")" || continue
    /usr/bin/sqlite3 "$shared/${db#"$own"/}" "attach '$db' as s; create table if not exists main.cache_18 (key BLOB PRIMARY KEY, value BLOB NOT NULL); insert or ignore into main.cache_18 select key, value from s.cache_18;" 2>/dev/null || true
  done
  rm -rf "$own/com.apple.metal" && ln -s "$shared/com.apple.metal" "$own/com.apple.metal"
}
# Black Ops II (Steam): the shader caches of Plutonium's BO2. DXMT keeps one
# per executable (dxmt/<exe>/ in the user cache folder: shaders_*.db, the
# translated shaders, and com.apple.metal, Metal's compiled ones), so Steam's
# t6sp/t6mp/t6zm started cold although they draw the same shaders (620 of
# t6mp's first 851 keys were already in Plutonium's): a 1.1 s freeze at the
# first shot and textures black for a moment. DXMT_SHADER_CACHE_PATH moves the
# database; Metal's folder has no setting, so it becomes a link. Steam's own
# entries are merged in once. BO2_SHARED_CACHE=0 keeps them apart.
if [ "$t" = steam ] && [ "${s_kind:-}" = t6 ] && on BO2_SHARED_CACHE; then
  dxmt_cache="$(getconf DARWIN_USER_CACHE_DIR 2>/dev/null)dxmt"
  shared="$dxmt_cache/plutonium-bootstrapper-win32.exe"
  own="$dxmt_cache/$s_exe"
  if [ "$dxmt_cache" != dxmt ] && mkdir -p "$shared/com.apple.metal" "$own"; then
    if [ ! -L "$own/com.apple.metal" ]; then
      for db in "$own"/shaders_*.db; do
        [ -f "$db" ] || continue
        /usr/bin/sqlite3 "$shared/${db##*/}" "attach '$db' as s; create table if not exists main.cache_18 (key BLOB PRIMARY KEY, value BLOB NOT NULL); insert or ignore into main.cache_18 select key, value from s.cache_18;" 2>/dev/null || true
      done
      rm -rf "$own/com.apple.metal" && ln -s "$shared/com.apple.metal" "$own/com.apple.metal"
    fi
    set_env DXMT_SHADER_CACHE_PATH "$shared"
  fi
# Advanced Warfare with Siliconium's tessellation-fixed DXMT translator (now unified
# in the engine's winemetal.so): keep its airconv-aw5 shader database so warm caches
# stay hot and never reload stale pre-fix shaders from the default root folder.
elif [ "$t" = steam ] && [ "${s_kind:-}" = s1 ] && { [ -f "${AW_DXMT_DIR:-/nonexistent}/x86_64-unix/winemetal.so" ] ||
     on AW_DXMT_FIX; }; then
  aw_cache="$(getconf DARWIN_USER_CACHE_DIR 2>/dev/null)dxmt/$s_exe/airconv-aw5"
  # a whole DXMT build under test (AW_DXMT_DIR): its own database
  [ -f "${AW_DXMT_DIR:-/nonexistent}/x86_64-unix/winemetal.so" ] && aw_cache="${aw_cache%/*}/test-$(basename "$AW_DXMT_DIR")"
  if [ "${aw_cache#/}" != "$aw_cache" ] && mkdir -p "$aw_cache"; then set_env DXMT_SHADER_CACHE_PATH "$aw_cache"
  else clear_env DXMT_SHADER_CACHE_PATH; fi
# Infinite Warfare & IW7-Mod with the unified tessellation-fixed DXMT translator:
# share iw7_ship.exe/airconv-aw5 and Metal's compiled shaders so neither starts
# cold after the other was played (first cold "Preloading Shaders" ~3.5 min).
elif [ "$t" = steam ] && [ "${s_kind:-}" = iw7 ] && on IW7_DXMT_FIX &&
     cmp -s "$engine/lib/wine/x86_64-windows/winemetal.dll" "$kit/payload/dxmt/x86_64-windows/winemetal.dll"; then
  iw_cache="$(getconf DARWIN_USER_CACHE_DIR 2>/dev/null)dxmt/iw7_ship.exe/airconv-aw5"
  if [ "${iw_cache#/}" != "$iw_cache" ] && mkdir -p "$iw_cache"; then set_env DXMT_SHADER_CACHE_PATH "$iw_cache"
  else clear_env DXMT_SHADER_CACHE_PATH; fi
  [ "$s_exe" = iw7_ship.exe ] || iw7_shared_metal "$(getconf DARWIN_USER_CACHE_DIR 2>/dev/null)dxmt"
# IW7-Mod on the engine's DXMT (IW7_DXMT_FIX=0): Steam's Infinite Warfare's
# engine-translator database and Metal folder, as above
elif [ "$t" = steam ] && [ "${s_kind:-}" = iw7 ] && [ "$s_exe" != iw7_ship.exe ]; then
  iw_cache="$(getconf DARWIN_USER_CACHE_DIR 2>/dev/null)dxmt/iw7_ship.exe"
  if [ "${iw_cache#/}" != "$iw_cache" ] && mkdir -p "$iw_cache"; then set_env DXMT_SHADER_CACHE_PATH "$iw_cache"
  else clear_env DXMT_SHADER_CACHE_PATH; fi
  iw7_shared_metal "$(getconf DARWIN_USER_CACHE_DIR 2>/dev/null)dxmt"
# SIL_DXMT_SO=<winemetal.so> SIL_DXMT_CACHE=<absolute folder> (development
# only): a Steam Library Direct3D 11 game runs from a clone of the engine with
# that DXMT translator (see the Steam block) and its own translated-shader
# database; nothing changes unless both are set
elif [ "$t" = steam ] && [ -f "${SIL_DXMT_SO:-/nonexistent}" ] && case "${SIL_DXMT_CACHE:-}" in /?*) true ;; *) false ;; esac; then
  mkdir -p "$SIL_DXMT_CACHE" && set_env DXMT_SHADER_CACHE_PATH "$SIL_DXMT_CACHE"
elif [ "$t" = steam ]; then
  clear_env DXMT_SHADER_CACHE_PATH
fi
# Enable DXMT MetalFX spatial swapchain only when DXMT_UPSCALE_FACTOR is
# explicitly set in (1.0, 2.0]; otherwise clear any stale registry entry.
if [ -n "${DXMT_UPSCALE_FACTOR:-}" ] &&
   [ -n "$(awk -v f="$DXMT_UPSCALE_FACTOR" 'BEGIN { if (f > 1.0 && f <= 2.0) print 1 }')" ]; then
  set_env DXMT_METALFX_SPATIAL_SWAPCHAIN 1
else
  { grep -q '^"DXMT_METALFX_SPATIAL_SWAPCHAIN"=' "$WINEPREFIX/user.reg" 2>/dev/null &&
    clear_env DXMT_METALFX_SPATIAL_SWAPCHAIN; }
fi
set_env CX_GRAPHICS_BACKEND dxmt
for v in MTL_HUD_ENABLED MVKCACHE_FPS MVKCACHE_LOG BO_STATS BO_DRLOG; do
  if [ -n "${!v:-}" ]; then set_env "$v" "${!v}"; else clear_env "$v"; fi
done
# Settings of older setups' engines (prefixes imported from them): unused here.
for v in WINE_ROSETTA_CALL_WORKAROUND WINE_ROSETTA_EXEC_BREAKPOINTS WINE_ROSETTA_LAZY_EXEC \
         WINE_ROSETTA_WOW64_BREAKPOINTS WINE_SOCK_FASTPATH WINE_X87_SIDECAR; do
  grep -q "^\"$v\"=" "$WINEPREFIX/user.reg" 2>/dev/null && clear_env "$v"
done

# --- Wine settings -------------------------------------------------------------
bootstrapper='HKCU\Software\Wine\AppDefaults\plutonium-bootstrapper-win32.exe'
# World at War's native XAudio2_0 is only for T4: the bootstrapper key is shared
# with Black Ops and BO2, so do not leave the override on for them.
if [ "$t" != t4 ] && grep -q '"xaudio2_0"="native"' "$WINEPREFIX/user.reg" 2>/dev/null; then
  reg delete "$bootstrapper\\DllOverrides" /v xaudio2_0 /f
fi
# Direct3D is DXVK's (9) or DXMT's (11); wined3d only backs DirectDraw, where
# BO1 reads its video memory (no3d reports 128 MB and caps textures to it).
reg add "$bootstrapper\\Direct3D" /v renderer /d no3d /f
if on BO1_VIDMEM; then reg add "$bootstrapper\\Direct3D" /v VideoMemorySize /d 4096 /f
else reg delete "$bootstrapper\\Direct3D" /v VideoMemorySize /f; fi
# Fullscreen without capturing the display (owner's choice, 2026-11-24): a
# captured display could not be recorded, showed black behind a windowed game
# and made Cmd-Tab slower. The games still start in real fullscreen (their
# configs below) at the held mode, through the window compositor.
# (CAPTURE_DISPLAY=2: capture as before, kept for A/B tests only)
if [ "${CAPTURE_DISPLAY:-0}" = 2 ]; then reg add "$bootstrapper\\Mac Driver" /v CaptureDisplaysForFullscreen /d y /f
else reg add "$bootstrapper\\Mac Driver" /v CaptureDisplaysForFullscreen /d n /f; fi
if [ "$t" = iw5 ]; then
  for exe in iw5mp.exe iw5sp.exe; do
    if [ "${CAPTURE_DISPLAY:-0}" = 2 ]; then reg add "HKCU\\Software\\Wine\\AppDefaults\\$exe\\Mac Driver" /v CaptureDisplaysForFullscreen /d y /f
    else reg add "HKCU\\Software\\Wine\\AppDefaults\\$exe\\Mac Driver" /v CaptureDisplaysForFullscreen /d n /f; fi
  done
fi
if [ "$t" = iw4 ]; then
  for exe in iw4x.exe iw4x-sp.exe iw4sp.exe; do
    if [ "${CAPTURE_DISPLAY:-0}" = 2 ]; then reg add "HKCU\\Software\\Wine\\AppDefaults\\$exe\\Mac Driver" /v CaptureDisplaysForFullscreen /d y /f
    else reg add "HKCU\\Software\\Wine\\AppDefaults\\$exe\\Mac Driver" /v CaptureDisplaysForFullscreen /d n /f; fi
  done
fi
# The Plutonium launcher's window is drawn with OpenGL.
reg add 'HKCU\Software\Wine\AppDefaults\plutonium-launcher-win32.exe\Direct3D' /v renderer /d gl /f
# (Each launch branch flushes the combined registry queue once right before
# starting Wine, avoiding redundant cold regedit + wineserver -w round trips.)

# --- macOS input ----------------------------------------------------------------
# Holding a key (W, A, S, D…) would open macOS's accent menu in the game's window:
# turn press-and-hold off for Wine's process only.
defaults write com.codeweavers.CrossOver.wineloader ApplePressAndHoldEnabled -bool false 2>/dev/null

# --- File pickers ---------------------------------------------------------------
# Wine's file dialogs (Plutonium's "Browse" for the game folder) open on the
# Windows desktop: give it shortcuts to the Mac's folders and the game folders,
# and the home folder as drive H:.
wdesk="$WINEPREFIX/drive_c/users/crossover/Desktop"
if [ -d "$wdesk" ] && [ ! -L "$wdesk" ]; then
  ln -sfn "$HOME" "$wdesk/Mac Home"
  for d in Downloads Documents; do [ -d "$HOME/$d" ] && ln -sfn "$HOME/$d" "$wdesk/$d"; done
  [ -d "${BO1_DIR:-}" ] && ln -sfn "$BO1_DIR" "$wdesk/Black Ops" || rm -f "$wdesk/Black Ops"
  [ -d "${BO2_DIR:-}" ] && ln -sfn "$BO2_DIR" "$wdesk/Black Ops II" || rm -f "$wdesk/Black Ops II"
  [ -d "${IW5_DIR:-}" ] && ln -sfn "$IW5_DIR" "$wdesk/Modern Warfare 3" || rm -f "$wdesk/Modern Warfare 3"
  [ -d "${IW4_DIR:-}" ] && ln -sfn "$IW4_DIR" "$wdesk/Modern Warfare 2" || rm -f "$wdesk/Modern Warfare 2"
  [ -d "${BOIII_DIR:-}" ] && ln -sfn "$BOIII_DIR" "$wdesk/Black Ops III" || rm -f "$wdesk/Black Ops III"
fi
[ -e "$WINEPREFIX/dosdevices/h:" ] || ln -s "$HOME" "$WINEPREFIX/dosdevices/h:"

# --- The Battle.net section (prefix-battlenet) ----------------------------------
# Battle.net (stopped above with its prefix, started again by bnet_play with
# this environment and the 1x display mode) signs in and starts the game from
# its launch code; this script waits until the game has quit
if [ "$t" = bnet ]; then
  bnet_play
  exit $?
fi

# Direct3D 9 -> Metal (patched mtld3d v0.15.5, macOS 15+) in its own persistent
# stamped engine clone so the base engine stays clean for DXVK fallback
# (D3D9_MTLD3D=0) and LaunchServices / Apple Metal binary caches stay warm.
mtld3d_cache_clean=0
prepare_mtld3d_engine() {
  local src="$kit/payload/mtld3d" persist="$home/cache/mtld3d-engine" new sig entry win
  [ -f "$src/x86_64-unix/mtld3d.so" ] && [ -f "$src/i386-windows/d3d9.dll" ] || return 1
  win="$WINEPREFIX/drive_c/windows"
  mkdir -p "$win/syswow64" "$win/system32" 2>/dev/null || true
  if [ -f "$src/prefix-markers/syswow64/mtld3d.dll" ]; then
    cmp -s "$src/prefix-markers/syswow64/mtld3d.dll" "$win/syswow64/mtld3d.dll" ||
      cp "$src/prefix-markers/syswow64/mtld3d.dll" "$win/syswow64/mtld3d.dll" || return 1
  fi
  if [ -f "$src/prefix-markers/system32/mtld3d.dll" ]; then
    cmp -s "$src/prefix-markers/system32/mtld3d.dll" "$win/system32/mtld3d.dll" ||
      cp "$src/prefix-markers/system32/mtld3d.dll" "$win/system32/mtld3d.dll" || return 1
  fi
  sig=$(stat -f '%m:%z' \
    "$engine/siliconium.version" \
    "$engine/lib/wine/x86_64-unix/winemac.so" \
    "$engine/lib/wine/x86_64-unix/winecoreaudio.so" \
    "$engine/lib/wine/x86_64-unix/ntdll.so" \
    "$engine/lib/wine/x86_64-unix/winebus.so" \
    "$engine/lib/wine/x86_64-unix/winemetal.so" \
    "$engine/lib/wine/i386-windows/xinput1_3.dll" \
    "$engine/lib/wine/i386-windows/dsound.dll" \
    "$engine/lib/wine/x86_64-windows/winebus.sys" \
    "$src/x86_64-unix/mtld3d.so" \
    "$src/i386-windows/d3d9.dll" 2>/dev/null | tr '\n' ';')
  if [ -x "$persist/lib/wine/x86_64-unix/wine" ] &&
     [ -f "$persist/lib/wine/x86_64-unix/mtld3d.so" ] &&
     [ "$(cat "$persist/.sil-stamp" 2>/dev/null)" = "$sig" ]; then
    mtld3d_engine=$persist
    return 0
  fi
  new="$persist.new"
  rm -rf "$new"
  mkdir -p "$new/lib" || return 1
  for entry in "$engine"/*; do
    [ "${entry##*/}" = lib ] || ln -s "$entry" "$new/" || { rm -rf "$new"; return 1; }
  done
  for entry in "$engine/lib"/*; do
    [ "${entry##*/}" = wine ] || ln -s "$entry" "$new/lib/" || { rm -rf "$new"; return 1; }
  done
  if cp -cRp "$engine/lib/wine" "$new/lib/wine" &&
     cp "$src/i386-windows/d3d9.dll" "$src/i386-windows/mtld3d.dll" "$new/lib/wine/i386-windows/" &&
     cp "$src/x86_64-windows/d3d9.dll" "$src/x86_64-windows/mtld3d.dll" "$new/lib/wine/x86_64-windows/" &&
     cp "$src/x86_64-unix/mtld3d.so" "$new/lib/wine/x86_64-unix/" &&
     codesign -fs - "$new/lib/wine/x86_64-unix/mtld3d.so" 2>/dev/null &&
     printf '%s' "$sig" > "$new/.sil-stamp" &&
     { rm -rf "$persist" && mv "$new" "$persist"; }; then
    mtld3d_engine=$persist
    return 0
  fi
  rm -rf "$new"
  return 1
}

# Keep each D3D9 game's mtld3d_shaders.bin isolated under cache/<game>/
# (Plutonium shares plutonium/bin across T4/T5/T5 MP/IW5; Steam game folders stay clean).
mtld3d_save_cache() {
  if [ -n "${mtld3d_cache_file:-}" ] && [ -f "${mtld3d_plut_bin:-}" ]; then
    mkdir -p "$(dirname -- "$mtld3d_cache_file")" 2>/dev/null || true
    cp -f "$mtld3d_plut_bin" "${mtld3d_cache_file}.tmp" 2>/dev/null &&
      mv -f "${mtld3d_cache_file}.tmp" "$mtld3d_cache_file" 2>/dev/null || true
    [ "${mtld3d_cache_clean:-0}" = 1 ] && rm -f "$mtld3d_plut_bin" "${mtld3d_plut_bin}.tmp" 2>/dev/null || true
  fi
}
mtld3d_stage_cache() {   # mtld3d_stage_cache <per-game cache file> [run_dir] [clean]
  local target=$1 run_dir=${2:-"$plutonium/bin"} clean_flag=${3:-0} owner_file prev
  mtld3d_cache_file=$target
  mtld3d_plut_bin="$run_dir/mtld3d_shaders.bin"
  mtld3d_cache_clean=0
  [ "$clean_flag" = clean ] && mtld3d_cache_clean=1
  [ -d "$run_dir" ] || return 0
  owner_file="$run_dir/.sil-mtld3d-owner"
  if [ "$mtld3d_cache_clean" = 0 ]; then
    prev=$(cat "$owner_file" 2>/dev/null || true)
    if [ -n "$prev" ] && [ "$prev" != "$target" ] && [ -f "$mtld3d_plut_bin" ]; then
      mkdir -p "$(dirname -- "$prev")" 2>/dev/null || true
      cp -f "$mtld3d_plut_bin" "${prev}.tmp" 2>/dev/null && mv -f "${prev}.tmp" "$prev" 2>/dev/null || true
    fi
    printf '%s' "$target" > "$owner_file" 2>/dev/null || true
  fi
  if [ -f "$target" ]; then
    cp -f "$target" "$mtld3d_plut_bin" 2>/dev/null || true
  else
    rm -f "$mtld3d_plut_bin" "${mtld3d_plut_bin}.tmp" 2>/dev/null || true
  fi
  [ "$mtld3d_cache_clean" = 0 ] && trap mtld3d_save_cache EXIT
}

# --- The Steam Library (prefix-steam) -------------------------------------------
# Steam (restarted above, so it and the game it starts get this environment
# and the 1x display mode) signs in by itself and starts the game: as its own
# Steam app when the part has one, else its executable with Steam's app ID.
if [ "$t" = steam ]; then
  if [ "$mtld3d_active" = 1 ]; then
    if ! prepare_mtld3d_engine; then
      mtld3d_active=0
      mtld3d_engine=
      clear_env MTLD3D_CONFIG
      clear_env RUST_LOG
    fi
  fi
  steamdir="$WINEPREFIX/drive_c/Program Files (x86)/Steam"
  log="$home/logs/steam-$s_id-$s_part.log"
  if [ "${s_client:-}" = own ]; then log="$home/logs/own-$s_id-$s_part.log"
  elif [ -n "${s_client:-}" ]; then log="$home/logs/$s_client.log"; fi
  log_cap "$log"
  case "$s_kind" in
    iw6) capture=n ;;            # borderless
    t6)  capture=n ;;            # BO2 keeps the desktop's mode
    # Black Ops III as its Mod Tools' map test (bo3-modtools.sh): fullscreen
    # through the window compositor (held at the desktop's size, below, so no
    # mode switch): a captured display could not be recorded (2026-11-23)
    t7)  capture=n ;;
    *)   if [ "${CAPTURE_DISPLAY:-0}" = 2 ]; then capture=y; else capture=n; fi ;;
  esac
  reg add "HKCU\\Software\\Wine\\AppDefaults\\$s_exe\\Mac Driver" /v CaptureDisplaysForFullscreen /d "$capture" /f
  if [ "$s_api" = d3d9x64 ]; then
    if [ "$mtld3d_active" = 1 ]; then
      reg add "HKCU\\Software\\Wine\\AppDefaults\\$s_exe\\DllOverrides" /v d3d9 /d builtin /f
    else
      steam_dxvk64 "$WINEPREFIX" "$kit" ||
        die "Could not install DXVK for $s_name (64-bit Direct3D 9): reinstall Siliconium."
      reg add "HKCU\\Software\\Wine\\AppDefaults\\$s_exe\\DllOverrides" /v d3d9 /d native /f
    fi
  fi
  # Black Ops Multiplayer: Plutonium's multiplayer renderer (payload/bo1/
  # mp-d3d9.dll, our DXVK with the multiplayer warming flag, DXVK_T5MP_WARM;
  # Steam's BlackOpsMP.exe is the executable Plutonium runs) for that
  # executable only, from Steam's 32-bit system folder; every other 32-bit
  # Direct3D 9 game of the section keeps the engine's own DXVK or mtld3d (builtin)
  if [ "$s_api" = d3d9 ] || { [ "$s_api" = gl ] && [ "$mtld3d_active" = 1 ]; }; then
    if [ "$mtld3d_active" = 1 ]; then
      reg add "HKCU\\Software\\Wine\\AppDefaults\\$s_exe\\DllOverrides" /v d3d9 /d builtin /f
      clear_env DXVK_T5MP_WARM
    elif [ "$s_exe" = BlackOpsMP.exe ] && on BO1_MP_FAST_LOAD && on BO1_WARM && on BO1_ASYNC &&
       [ -f "$kit/payload/bo1/mp-d3d9.dll" ]; then
      # The renderer carries Wine's builtin mark (Plutonium puts it in a copy of
      # the engine's DLL folder); as a native DLL Wine would take it for a
      # placeholder and the game would not start: a copy with the standard
      # DOS-stub text instead of the mark (bytes 64-79, never run)
      mpdll="$WINEPREFIX/bo1-mp-d3d9.native.dll"
      if [ ! -f "$mpdll" ] || [ "$kit/payload/bo1/mp-d3d9.dll" -nt "$mpdll" ]; then
        cp "$kit/payload/bo1/mp-d3d9.dll" "$mpdll.tmp" &&
          printf 'This program can' | dd of="$mpdll.tmp" bs=1 seek=64 conv=notrunc 2> /dev/null &&
          mv -f "$mpdll.tmp" "$mpdll"
      fi
      cmp -s "$mpdll" "$WINEPREFIX/drive_c/windows/syswow64/d3d9.dll" ||
        cp "$mpdll" "$WINEPREFIX/drive_c/windows/syswow64/d3d9.dll"
      reg add "HKCU\\Software\\Wine\\AppDefaults\\$s_exe\\DllOverrides" /v d3d9 /d native /f
      set_env DXVK_T5MP_WARM 1
    elif [ "$s_id" = cod2 ] && [ -f "$kit/payload/steam/cod2-d3d9.dll" ]; then
      # Call of Duty 2: our DXVK plus own bindings for the 3D and cube variants
      # of shader model 1 samplers (patches/dxvk-d3d9-sm1-samplers.patch);
      # Metal cannot share them and the menus were never drawn (black screen
      # with the menu's sound). For its executables only, from Steam's 32-bit
      # system folder, as Black Ops Multiplayer's renderer
      cmp -s "$kit/payload/steam/cod2-d3d9.dll" "$WINEPREFIX/drive_c/windows/syswow64/d3d9.dll" ||
        cp "$kit/payload/steam/cod2-d3d9.dll" "$WINEPREFIX/drive_c/windows/syswow64/d3d9.dll"
      reg add "HKCU\\Software\\Wine\\AppDefaults\\$s_exe\\DllOverrides" /v d3d9 /d native /f
      clear_env DXVK_T5MP_WARM
    else
      reg add "HKCU\\Software\\Wine\\AppDefaults\\$s_exe\\DllOverrides" /v d3d9 /d builtin /f
      clear_env DXVK_T5MP_WARM
    fi
  fi
  # Advanced Warfare: the engine's DXMT 0.80 (same 4 patches) plus upstream
  # ab984cf (patches/dxmt-mesh-no-ps-v0.80.patch): a tessellation (mesh)
  # pipeline with no pixel shader gets no colour attachments, else Metal
  # aborts the game ("fragmentFunction must not be nil", after the first
  # cutscene). For its executables only, from Steam's 64-bit system folder
  # as a native DLL; every other game keeps the builtin (Wine's default for
  # d3d11 loads the builtin even with this file there: it is not marked
  # prefer-native). AW_DXMT_FIX=0: the engine's DXMT, as before.
  # AW_DXMT_DIR=<folder with x86_64-windows/{d3d11,dxgi,d3d10core,winemetal}.dll
  # and x86_64-unix/winemetal.so, builtin-marked>: a whole DXMT build under
  # test for Advanced Warfare (development only; the engine stays untouched)
  aw_dxmt_dir=
  [ "${s_kind:-}" = s1 ] && [ -f "${AW_DXMT_DIR:-/nonexistent}/x86_64-unix/winemetal.so" ] &&
    [ -f "$AW_DXMT_DIR/x86_64-windows/d3d11.dll" ] && aw_dxmt_dir=$AW_DXMT_DIR
  # AW_D3D=dxvk AW_DXVK_DIR=<folder with a 64-bit DXVK d3d11.dll + dxgi.dll>:
  # Advanced Warfare on DXVK (Vulkan → MoltenVK) instead of DXMT (development
  # only). Native from Steam's 64-bit system folder for AW's exe only; the
  # other games keep the builtin DXMT (not prefer-native, see below)
  aw_dxvk=
  [ "${s_kind:-}" = s1 ] && [ "${AW_D3D:-}" = dxvk ] && [ -f "${AW_DXVK_DIR:-/nonexistent}/d3d11.dll" ] &&
    [ -f "$AW_DXVK_DIR/dxgi.dll" ] && aw_dxvk=$AW_DXVK_DIR
  if [ "${s_kind:-}" = s1 ]; then
    if [ -n "$aw_dxvk" ]; then
      for d in d3d11 dxgi; do
        cmp -s "$aw_dxvk/$d.dll" "$WINEPREFIX/drive_c/windows/system32/$d.dll" ||
          cp "$aw_dxvk/$d.dll" "$WINEPREFIX/drive_c/windows/system32/$d.dll"
        reg add "HKCU\\Software\\Wine\\AppDefaults\\$s_exe\\DllOverrides" /v $d /d native /f
      done
    else
      reg delete "HKCU\\Software\\Wine\\AppDefaults\\$s_exe\\DllOverrides" /v dxgi /f
    fi
  fi
  if [ "${s_kind:-}" = s1 ] && [ -z "$aw_dxvk" ]; then
    if [ -n "$aw_dxmt_dir" ]; then
      reg add "HKCU\\Software\\Wine\\AppDefaults\\$s_exe\\DllOverrides" /v d3d11 /d builtin /f
    elif on AW_DXMT_FIX && [ -f "$kit/payload/steam/aw-d3d11.dll" ]; then
      cmp -s "$kit/payload/steam/aw-d3d11.dll" "$WINEPREFIX/drive_c/windows/system32/d3d11.dll" ||
        cp "$kit/payload/steam/aw-d3d11.dll" "$WINEPREFIX/drive_c/windows/system32/d3d11.dll"
      reg add "HKCU\\Software\\Wine\\AppDefaults\\$s_exe\\DllOverrides" /v d3d11 /d native /f
    else
      reg add "HKCU\\Software\\Wine\\AppDefaults\\$s_exe\\DllOverrides" /v d3d11 /d builtin /f
    fi
  fi
  # Infinite Warfare (iw7) needs the same DLL: right after its brightness
  # screen it creates depth-only tessellation pipelines and the engine's DXMT
  # aborted it with the same "fragmentFunction must not be nil" (session 20).
  # Its executable only; IW7_DXMT_FIX=0: the engine's DXMT
  if [ "${s_kind:-}" = iw7 ]; then
    if on IW7_DXMT_FIX && [ -f "$kit/payload/steam/aw-d3d11.dll" ]; then
      cmp -s "$kit/payload/steam/aw-d3d11.dll" "$WINEPREFIX/drive_c/windows/system32/d3d11.dll" ||
        cp "$kit/payload/steam/aw-d3d11.dll" "$WINEPREFIX/drive_c/windows/system32/d3d11.dll"
      reg add "HKCU\\Software\\Wine\\AppDefaults\\$s_exe\\DllOverrides" /v d3d11 /d native /f
    else
      reg add "HKCU\\Software\\Wine\\AppDefaults\\$s_exe\\DllOverrides" /v d3d11 /d builtin /f
    fi
  fi
  # WWII's multiplayer executable (Multiplayer and Zombies) asks
  # InternetGetConnectedState on every frame while online. Wine answers it by
  # listing every network adapter through its nsiproxy driver: ~10 ms a call
  # on the test Mac (27 adapters), and an online match held ~27 ms a frame
  # (38.6 FPS; 63.6 with this, 2026-11-23). payload/steam/wwii-wininet.dll
  # (tools/wininet-netstate.c) answers from a result its own thread refreshes
  # every second and forwards everything else to the engine's own wininet.dll,
  # copied beside it as wininet_wine.dll; that executable alone loads it
  # (other programs keep Wine's wininet.dll). WW2_NETSTATE=0: Wine's own.
  # Advanced Warfare's multiplayer executable (Multiplayer and Exo Zombies,
  # Sledgehammer's previous engine) gets the same: inferred from WWII, not
  # measured (AW was not installed, 2026-11-23); when it does not ask, the DLL
  # changes nothing. AW_NETSTATE=0: Wine's own.
  netstate_switch=
  case "$s_exe" in s2_mp64_ship.exe) netstate_switch=WW2_NETSTATE ;; s1_mp64_ship.exe) netstate_switch=AW_NETSTATE ;; esac
  if [ -n "$netstate_switch" ]; then
    s32="$WINEPREFIX/drive_c/windows/system32" wn="$engine/lib/wine/x86_64-windows/wininet.dll"
    if on "$netstate_switch" && [ -f "$kit/payload/steam/wwii-wininet.dll" ] && [ -f "$wn" ] &&
       { cmp -s "$wn" "$s32/wininet_wine.dll" || cp "$wn" "$s32/wininet_wine.dll"; } &&
       { cmp -s "$kit/payload/steam/wwii-wininet.dll" "$s32/wininet.dll" || cp "$kit/payload/steam/wwii-wininet.dll" "$s32/wininet.dll"; }; then
      reg add "HKCU\\Software\\Wine\\AppDefaults\\$s_exe\\DllOverrides" /v wininet /d native /f
    else
      reg add "HKCU\\Software\\Wine\\AppDefaults\\$s_exe\\DllOverrides" /v wininet /d builtin /f
    fi
  fi
  # The tessellation-fixed DXMT winemetal.so (patches/dxmt-airconv-ts-workloads-v0.80.patch)
  # is now unified directly into the base engine, so AW, IW, and IW7-Mod run straight
  # on $engine with zero clone overhead. Keep ephemeral engine clones only for the
  # AW_DXMT_DIR and SIL_DXMT_SO developer A/B testing hooks, and remove any legacy
  # $home/cache/aw-engine clone left by older builds.
  aw_engine=
  aw_engine_ephemeral=0
  sil_so=
  [ -f "${SIL_DXMT_SO:-/nonexistent}" ] && case "${SIL_DXMT_CACHE:-}" in /?*) true ;; *) false ;; esac && sil_so=$SIL_DXMT_SO
  [ -d "$home/cache/aw-engine" ] && rm -rf "$home/cache/aw-engine" 2>/dev/null || true
  if [ -n "${aw_dxmt_dir:-}" ] || [ -n "$sil_so" ]; then
    for old in "$home/cache"/aw-engine.*; do   # left by earlier ephemeral runs
      [ -d "$old" ] && /usr/bin/python3 -I -c 'import shutil, sys; shutil.rmtree(sys.argv[1])' "$old"
    done
    aw_so="$kit/payload/dxmt/x86_64-unix/winemetal.so"; [ -n "${aw_dxmt_dir:-}" ] && aw_so="$aw_dxmt_dir/x86_64-unix/winemetal.so"
    [ -n "$sil_so" ] && aw_so=$sil_so
    if aw_engine=$(mktemp -d "$home/cache/aw-engine.XXXXXX") && mkdir "$aw_engine/lib"; then
      aw_engine_ephemeral=1
      for entry in "$engine"/*; do [ "${entry##*/}" = lib ] || ln -s "$entry" "$aw_engine/"; done
      for entry in "$engine/lib"/*; do [ "${entry##*/}" = wine ] || ln -s "$entry" "$aw_engine/lib/"; done
      if ! { cp -cRp "$engine/lib/wine" "$aw_engine/lib/wine" &&
             { [ -z "${aw_dxmt_dir:-}" ] || cp "$aw_dxmt_dir"/x86_64-windows/*.dll "$aw_engine/lib/wine/x86_64-windows/"; } &&
             cp "$aw_so" "$aw_engine/lib/wine/x86_64-unix/winemetal.so" &&
             codesign -fs - "$aw_engine/lib/wine/x86_64-unix/winemetal.so" 2>/dev/null; }; then
        /usr/bin/python3 -I -c 'import shutil, sys; shutil.rmtree(sys.argv[1])' "$aw_engine"; aw_engine=; aw_engine_ephemeral=0
      fi
    else
      aw_engine=
    fi
  fi
  # The pipeline lists shipped for Black Ops (gathered in Zombies) and World
  # at War (Der Riese), and what Plutonium learned on this Mac: the same game
  # files, so the same pipelines; DXVK compiles them while the game starts
  # instead of while it is played. As with Plutonium: World at War's list for
  # both parts (Plutonium's T4 multiplayer uses the same cache), Black Ops'
  # for the campaign/Zombies only (its multiplayer learns its own)
  if [ "$mtld3d_active" = 0 ]; then
    case "$s_exe" in
      BlackOps.exe) on BO1_SHADER_CACHE && merge_statecache \
        "$home/cache/steam-bo1/BlackOps.dxvk-cache" "$kit/payload/bo1/pipelines.dxvk-cache" \
        "$home/cache/bo1/plutonium-bootstrapper-win32.dxvk-cache" \
        "$home/cache/plutonium-bootstrapper-win32.dxvk-cache" ;;
      CoDWaW.exe|CoDWaWmp.exe) on WAW_PIPELINES && merge_statecache \
        "$home/cache/steam-waw/${s_exe%.exe}.dxvk-cache" "$kit/payload/waw/pipelines.dxvk-cache" \
        "$home/cache/t4/plutonium-bootstrapper-win32.dxvk-cache" ;;
    esac
  fi
  # Black Ops, Black Ops II Zombies/Multiplayer and World at War: their own
  # XAudio2 from the game's redist, as with Plutonium (Wine's left Black Ops'
  # gunfire silent, BO2's on some Macs, and World at War's music broken);
  # Black Ops also reads its video memory through DirectDraw (no3d reports
  # 128 MB and caps the textures to it). Per executable. BO2's campaign
  # (t6sp.exe, shared with the Black Ops II Campaign tile) keeps Wine's.
  xa_dll= xa_cab= xa_on=
  case "$s_exe" in
    t6zm.exe|t6mp.exe) xa_dll=XAudio2_7 xa_cab=Jun2010_XAudio_x86.cab xa_on=BO2_XAUDIO ;;
    BlackOps.exe|BlackOpsMP.exe)
      xa_dll=XAudio2_7 xa_cab=Jun2010_XAudio_x86.cab xa_on=BO1_XAUDIO
      reg add "HKCU\\Software\\Wine\\AppDefaults\\$s_exe\\Direct3D" /v renderer /d no3d /f
      if on BO1_VIDMEM; then reg add "HKCU\\Software\\Wine\\AppDefaults\\$s_exe\\Direct3D" /v VideoMemorySize /d 4096 /f
      else reg delete "HKCU\\Software\\Wine\\AppDefaults\\$s_exe\\Direct3D" /v VideoMemorySize /f; fi ;;
    CoDWaW.exe|CoDWaWmp.exe) xa_dll=XAudio2_0 xa_cab=Mar2008_XAudio_x86.cab xa_on=WAW_XAUDIO ;;
  esac
  if [ -n "$xa_dll" ]; then
    xa_lc=$(printf '%s' "$xa_dll" | tr '[:upper:]' '[:lower:]')
    xa="$WINEPREFIX/$xa_lc.native.dll"
    xa_more=()   # Black Ops / Black Ops II: the same Jun2010 cab from the other one or Plutonium's folders
    case "$xa_on" in BO1_XAUDIO|BO2_XAUDIO)
      xa_more=(${BO1_DIR:+"$BO1_DIR/redist/DirectX/$xa_cab"} ${BO2_DIR:+"$BO2_DIR/redist/DirectX/$xa_cab"}
               "$WINEPREFIX/drive_c/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops/redist/DirectX/$xa_cab"
               "$WINEPREFIX/drive_c/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops II/redist/DirectX/$xa_cab") ;;
    esac
    for cab in "$dir/redist/DirectX/$xa_cab" "$dir/DirectX/$xa_cab" ${xa_more[@]+"${xa_more[@]}"}; do   # Steam's WaW: DirectX/
      [ ! -f "$xa" ] && [ -f "$cab" ] || continue
      tmp=$(mktemp -d)
      bsdtar -xf "$cab" -C "$tmp" "$xa_dll.dll" 2>/dev/null && cp "$tmp/$xa_dll.dll" "$xa"
      rm -rf "$tmp"
    done
    if on "$xa_on" && [ -f "$xa" ]; then
      cmp -s "$xa" "$WINEPREFIX/drive_c/windows/syswow64/$xa_lc.dll" || cp "$xa" "$WINEPREFIX/drive_c/windows/syswow64/$xa_lc.dll"
      reg add "HKCU\\Software\\Wine\\AppDefaults\\$s_exe\\DllOverrides" /v "$xa_lc" /d native /f
    else
      reg delete "HKCU\\Software\\Wine\\AppDefaults\\$s_exe\\DllOverrides" /v "$xa_lc" /f
    fi
  fi
  # Offline Black Ops II packs ("Your Own Game Files"): common community packs
  # ship with localization.txt set to a language whose audio bank is missing
  # (e.g. polish without sound/cmn_root.polish.sabs, causing a silent hang at a
  # black screen right after R_Init) or with steam_api.dll left on the MP/ZM
  # variant instead of steam_api.dll_sp. Auto-repair both safely (backing up the
  # original localization.txt once) so Campaign boots out of the box.
  if [ "${s_client:-}" = own ] && [ "$s_id" = bo2 ]; then
    if [ -f "$dir/localization.txt" ] && [ -d "$dir/sound" ]; then
      bo2_loc=$(head -n 1 "$dir/localization.txt" 2>/dev/null | LC_ALL=C tr -cd 'A-Za-z_' | tr '[:upper:]' '[:lower:]')
      if [ -z "$bo2_loc" ] || [ ! -f "$dir/sound/cmn_root.$bo2_loc.sabs" ] || [ ! -d "$dir/zone/$bo2_loc" ]; then
        bo2_pick=
        for bo2_cand in english spanish french german italian russian polish; do
          if [ -f "$dir/sound/cmn_root.$bo2_cand.sabs" ] && [ -d "$dir/zone/$bo2_cand" ]; then
            bo2_pick=$bo2_cand; break
          fi
        done
        if [ -z "$bo2_pick" ]; then
          for bo2_sabs in "$dir/sound"/cmn_root.*.sabs; do
            bo2_cand=${bo2_sabs##*/cmn_root.}
            bo2_cand=${bo2_cand%.sabs}
            [ "$bo2_cand" = all ] && continue
            if [ -f "$bo2_sabs" ] && [ -d "$dir/zone/$bo2_cand" ]; then
              bo2_pick=$bo2_cand; break
            fi
          done
        fi
        if [ -n "$bo2_pick" ]; then
          [ -f "$dir/localization.txt.sil-orig" ] || cp -p "$dir/localization.txt" "$dir/localization.txt.sil-orig" 2>/dev/null || true
          bo2_sw=
          if [ -d "$dir/_Language Switcher" ]; then
            bo2_sw=$(find "$dir/_Language Switcher" -maxdepth 2 -iname 'localization.txt' 2>/dev/null | awk -v lang="$bo2_pick" 'tolower($0) ~ "/" lang "/localization\\.txt$" { print; exit }')
          fi
          if [ -n "$bo2_sw" ] && [ -f "$bo2_sw" ]; then
            cp -f "$bo2_sw" "$dir/localization.txt"
          else
            bo2_tmp=$(mktemp "$dir/localization.txt.XXXXXX") &&
              awk -v lang="$bo2_pick" 'NR == 1 { printf "%s\r\n", lang; next } { print } END { if (NR == 0) printf "%s\r\n", lang }' "$dir/localization.txt" > "$bo2_tmp" &&
              mv -f "$bo2_tmp" "$dir/localization.txt" || rm -f "${bo2_tmp:-}"
          fi
          printf '%s\n' "--- $(date) BO2 offline auto-repair: localization.txt ($bo2_loc -> $bo2_pick; missing sound/cmn_root.$bo2_loc.sabs or zone/$bo2_loc)" >> "$log"
        fi
      fi
    fi
    if [ "$s_part" = sp ] && [ -f "$dir/steam_api.dll_sp" ] && ! cmp -s "$dir/steam_api.dll_sp" "$dir/steam_api.dll" 2>/dev/null; then
      if [ -f "$dir/steam_api.dll" ] && [ ! -f "$dir/steam_api.dll.sil-orig" ] &&
         { [ ! -f "$dir/steam_api.dll_zmp" ] || ! cmp -s "$dir/steam_api.dll" "$dir/steam_api.dll_zmp" 2>/dev/null; }; then
        cp -p "$dir/steam_api.dll" "$dir/steam_api.dll.sil-orig" 2>/dev/null || true
      fi
      cp -f "$dir/steam_api.dll_sp" "$dir/steam_api.dll" &&
        printf '%s\n' "--- $(date) BO2 offline auto-repair: synced steam_api.dll from steam_api.dll_sp" >> "$log"
    fi
  fi
  # Black Ops II: the hardware profile made on an Apple GPU, once (as for the campaign)
  if [ "$s_kind" = t6 ] && on BO2_HW_PROFILE && [ ! -f "$dir/players/.sil-defaults-hardware" ]; then
    mkdir -p "$dir/players"
    cp "$kit/payload/bo2/hardware.chp" "$dir/players/hardware.chp" && : > "$dir/players/.sil-defaults-hardware"
  fi
  # (fullscreen at the desktop's size every start, as the Steam Library's
  # other games: STEAM_SCREEN=0 leaves BO2's own choice)
  [ "$s_kind" = t6 ] && [ "${STEAM_SCREEN:-1}" != 0 ] && bo2_hw_screen "$dir/players" - "$dir"/players/hardware*.chp
  # "did not quit properly / run in safe mode?" markers (__<exe>) left by a
  # game stopped from the app or a crash: the app starts a game only when it
  # is not running, so they are stale here
  rm -f -- "$dir/__${s_exe%.exe}"
  # Call of Duty (OpenGL), COD1_GLDIRECT (on by default; 0 = Apple's OpenGL): GLDirect 5
  # (github.com/MrRendroc/gldirect, MIT: Mesa's OpenGL on Direct3D 9) as its
  # opengl32, so it draws through the engine's DXVK like Call of Duty 2 instead of
  # Apple's OpenGL (which waits for the GPU at each of ~45 vertex-buffer updates a
  # frame). Wine finds a native opengl32 only next to the executable (not on the
  # search path while its own is in the system folder), so the wrapper and its
  # settings sit in the game folder (none of the game's files change) and are
  # native for the game's two executables only (per-executable override; the
  # multiplayer's CoDMP.exe is the one GLDirect was measured with: official
  # Timedemo1, 45 → 138 fps); no3d keeps Wine's DirectDraw (the game asks it
  # for video memory) from starting its own OpenGL through it. Off: the two
  # files go (only if ours).
  # United Offensive (UO_GLDIRECT): the same engine in the same folder, its own
  # two executables (CoDUOSP.exe / CoDUOMP.exe) get the same override
  if [ "$s_id" = cod1 ] || [ "$s_id" = uo ]; then
    if steam_gldirect && [ -f "$kit/payload/steam/cod1-gl/opengl32.dll" ]; then
      for f in opengl32.dll gldirect.ini; do
        cmp -s "$kit/payload/steam/cod1-gl/$f" "$dir/$f" || cp "$kit/payload/steam/cod1-gl/$f" "$dir/$f"
      done
      reg add "HKCU\\Software\\Wine\\AppDefaults\\$s_exe\\DllOverrides" /v opengl32 /d native /f
      reg add "HKCU\\Software\\Wine\\AppDefaults\\$s_exe\\Direct3D" /v renderer /d no3d /f
      # GLDirect builds a Direct3D effect (HLSL) per OpenGL state it meets;
      # compiled once, each is kept in the game's cache (fx_2_0 binaries,
      # named by the state + this build) so later starts draw without the
      # ~100 ms compile hitches. United Offensive shares Call of Duty's cache:
      # a file is named by the whole effect state (+ this build), so the same
      # state is the same effect in either game, and the expansion starts with
      # Call of Duty's effects already compiled
      mkdir -p "$home/cache/steam-cod1/gld"
      gld_cache="$home/cache/steam-cod1/gld"
      export GLD_SHADER_CACHE="Z:${gld_cache//\//\\}"
      # an effect not in the cache yet is compiled on a worker thread (what
      # it draws appears a few frames late the first time) instead of
      # stopping the game: timedemo with an empty cache, worst frame
      # 220 -> 37 ms, 1 % low 19 -> 53 fps. GLD_ASYNC_EFFECTS=0: in-line
      export GLD_ASYNC_EFFECTS="${GLD_ASYNC_EFFECTS:-1}"
      # the intro movies: on a display that is not 4:3 the game draws an
      # opaque black quad over them (black screen, with Apple's OpenGL too);
      # while a movie streams GLDirect drops exactly that quad
      export GLD_CINEMATIC_FIX="${GLD_CINEMATIC_FIX:-1}"
    else
      for f in opengl32.dll gldirect.ini; do
        [ -f "$dir/$f" ] && [ -f "$kit/payload/steam/cod1-gl/$f" ] && cmp -s "$kit/payload/steam/cod1-gl/$f" "$dir/$f" && rm -f "$dir/$f"
      done
      reg delete "HKCU\\Software\\Wine\\AppDefaults\\$s_exe\\DllOverrides" /v opengl32 /f
      reg delete "HKCU\\Software\\Wine\\AppDefaults\\$s_exe\\Direct3D" /v renderer /f
    fi
  fi
  # Wine's mouse look (winemac patch) keeps the Mac cursor detached while the
  # game hides it; without it every recentring warps the Mac cursor and aiming
  # feels heavy. Modern Warfare 2 and 3 draw their menus' pointer from Wine's
  # cursor position, which jumped to the centre whenever the mouse stopped
  # (Wine then asked the detached Mac cursor): 2 keeps Wine's position
  # (wine-winemac-mouselook-position.patch). Ghosts / AW: off, as for Ghosts'
  # campaign. WINE_MAC_MOUSELOOK in settings.conf wins.
  # The other games draw their menu pointer the same way (Black Ops' jumped
  # to the centre too): 2 for all but Ghosts / Advanced Warfare.
  case "$s_kind" in
    iw6|s1) export WINE_MAC_MOUSELOOK="${WINE_MAC_MOUSELOOK:-0}" ;;   # until tested in AW
    *)      export WINE_MAC_MOUSELOOK="${WINE_MAC_MOUSELOOK:-2}" ;;
  esac
  # Black Ops III checks for Media Foundation's video decoders ("requires the
  # Windows Media Feature Pack"): as for BOIII, the engine's winegstreamer
  # (registered in Steam's prefix) with GStreamer and its plugins in lib64
  if [ "$s_kind" = t7 ]; then
    export GST_PLUGIN_SYSTEM_PATH_1_0="$engine/lib64/gstreamer-1.0" GST_PLUGIN_PATH_1_0= \
           GST_REGISTRY_1_0="$home/cache/gstreamer-registry.bin"
  fi
  # 32-bit games: 4 GB of address space instead of 2 (as Plutonium's
  # bootstrapper has). Steam's executables are not large-address-aware and
  # World at War ran out of memory under DXVK at 1440p (std::bad_alloc).
  case "$s_api" in gl|d3d9|d3d11) set_env WINE_LARGE_ADDRESS_AWARE 1 ;; *) clear_env WINE_LARGE_ADDRESS_AWARE ;; esac
  # DXVK's logs go to Siliconium's logs, not into the game's folder
  mkdir -p "$home/logs/dxvk"; set_env DXVK_LOG_PATH "Z:${home//\//\\}\\logs\\dxvk"
  marker="$home/cache/$steam_cache_tag/.started-$s_part"; mkdir -p "$home/cache/$steam_cache_tag"
  [ -n "${s_client:-}" ] && [ "${s_client:-}" != own ] && marker="$home/cache/$steam_cache_tag/.started-$s_client"
  first=1; [ -f "$marker" ] && first=0
  steam_args "${dw:-}" "${dh:-}" "${hz:-}" "$first"
  if [ "${s_client:-}" = cod4x ]; then
    # CoD4X keeps its profiles in its AppData folder (fs_savepath
    # %LOCALAPPDATA%\CallofDuty4MW: players\profiles\<name>, seen on its first
    # start 2026-11-21), not in the game's folder: its settings go there
    mkdir -p "$c4_home/players/profiles"
    steam_config "$c4_home" "${dw:-}" "${dh:-}" "${hz:-}" "$home/cache/steam-$s_id/$s_client-home"
  elif [ "${s_client:-}" = iw7mod ]; then
    # IW7-Mod moves the game's profile to <game>\iw7-mod\players2 (its
    # filesystem.cpp) and writes the dvars without a readable name as the game
    # does (setcl <checksum>): the same two values, in its profile
    steam_config "$dir/iw7-mod" "${dw:-}" "${dh:-}" "${hz:-}" "$home/cache/steam-$s_id/$s_client-home"
  else
    steam_config "$dir" "${dw:-}" "${dh:-}" "${hz:-}" "$home/cache/$steam_cache_tag"
  fi
  # Controller aim as on the consoles (after steam_config so first-start profiles exist)
  case "$s_kind" in
    t6)  for c in "$dir"/players/*.cfg; do console_aim "$c"; done ;;
    iw6) for c in "$dir"/players2/*.cfg; do console_aim "$c"; done ;;
  esac
  # shellcheck disable=SC2206
  [ -n "${GAME_ARGS:-}" ] && s_argv+=($GAME_ARGS)
  if [ -z "${s_client:-}" ] || [ "${s_client:-}" = own ]; then steam_mod_args "$dir"; fi
  # IW7-Mod without Steam: -nosteam takes the path it takes when no Steam is
  # installed (stand-ins for Steam's client and overlay; its own Steam API),
  # so every Mac plays it the same way, with or without Steam in this prefix
  [ "${s_client:-}" = iw7mod ] && s_argv+=(-nosteam)
  # Frame statistics (MVKCACHE_FPS) for the OpenGL games, which do not go
  # through MoltenVK: Wine's own frame-rate trace (every few seconds)
  [ -n "${MVKCACHE_FPS:-}" ] && [ "$s_api" = gl ] && [ "$WINEDEBUG" = -all ] && export WINEDEBUG=-all,+fps
  reg_flush
  # A Steam opened meanwhile (the app's Open Steam) would not have this
  # environment: close it, Steam starts again below
  "$WINESERVER" -k 2>/dev/null; "$WINESERVER" -w 2>/dev/null
  console=/nonexistent cseen=0
  # Steam for Windows starts the Steam Library's games; the community clients
  # (s_client) start their own executable without it. CoD4X too, but a CoD4X
  # server can require Steam (the server's sv_steamforce, set by its admin;
  # default off): it asks the game for a Steam ticket and drops a player
  # without Steam ("Steam is not installed/running…"), on Windows too. So when
  # Steam for Windows is installed in this prefix and signs in by itself (a
  # remembered account), it runs in the background while CoD4X plays, as on
  # Windows; COD4X_STEAM=0: never. Without it CoD4X plays as before, on the
  # servers that do not require Steam.
  use_steam=1
  if [ -n "${s_client:-}" ]; then
    use_steam=0
    [ "$s_client" = cod4x ] && on COD4X_STEAM && [ -f "$steamdir/Steam.exe" ] &&
      grep -q '^"AutoLoginUser"="[^"]' "$WINEPREFIX/user.reg" 2>/dev/null && use_steam=1
  fi
  if [ "$use_steam" = 1 ]; then
  clog="$steamdir/logs/connection_log.txt"
  seen=$(wc -l < "$clog" 2>/dev/null | tr -d ' '); seen=${seen:-0}
  # (Steam on the engine's own loader, never the game bundle: tools/game-bundle.sh)
  if env -u WINELOADER bash "$kit/steam.sh" start; then :
  elif [ -n "${s_client:-}" ]; then use_steam=0
  else exit 1; fi
  signed=
  # Steam's sign-in: up to 3 minutes (CoD4X: 90 s, then it starts anyway)
  tries=360; [ -n "${s_client:-}" ] && tries=180
  [ "$use_steam" = 1 ] && for _ in $(seq 1 "$tries"); do
    tail -n +$((seen + 1)) "$clog" 2>/dev/null | grep '\[Logged On,' > /dev/null && { signed=1; break; }
    sleep 0.5
  done
  if [ -n "$signed" ] && [ -n "${s_client:-}" ]; then
    printf '%s\n' "--- $(date) Steam signed in: running in the background for $s_name" >> "$log"
  elif [ -n "${s_client:-}" ]; then
    printf '%s\n' "--- $(date) Steam did not sign in: $s_name starts without Steam (servers that require Steam will refuse it)" >> "$log"
  elif [ -z "$signed" ]; then
    env -u WINELOADER bash "$kit/steam.sh" open
    die "Steam is not signed in: sign in in Steam's window (tick Remember me), then press Play again"
  fi
  console="$steamdir/logs/console_log.txt"
  cseen=$(wc -l < "$console" 2>/dev/null | tr -d ' '); cseen=${cseen:-0}
  fi
  printf '%s\n' "--- $(date) $s_name: ${s_argv[*]:-}" >> "$log"
  # "Set Optimal Settings?" / "Run In Safe Mode?": answered No as they appear
  # (kit/tools/dialog-guard.c), so the settings are never replaced
  guard="$kit/payload/steam/dialog-guard.exe"
  guard_pid=
  steam_cleanup() {
    [ -n "${guard_pid:-}" ] && kill "$guard_pid" 2>/dev/null || true
    [ -n "${focus_pid:-}" ] && kill "$focus_pid" 2>/dev/null || true
    pkill -f 'dialog-guard\.exe|pad-mapper\.exe' 2>/dev/null || true
    mtld3d_save_cache
    if [ -z "${s_client:-}" ] || [ "${s_client:-}" = own ]; then steam_mod_remove "$dir"; fi
    copy_release
    true
  }
  trap steam_cleanup EXIT
  if [ -f "$guard" ]; then
    env -u WINELOADER "$plain_wine" "$guard" 21600 > /dev/null 2>&1 &
    guard_pid=$!
  fi
  # Controllers in the games without controller support on PC: played as
  # keyboard and mouse (kit/tools/pad-mapper.c); CONTROLLER_MAP=0 turns it off
  case "$s_pad" in
    map) if on CONTROLLER_MAP && [ -f "$kit/payload/steam/pad-mapper.exe" ]; then
             # Call of Duty 4, Modern Warfare 2 and 3: every button holds a numpad
             # key bound to its exact command in the game's settings
             # (steam_pad_binds); the keyboard keeps the player's bindings
             pad_ads=
             if [ "$s_kind" = iw ]; then
               pad_ads=keys
               # (CoD4X: the profiles in its AppData folder, c4_home. No comment
               # inside the <( ) below: macOS's bash 3.2 parses it again when it
               # runs, and an apostrophe in a comment there ended the whole
               # Steam block with "bad substitution" in 1.1.0 and 1.1.1)
               while IFS= read -r c; do steam_pad_binds "$c"; done \
                 < <(if [ -n "${c4_home:-}" ]; then find "$c4_home/players" -maxdepth 3 -name 'config*.cfg' 2>/dev/null
                     else find "$dir/players" "$dir/players2" -maxdepth 3 -name 'config*.cfg' 2>/dev/null; fi)
             elif [ "$s_id" = cod1 ]; then
               # Call of Duty: the same keys, its own commands (X also holds F11)
               pad_ads="keys q3"
               for c in "$dir/Main/config.cfg" "$dir/Main/config_mp.cfg"; do steam_pad_binds "$c"; done
             elif [ "$s_id" = uo ]; then
               # United Offensive: as Call of Duty, its settings in uo/
               pad_ads="keys q3"
               for c in "$dir/uo/uoconfig.cfg" "$dir/uo/uoconfig_mp.cfg"; do steam_pad_binds "$c"; done
             elif [ "$s_id" = cod2 ]; then
               # Call of Duty 2: as Call of Duty; its settings are in the
               # profiles it makes on the first start (main/players)
               pad_ads="keys q3"
               while IFS= read -r c; do steam_pad_binds "$c"; done \
                 < <(find "$dir/main/players" -maxdepth 3 -name 'config*.cfg' 2>/dev/null)
             fi
             env -u WINELOADER "$plain_wine" "$kit/payload/steam/pad-mapper.exe" 21600 $pad_ads > /dev/null 2>&1 &
           fi ;;
  esac
  if [ "$s_own" = 1 ]; then
    # this start is Steam's own: the in-game switch relay (tools/steam-relay.sh) lets it through
    mkdir -p "$WINEPREFIX/drive_c/users/Public/Siliconium/relay" &&
      : > "$WINEPREFIX/drive_c/users/Public/Siliconium/relay/bypass-$s_app"
    (cd "$steamdir" && env -u WINELOADER "$engine/lib/wine/x86_64-unix/wine" Steam.exe -applaunch "$s_app" ${s_argv[@]+"${s_argv[@]}"} >> "$log" 2>&1 &)
  else
    # Call of Duty and Call of Duty 2 load steam.dll by name ("Failed to find
    # Steam." otherwise): Steam's folder on their search path, as when Steam
    # starts them. Offline "Your Own Game Files" (s_client=own) run without
    # SteamAppId/SteamGameId so retail/disc/offline folders work cleanly.
    steam_env=()
    [ "${s_client:-}" != own ] && steam_env=(SteamAppId="$s_app" SteamGameId="$s_app")
    [ "$s_kind" = q3 ] && steam_env+=(WINEPATH='C:\Program Files (x86)\Steam')
    game_wine=$wine game_unset=
    # (Advanced Warfare / Infinite Warfare's engine clone, or mtld3d's D3D9->Metal
    # engine clone: each uses its own Game Mode bundle, never the main engine's WINELOADER)
    if [ -n "${aw_engine:-}" ]; then
      game_wine="$aw_engine/lib/wine/x86_64-unix/wine"
      if [ -n "${WINELOADER:-}" ] && gb=$(game_bundle "$game_wine"); then
        game_wine=$gb; steam_env+=(WINELOADER="$gb")
      else game_unset=1; fi
    elif [ -n "${mtld3d_engine:-}" ]; then
      game_wine="$mtld3d_engine/lib/wine/x86_64-unix/wine"
      steam_env+=(CX_ROOT="$mtld3d_engine"
                  WINEDLLPATH="$mtld3d_engine/lib/wine/x86_64-windows:$mtld3d_engine/lib/wine/i386-windows:$mtld3d_engine/lib/wine/x86_64-unix"
                  WINEDLLOVERRIDES="${WINEDLLOVERRIDES};d3d9=b")
      mtld3d_cache_part="$s_part"
      [ -n "${s_client:-}" ] && [ "${s_client:-}" != own ] && mtld3d_cache_part="$s_client"
      mtld3d_target="$home/cache/$steam_cache_tag/${mtld3d_cache_part}-mtld3d_shaders.bin"
      # Local on-machine cross-seeding across sibling D3D9 installs (never ships
      # copyrighted game shaders; copies only an existing local cache on this Mac).
      if [ ! -f "$mtld3d_target" ]; then
        mtld3d_seeds=()
        case "$s_id" in
          cod4) mtld3d_seeds=("$home/cache/steam-cod4/sp-mtld3d_shaders.bin" "$home/cache/steam-cod4/mp-mtld3d_shaders.bin" "$home/cache/steam-cod4/cod4x-mtld3d_shaders.bin" "$home/cache/own-cod4/sp-mtld3d_shaders.bin") ;;
          waw)  mtld3d_seeds=("$home/cache/t4/mtld3d_shaders.bin" "$home/cache/steam-waw/sp-mtld3d_shaders.bin" "$home/cache/steam-waw/mp-mtld3d_shaders.bin") ;;
          bo1)  mtld3d_seeds=("$home/cache/bo1/mtld3d_shaders.bin" "$home/cache/bo1-mp/mtld3d_shaders.bin" "$home/cache/steam-bo1/sp-mtld3d_shaders.bin" "$home/cache/steam-bo1/mp-mtld3d_shaders.bin") ;;
          mw2)  mtld3d_seeds=("$home/cache/iw4/mtld3d_shaders.bin" "$home/cache/steam-mw2/$s_part-mtld3d_shaders.bin" "$home/cache/own-mw2/sp-mtld3d_shaders.bin") ;;
          mw3)  mtld3d_seeds=("$home/cache/iw5/mtld3d_shaders.bin" "$home/cache/steam-mw3/$s_part-mtld3d_shaders.bin" "$home/cache/own-mw3/sp-mtld3d_shaders.bin") ;;
        esac
        for mtld3d_seed in "${mtld3d_seeds[@]}"; do
          if [ "$mtld3d_seed" != "$mtld3d_target" ] && [ -s "$mtld3d_seed" ]; then
            mkdir -p "$(dirname -- "$mtld3d_target")" && cp -f "$mtld3d_seed" "$mtld3d_target" && break
          fi
        done
      fi
      mtld3d_stage_cache "$mtld3d_target" "$dir" clean
      if [ -n "${WINELOADER:-}" ] && gb=$(game_bundle "$game_wine"); then
        game_wine=$gb; steam_env+=(WINELOADER="$gb")
      else game_unset=1; fi
    fi
    printf '==> %s\n' "Starting ${s_name}..."
    # (a fix's launcher, m_start, starts the game itself with these arguments)
    (cd "$dir" && env ${game_unset:+-u WINELOADER} ${steam_env[@]+"${steam_env[@]}"} "$game_wine" "./${m_start:-$s_exe}" ${s_argv[@]+"${s_argv[@]}"} >> "$log" 2>&1 &)
  fi
  # The game is running when its executable works the CPU; Steam says right
  # away when it will not start it. Match only actual game processes, never our
  # own iw6-focus / iw6-restore helpers (which receive the exe name as an arg).
  game_pids() {
    ps -axo pid=,args= | awk -v name="$1" 'BEGIN { n = tolower(name) } { l = tolower($0) } index(l, n) && l !~ /iw6-focus|iw6-restore\.exe|launch\.sh|awk/ { print $1 }'
  }
  game_pid=
  # (IW7-Mod's updater fetches its data files, ~376 MB, before the game opens
  # the first time, at a low CPU load: up to 20 minutes)
  start_wait=720; [ "${s_client:-}" = iw7mod ] && start_wait=4800
  i7_t0= i7_kb0=0 i7_last_kb=0 i7_last_msg=""
  if [ "${s_client:-}" = iw7mod ] && [ -d "$dir/iw7-mod" ]; then
    i7_kb0=$(du -sk "$dir/iw7-mod" 2>/dev/null | awk '{print $1}')
    i7_kb0=${i7_kb0:-0}; i7_last_kb=$i7_kb0
  fi
  for _w in $(seq 1 "$start_wait"); do
    for pid in $(game_pids "$s_exe"); do
      cpu=$(ps -o %cpu= -p "$pid" 2>/dev/null | tr -d ' '); cpu=${cpu%%.*}
      [ "${cpu:-0}" -gt 20 ] && { game_pid=$pid; break 2; }
    done
    if [ "${s_client:-}" = iw7mod ] && [ $((_w % 8)) = 0 ] && [ -d "$dir/iw7-mod" ]; then
      i7_kb=$(du -sk "$dir/iw7-mod" 2>/dev/null | awk '{print $1}'); i7_kb=${i7_kb:-0}
      if [ "$i7_kb" -gt "$i7_last_kb" ]; then
        i7_now=$(date +%s)
        [ -z "$i7_t0" ] && { i7_t0=$i7_now; i7_kb0=$i7_kb; }
        i7_mb=$((i7_kb / 1024))
        i7_dt=$((i7_now - i7_t0))
        i7_dkb=$((i7_kb - i7_kb0))
        i7_extra=""
        if [ "$i7_dt" -ge 2 ] && [ "$i7_dkb" -gt 256 ]; then
          i7_spd=$(awk -v d="$i7_dkb" -v t="$i7_dt" 'BEGIN { printf "%.1f MB/s", (d / 1024.0) / t }')
          i7_rem_kb=$((385024 - i7_kb))
          if [ "$i7_rem_kb" -gt 0 ]; then
            i7_rem=$((i7_rem_kb * i7_dt / i7_dkb))
            i7_eta=$(sil_fmt_eta "$i7_rem")
            i7_extra=" · $i7_spd · $i7_eta"
          else
            i7_extra=" · $i7_spd"
          fi
        fi
        i7_msg="Downloading IW7-Mod data: ${i7_mb} / ~376 MB${i7_extra}"
        if [ "$i7_msg" != "$i7_last_msg" ]; then
          printf '==> %s\n' "$i7_msg"
          i7_last_msg=$i7_msg
        fi
        i7_last_kb=$i7_kb
      fi
    fi
    err=$(tail -n +$((cseen + 1)) "$console" 2>/dev/null | grep -oE "AppID $s_app.*LaunchApp failed with [A-Za-z_]+[0-9]*" | grep -oE '[A-Za-z]+Error_[0-9]+|k_E[A-Za-z0-9_]+' | tail -1)
    case "$err" in
      AppError_5) die "Steam has no license for $s_name on this account: sign in with the account that owns it (Open Steam)" ;;
      ?*) env -u WINELOADER bash "$kit/steam.sh" open; die "Steam could not start $s_name ($err): look at Steam's window" ;;
    esac
    sleep 0.25
  done
  if [ -z "$game_pid" ] && [ -n "${s_client:-}" ]; then
    die "$s_name did not start (see logs/${log##*/})"
  elif [ -z "$game_pid" ]; then
    env -u WINELOADER bash "$kit/steam.sh" open
    die "Steam did not start $s_name: look at Steam's window (license, an update, or a first-time setup step)"
  fi
  : > "$marker"
  # Call of Duty 2 minimizes its fullscreen window when it loses focus, and
  # Wine did not restore it when the player came back (black screen): Ghosts'
  # helper restores the game's window when its Mac app is activated again
  focus_pid=
  # Every part (2026-11-23): the game is made the active app when its window
  # is up, and its window is restored after Cmd+Tab (focus_helper above).
  # Call of Duty, United Offensive (GLDirect) and Call of Duty 2 minimized
  # their fullscreen window when they lost the focus and stayed black, and
  # WWII (s2) left its window iconic at -32000,-32000 (2026-11-22): restoring
  # it in Wine brought the picture back.
  # The helper needs the game's own Mac process: the one found above can be
  # Wine's start.exe (its command line names the game too), which is never
  # the frontmost app, so the window was never restored (Call of Duty and
  # Call of Duty 2's campaign: after Cmd+Tab the window stayed minimized)
  app_pid=$game_pid
  for pid in $(game_pids "$s_exe"); do
    case "$(ps -o comm= -p "$pid" 2>/dev/null)" in *"$s_exe") app_pid=$pid; break ;; esac
  done
  # (other parts: found by program name, the fix's executable when it runs
  # the game in its own process, e.g. iw3sp_mod.exe: comm is cut to 16
  # characters there and named start.exe's pid instead, 2026-11-23)
  if [ "$s_exe" = iw6sp64_ship.exe ] && [ -x "$kit/payload/iw6/iw6-focus" ]; then
    # Ghosts' campaign: the helper exactly as Siliconium's own Ghosts runs it
    # (no executable name: it also hides Ghosts' black fullscreen window while
    # another app is in front)
    SIL_FOCUS_FROM="$sil_focus_from" "$kit/payload/iw6/iw6-focus" "$app_pid" "$wine" "$kit/payload/iw6/iw6-restore.exe" >> "$log" 2>&1 &
    focus_pid=$!
  else
    # (Ghosts' multiplayer passes its executable: a Ghosts name keeps the hiding)
    focus_helper "${m_start:+${m_start##*/}:}$s_exe" 0
  fi
  while [ -n "$(game_pids "$s_exe")" ]; do sleep 2; done
  mtld3d_save_cache
  if [ -z "${s_client:-}" ] || [ "${s_client:-}" = own ]; then steam_mod_remove "$dir"; fi
  [ -n "$focus_pid" ] && kill "$focus_pid" 2>/dev/null
  # Only remove ephemeral dev clones (AW_DXMT_DIR / SIL_DXMT_SO); the standard
  # persistent $home/cache/aw-engine stays warm across launches.
  [ "$aw_engine_ephemeral" = 1 ] && [ -n "${aw_engine:-}" ] &&
    (sleep 120; /usr/bin/python3 -I -c 'import shutil, sys; shutil.rmtree(sys.argv[1])' "$aw_engine") > /dev/null 2>&1 &
  exit 0
fi

# --- Black Ops II's campaign through Steam for Windows (prefix-steam) ----------
# Steam (restarted above, so Wine sees the 1x display mode and Steam gets this
# environment: x87 accelerator, DXMT settings) signs in by itself and starts
# the game, checking its license; Siliconium's patches are in the engine and the
# environment, the game's files are Steam's own.
if [ "$t" = t6s ]; then
  if [ "${CAPTURE_DISPLAY:-0}" = 2 ]; then reg add 'HKCU\Software\Wine\AppDefaults\t6sp.exe\Mac Driver' /v CaptureDisplaysForFullscreen /d y /f
  else reg add 'HKCU\Software\Wine\AppDefaults\t6sp.exe\Mac Driver' /v CaptureDisplaysForFullscreen /d n /f; fi
  # a hardware profile made on an Apple GPU (fullscreen 1920x1080), once, as for BO2
  if on BO2_HW_PROFILE && [ ! -f "$dir/players/.sil-defaults-hardware" ]; then
    mkdir -p "$dir/players"
    cp "$kit/payload/bo2/hardware.chp" "$dir/players/hardware.chp" && : > "$dir/players/.sil-defaults-hardware"
  fi
  [ "${STEAM_SCREEN:-1}" != 0 ] && bo2_hw_screen "$dir/players" - "$dir"/players/hardware*.chp
  bs="$kit/bo2-steam.sh"
  clog="$WINEPREFIX/drive_c/Program Files (x86)/Steam/logs/connection_log.txt"
  seen=$(wc -l < "$clog" 2>/dev/null | tr -d ' '); seen=${seen:-0}
  reg_flush
  bash "$bs" start || exit 1
  signed=
  for _ in $(seq 1 360); do   # this Steam's sign-in (up to 3 minutes)
    tail -n +$((seen + 1)) "$clog" 2>/dev/null | grep '\[Logged On,' > /dev/null && { signed=1; break; }
    sleep 0.5
  done
  if [ -z "$signed" ]; then
    bash "$bs" open
    die "Steam is not signed in: sign in in Steam's window (tick Remember me), then press Play Campaign again"
  fi
  console="$WINEPREFIX/drive_c/Program Files (x86)/Steam/logs/console_log.txt"
  cseen=$(wc -l < "$console" 2>/dev/null | tr -d ' '); cseen=${cseen:-0}
  bash "$bs" launch
  # The game is running when t6sp.exe works the CPU; Steam says right away
  # when it will not start it
  game_pid=
  for _ in $(seq 1 720); do
    for pid in $(pgrep -f 't6sp\.exe'); do
      cpu=$(ps -o %cpu= -p "$pid" 2>/dev/null | tr -d ' '); cpu=${cpu%%.*}
      [ "${cpu:-0}" -gt 20 ] && { game_pid=$pid; break 2; }
    done
    err=$(tail -n +$((cseen + 1)) "$console" 2>/dev/null | grep -oE 'AppID 202970.*LaunchApp failed with [A-Za-z_]+[0-9]*' | grep -oE '[A-Za-z]+Error_[0-9]+|k_E[A-Za-z0-9_]+' | tail -1)
    case "$err" in
      AppError_5) die "Steam has no license for Black Ops II on this account: sign in with the account that owns it (Open Steam)" ;;
      ?*) bash "$bs" open; die "Steam could not start the campaign ($err): look at Steam's window" ;;
    esac
    sleep 0.25
  done
  if [ -z "$game_pid" ]; then
    bash "$bs" open
    die "Steam did not start the campaign: look at Steam's window (license, an update, or a first-time setup step)"
  fi
  log="$home/logs/bo2-steam-campaign.log"; log_cap "$log"
  focus_helper t6sp.exe
  while pgrep -f 't6sp\.exe' >/dev/null; do sleep 2; done
  [ -n "$focus_pid" ] && kill "$focus_pid" 2> /dev/null
  exit 0
fi

# --- Black Ops III for Windows through boiii (BOIII / Ezz client) ----------------
# boiii.exe sits in the game folder and starts the game from there (it is the
# working directory), on DXMT (Direct3D 11 -> Metal, 64-bit).
if [ "$t" = t7 ]; then
  for exe in boiii.exe boiii-beta.exe BlackOps3.exe; do
    if [ "${CAPTURE_DISPLAY:-0}" = 2 ]; then reg add "HKCU\\Software\\Wine\\AppDefaults\\$exe\\Mac Driver" /v CaptureDisplaysForFullscreen /d y /f
    else reg add "HKCU\\Software\\Wine\\AppDefaults\\$exe\\Mac Driver" /v CaptureDisplaysForFullscreen /d n /f; fi
  done
  # Shaders shared with the Steam Library's Black Ops III. DXMT keeps its
  # translated shaders under the game's name for both (dxmt/BlackOps3.exe/
  # shaders_*.db: boiii runs the game's code), but Metal's compiled ones
  # under the process's name: dxmt/boiii.exe/com.apple.metal and
  # dxmt/BlackOps3.exe/com.apple.metal, so one of them always started cold
  # after the other. boiii's becomes a link to the game's, made once (the
  # larger of the two is kept: Metal's cache cannot be merged), as for
  # Black Ops II and IW7-Mod; never while either game runs
  bo3_shared_metal() {   # <DXMT's cache folder>
    local dxmt=$1 shared own a b exe
    case "$dxmt" in /?*/dxmt) ;; *) return 0 ;; esac
    shared="$dxmt/BlackOps3.exe/com.apple.metal"
    pgrep -f '[B]lackOps3\.exe|[b]oiii(-beta)?\.exe' > /dev/null && return 0
    for exe in boiii.exe boiii-beta.exe; do
      own="$dxmt/$exe/com.apple.metal"
      [ -L "$own" ] && continue
      mkdir -p "$dxmt/$exe" "$dxmt/BlackOps3.exe" || continue
      if [ -d "$own" ]; then
        a=$(du -sk "$own" 2>/dev/null | cut -f1) b=$(du -sk "$shared" 2>/dev/null | cut -f1)
        if [ "${a:-0}" -gt "${b:-0}" ]; then rm -rf "$shared" && mv "$own" "$shared" || continue
        else rm -rf "$own" || continue; fi
      fi
      mkdir -p "$shared" && ln -s "$shared" "$own"
    done
  }
  bo3_shared_metal "$(getconf DARWIN_USER_CACHE_DIR 2>/dev/null)dxmt"
  # The game refuses to start unless Steam is installed ("Steam must be
  # installed for the game to run"), but boiii plays without it: register an
  # empty Steam folder whose steam.exe does nothing (no Steam, no login).
  steam="$WINEPREFIX/drive_c/Program Files (x86)/Steam"
  mkdir -p "$steam"
  [ -f "$steam/steam.exe" ] || cp "$WINEPREFIX/drive_c/windows/system32/rundll32.exe" "$steam/steam.exe"
  reg add 'HKCU\Software\Valve\Steam' /v SteamExe /d 'c:/program files (x86)/steam/steam.exe' /f
  reg add 'HKCU\Software\Valve\Steam' /v SteamPath /d 'c:/program files (x86)/steam' /f
  reg add 'HKLM\Software\Wow6432Node\Valve\Steam' /v InstallPath /d 'C:\Program Files (x86)\Steam' /f
  # boiii's launcher is Internet Explorer's browser control (Wine's mshtml,
  # drawn by Wine Gecko). The prefix is made with mshtml off (Plutonium's
  # installer), which leaves its registration incomplete (the HTML document
  # class may be there, its content types are not) and the launcher white:
  # run mshtml's own registration once per prefix.
  reg_flush
  if [ ! -f "$WINEPREFIX/.sil-mshtml" ]; then
    env -u WINELOADER WINEDLLOVERRIDES="mscoree,winemenubuilder.exe=" "$plain_wine" regsvr32 /s mshtml.dll > /dev/null 2>&1 &&
    env -u WINELOADER WINEDLLOVERRIDES="mscoree,winemenubuilder.exe=" "$plain_wine" 'C:\windows\syswow64\regsvr32.exe' /s mshtml.dll > /dev/null 2>&1 &&
      : > "$WINEPREFIX/.sil-mshtml"
  fi
  # Prefixes made before the engine had winegstreamer: register it once.
  sys="$WINEPREFIX/drive_c/windows"
  if [ ! -f "$sys/system32/winegstreamer.dll" ] && [ -f "$engine/lib/wine/x86_64-windows/winegstreamer.dll" ]; then
    cp "$engine/lib/wine/x86_64-windows/winegstreamer.dll" "$sys/system32/"
    cp "$engine/lib/wine/i386-windows/winegstreamer.dll" "$sys/syswow64/" 2>/dev/null
    env -u WINELOADER "$plain_wine" regsvr32 /s winegstreamer.dll > /dev/null 2>&1
    env -u WINELOADER "$plain_wine" 'C:\windows\syswow64\regsvr32.exe' /s winegstreamer.dll > /dev/null 2>&1
  fi
  [ "${prewarm_active:-0}" = 0 ] && [ "$reg_disk_synced" = 0 ] && { "$WINESERVER" -w 2>/dev/null; reg_disk_synced=1; }
  # Black Ops III checks for Media Foundation's video decoders ("requires the
  # Windows Media Feature Pack"): the engine's winegstreamer, with GStreamer
  # and its plugins (Apple's VideoToolbox decoder among them) in lib64.
  export GST_PLUGIN_SYSTEM_PATH_1_0="$engine/lib64/gstreamer-1.0" GST_PLUGIN_PATH_1_0= \
         GST_REGISTRY_1_0="$home/cache/gstreamer-registry.bin"
  # boiii keeps the game's location in AppData\Local\boiii\user\game_path.txt
  # (Windows path, no newline; it guesses Steam's default otherwise): point
  # it at the chosen folder, so the folder never has to be picked in boiii.
  bdir="$WINEPREFIX/drive_c/users/crossover/AppData/Local/boiii/user"
  mkdir -p "$bdir"
  printf '%s' "$(sil_winpath "$dir")" > "$bdir/game_path.txt"
  log="$home/logs/boiii-play.log"
  # boiii's launcher window: mshtml stays on here
  export WINEDLLOVERRIDES="mscoree,winemenubuilder.exe="
  # (DXMT's MetalFX swapchain was tried: it scales the game's own back buffer
  # up, 2560x1440 -> 3840x2160 at 1.5, which cost frames instead of saving them.)
  # mods' unsafe Lua functions: boiii asks first unless the player turned
  # "Ask before unsafe Lua" off (BOIII_SAFE_LUA=0), then -unsafe-lua
  on BOIII_SAFE_LUA || GAME_ARGS="${GAME_ARGS:+$GAME_ARGS }-unsafe-lua"
  # Workshop mods: boiii takes Wine for Linux and runs steamcmd/steamcmd.sh
  # (it would fetch Linux SteamCMD, which can't run on macOS: "Retry Limit
  # Reached"). Give it Valve's macOS SteamCMD (checked against Valve's
  # signature) behind a steamcmd.sh of ours: SteamCMD gets its own home in the
  # game folder (never the Mac Steam app's), and its steamapps is linked
  # where boiii looks for the downloaded mod.
  scmd="$dir/steamcmd"
  if [ ! -x "$scmd/mac/steamcmd" ]; then
    tmp=$(mktemp -d)
    if curl -fsSL --retry 2 -o "$tmp/s.tgz" https://steamcdn-a.akamaihd.net/client/installer/steamcmd_osx.tar.gz &&
       mkdir -p "$tmp/x" && tar -xzf "$tmp/s.tgz" -C "$tmp/x" &&
       codesign -v "$tmp/x/steamcmd" 2>/dev/null &&
       codesign -dv "$tmp/x/steamcmd" 2>&1 | grep 'TeamIdentifier=MXGJJ98X76' > /dev/null; then
      rm -rf "$scmd/mac"; mkdir -p "$scmd"; mv "$tmp/x" "$scmd/mac"
    fi
    rm -rf "$tmp"
  fi
  if [ -x "$scmd/mac/steamcmd" ]; then
    rm -rf "$dir/steamcmd.tar.gz" "$scmd/linux32"
    # steamcmd.sh is a small Windows program of ours (kit/tools/steamcmd-bridge.c):
    # boiii can only wait for Windows programs; it runs the Mac script below
    cp "$kit/payload/bo3w/steamcmd-bridge.exe" "$scmd/steamcmd.sh"
    cat > "$scmd/sil-steamcmd.sh" <<'SH'
#!/bin/bash
# Siliconium: Valve's macOS SteamCMD for boiii's Workshop downloads, started by
# steamcmd.sh (our Windows bridge), which waits for done.<token>
here="$(cd "${0%/*}" && pwd -P)"
token=$1; shift
export HOME="$here/home"
root="$HOME/Library/Application Support/Steam"
mkdir -p "$root/steamapps"
[ -L "$here/steamapps" ] || rm -rf "$here/steamapps"
ln -sfn "$root/steamapps" "$here/steamapps"
# SteamCMD's log stays out of boiii's sight: when boiii reads "update
# started" in steamcmd/logs/content_log.txt it empties the download folder
# (Windows SteamCMD's leftovers), which the macOS one is still writing
rm -rf "$here/logs"
"$here/mac/steamcmd.sh" "$@"
rc=$?
echo "$rc" > "$here/done.$token.tmp" && mv "$here/done.$token.tmp" "$here/done.$token"
exit "$rc"
SH
    chmod +x "$scmd/sil-steamcmd.sh"
  fi
  cd "$dir" || exit 1
  # BlackOps3.start stays behind when the game is stopped from the app, and the
  # next start would offer Safe Mode (which lowers the graphics settings).
  rm -f BlackOps3.start
  # The player name from the app's settings, in boiii's own profile, only
  # while boiii has none of its own: the name typed in boiii's launcher is kept
  # Siliconium 1.0.0 padded short names with "^7" to 16 bytes (Ezz v3.0.0
  # crashed on its server thread with shorter names). Ezz v3.1.0 crashed with
  # the padded "Player^7^7^7^7^7" as the lobby loaded, and played with an
  # unpadded 11-character name: no padding any more, and 1.0.0's is removed.
  # Without a name of the player's own (the app's generic "Player" included),
  # boiii's name is "Siliconium".
  boiii_version=$(/usr/bin/python3 -I - "$dir/boiii_players/properties.json" "${3:-${PLAYER_NAME:-}}" <<'PY' 2>/dev/null || true
import json, os, sys
p, name = sys.argv[1], sys.argv[2]
d = {}
if os.path.exists(p):
    try: d = json.load(open(p, encoding="utf-8-sig"))   # boiii writes a UTF-8 byte order mark
    except Exception: sys.exit(0)                        # unreadable: leave it alone
current = d.get("playerName", "")
while current.endswith("^7") and len(current) > 2:     # Siliconium 1.0.0's padding
    current = current[:-2]
if name == "Player":                                    # the app's generic default
    name = ""
if current in ("", "crossover", "Unknown Soldier", "Player"):
    current = name or "Siliconium"
if d.get("playerName") != current:
    d["playerName"] = current
    os.makedirs(os.path.dirname(p), exist_ok=True)
    json.dump(d, open(p, "w", encoding="utf-8-sig"), separators=(",", ":"))
ver = d.get("selectedVersion", "")
if isinstance(ver, str) and ver:
    print(ver)
PY
)
  # First start: the game's auto-detect picks for an unknown GPU (half
  # resolution, no shadows, no ambient occlusion). Set it up once with Apple
  # Silicon-tuned DXMT pipelining (BackbufferCount=3, MaxFrameLatency=2, Vsync=0,
  # OITLayers=8, SpotShadowTextureSize=2048, Volumetric/SSS off) and RAM/GPU
  # scaling for base/8 GB Macs. Afterwards the game's own options always rule.
  bo3_ini_batch() {
    local f=$1 tmp
    shift
    [ $# -gt 0 ] || return 0
    tmp=$(mktemp "$f.XXXXXX") || return 0
    if awk -v n="$#" '
      BEGIN {
        for (i = 1; i <= n; i++) {
          kv = ARGV[i]; ARGV[i] = ""
          p = index(kv, "=")
          k = substr(kv, 1, p - 1); v = substr(kv, p + 1)
          order[i] = k; want[k] = v
        }
      }
      {
        eq = index($0, " = \"")
        if (eq > 1) {
          k = substr($0, 1, eq - 1)
          if (k in want) {
            if (!(k in seen)) {
              rest = substr($0, eq + 4); q = index(rest, "\"")
              tail = q ? substr(rest, q + 1) : ""
              print k " = \"" want[k] "\"" tail
              seen[k] = 1
            }
            next
          }
        }
        print
      }
      END {
        for (i = 1; i <= n; i++) {
          k = order[i]
          if (!(k in seen)) { printf "%s = \"%s\"\n", k, want[k]; seen[k] = 1 }
        }
      }
    ' "$@" "$f" > "$tmp"; then
      cmp -s "$tmp" "$f" && rm -f "$tmp" || mv -f "$tmp" "$f"
    else
      rm -f "$tmp"
    fi
  }
  ini="$dir/boiii_players/config.ini"
  if on BOIII_GRAPHICS && [ ! -f "$dir/boiii_players/.sil-defaults-config.ini" ] && [ -n "${dw:-}" ]; then
    mkdir -p "$dir/boiii_players"; [ -f "$ini" ] || : > "$ini"
    bo3_vmem=0.95 bo3_tex=0 bo3_res=100
    [ "${sil_ram_gb:-16}" -le 8 ] && { bo3_vmem=0.75; bo3_tex=1; }
    if [ "${dw:-0}" -ge 3200 ]; then bo3_res=70
    elif [ "${dw:-0}" -ge 2000 ]; then bo3_res=80
    elif [ "${sil_gpu_cores:-16}" -le 10 ] && [ "${dw:-0}" -ge 1900 ]; then bo3_res=85
    fi
    bo3_ini_batch "$ini" AutoDetectHasRun=1 RestrictGraphicsOptions=0 FullScreenMode=1 "WindowSize=${bo3_win_w:-$dw}x${bo3_win_h:-$dh}" \
      "RefreshRate=${hz:-60}" Vsync=0 BackbufferCount=3 MaxFrameLatency=2 "VideoMemory=$bo3_vmem" \
      "ResolutionPercent=$bo3_res" MeshQuality=0 "TextureQuality=$bo3_tex" TextureFilter=2 \
      DisableDynamicLightShadows=0 DisableDynamicSunShadows=0 SpotShadowTextureSize=2048 \
      ShadowFiltering=1 VolumetricLightingEnabled=0 OITLayers=8 "SSAOTechnique=GTAO Medium Quality" \
      "AATechnique=Filmic SMAA T2x" SubsurfaceScattering=0 MotionBlur=Off
    : > "$dir/boiii_players/.sil-defaults-config.ini"
  fi
  # Every launch (BOIII_SCREEN=0 leaves it to the game): fullscreen at the
  # display's native size and refresh rate, and the game's frame cap at that
  # rate. Its own default cap is 60 (MaxFPS = "60"), and a crash or the
  # launcher could leave it windowed.
  if on BOIII_SCREEN && [ -n "${dw:-}" ] && [ -n "${dh:-}" ]; then
    mkdir -p "$dir/boiii_players"; [ -f "$ini" ] || : > "$ini"
    bo3_pairs=(FullScreenMode=1 "WindowSize=${bo3_win_w:-$dw}x${bo3_win_h:-$dh}" "MaxFPS=${maxfps:-0}")
    [ -n "${hz:-}" ] && bo3_pairs+=("RefreshRate=$hz")
    bo3_ini_batch "$ini" "${bo3_pairs[@]}"
    # Ezz keeps the engine's own cap in boiii_players/user/config.cfg
    # (set com_maxfps "60"), and it overrides MaxFPS: the game stopped at 60-62.
    ucfg="$dir/boiii_players/user/config.cfg"
    if [ -f "$ucfg" ]; then
      if grep -q '^set com_maxfps ' "$ucfg"; then
        sed -i '' -E "s/^set com_maxfps \"[^\"]*\"/set com_maxfps \"${maxfps:-0}\"/" "$ucfg"
      else
        printf 'set com_maxfps "%s"\n' "${maxfps:-0}" >> "$ucfg"
      fi
    fi
  fi
  # Fullscreen: a 1x display mode of the desktop's size while the game runs
  # (as for BO1/BO2). On a HiDPI desktop the game otherwise switches to the
  # panel's full pixel size and shows its 1080p picture in one corner.
  if on DISPLAY_MODE && [ -n "${dw:-}" ] && [ -n "${dh:-}" ]; then
    stop_displaymode
    log_cap "$home/logs/displaymode.log"
    keep=$(keep_hidpi)   # (see hold_1x_size)
    boiii_dm_size=$(stat -f %z "$home/logs/displaymode.log" 2>/dev/null || echo 0)
    SIL_KEEP_UNSCALED=$keep "$kit/tools/displaymode" "$dw" "$dh" $$ >> "$home/logs/displaymode.log" 2>&1 &
    for _ in $(seq 50); do
      [ "$(stat -f %z "$home/logs/displaymode.log" 2>/dev/null || echo 0)" != "$boiii_dm_size" ] && break
      sleep 0.1
    done
  fi
  # Ezz can exit the launcher after starting versions/boiii-beta.exe.
  # Keep this session and its display mode alive until Wine finishes.
  # Keep the Wine-compatible version picker through this launch. Ezz still
  # fetches the selected version and forces its data update on first use.
  if [ "$mode" = launcher ] &&
     /usr/bin/python3 -I "$kit/tools/boiii-launcher-compat.py" boiii.exe "${bdir%/user}/data/launcher/main.js"; then
    GAME_ARGS="${GAME_ARGS:+$GAME_ARGS }-noupdate"
  fi
  reg_flush
  # "Play" starts the version chosen in Ezz's launcher (Stable or Beta,
  # boiii_players/properties.json "selectedVersion"): -launch alone always
  # started the Stable build, which stops with "Connection Interrupted".
  boiii_exe=boiii.exe
  if [ "$mode" != launcher ] && [ "${boiii_version:-}" = beta ] && [ -f versions/boiii-beta.exe ]; then
    boiii_exe=versions/boiii-beta.exe
    case " ${GAME_ARGS:-} " in *" -noupdate "*) ;; *) GAME_ARGS="${GAME_ARGS:+$GAME_ARGS }-noupdate" ;; esac
  fi
  # shellcheck disable=SC2086
  : > "$log"
  printf '==> %s\n' "Starting Black Ops III..."
  focus_helper "${boiii_exe##*/}"
  boiii_watch_pid=
  boiii_stop_watch() { [ -n "${boiii_watch_pid:-}" ] && { kill "$boiii_watch_pid" 2>/dev/null; wait "$boiii_watch_pid" 2>/dev/null; boiii_watch_pid=; } || true; }
  boiii_data_root="${bdir%/user}"
  # On first start (or in Ezz's launcher), boiii.exe downloads its data/version
  # files (~80 MB). Watch folder growth and report live speed & ETA, then stop
  # automatically once idle so nothing polls during gameplay.
  if [ ! -d "$boiii_data_root/data" ] || [ "$mode" = launcher ]; then
    boiii_first=0; [ -d "$boiii_data_root/data" ] || boiii_first=1
    boiii_kb0=$(du -sk "$boiii_data_root" "$dir/versions" 2>/dev/null | awk '{s+=$1} END{print s+0}')
    boiii_prev_exit=$(trap -p EXIT | sed -E "s/^trap -- '(.*)' EXIT$/\1/")
    trap "boiii_stop_watch${boiii_prev_exit:+; $boiii_prev_exit}" EXIT
    (
      b_t0="" b_last_kb=${boiii_kb0:-0} b_idle=0 b_last_msg=""
      while sleep 1.5; do
        b_kb=$(du -sk "$boiii_data_root" "$dir/versions" 2>/dev/null | awk '{s+=$1} END{print s+0}')
        if [ "$b_kb" -gt "$b_last_kb" ]; then
          b_idle=0
          b_dkb=$((b_kb - ${boiii_kb0:-0}))
          if [ "$b_dkb" -gt 256 ]; then
            b_now=$(date +%s)
            [ -z "$b_t0" ] && b_t0=$b_now
            b_mb=$((b_dkb / 1024)); [ "$b_mb" -lt 1 ] && b_mb=1
            b_dt=$((b_now - b_t0))
            b_extra=""
            if [ "$b_dt" -ge 2 ]; then
              b_spd=$(awk -v d="$b_dkb" -v t="$b_dt" 'BEGIN { printf "%.1f MB/s", (d / 1024.0) / t }')
              if [ "$boiii_first" = 1 ] && [ "$b_dkb" -lt 81920 ]; then
                b_rem=$(( (81920 - b_dkb) * b_dt / b_dkb ))
                b_extra=" ($b_spd · $(sil_fmt_eta "$b_rem"))"
              else
                b_extra=" ($b_spd)"
              fi
            fi
            b_msg="Downloading BOIII data: ${b_mb} MB${b_extra}"
            if [ "$b_msg" != "$b_last_msg" ]; then
              printf '==> %s\n' "$b_msg"
              b_last_msg=$b_msg
            fi
          fi
          b_last_kb=$b_kb
        else
          b_idle=$((b_idle + 1))
          [ "$b_idle" -ge 15 ] && break
        fi
      done
    ) &
    boiii_watch_pid=$!
  fi
  "$wine" "$boiii_exe" ${GAME_ARGS:-} >> "$log" 2>&1
  boiii_status=$?
  boiii_stop_watch
  wait_wine_exit 'boiii(-[[:alnum:]._-]+)?\.exe|BlackOps3\.exe' 1
  exit "$boiii_status"
fi

# --- Plutonium and game settings -----------------------------------------------
winpath=$(sil_winpath "$dir")
plutonium_cfg="$plutonium/config.json"
set_cvar() { sed -i '' -E "s/^seta $2 \"[^\"]*\"/seta $2 \"$3\"/" "$1"; }
set_or_add() { if grep -q "^seta $2 " "$1"; then set_cvar "$@"; else printf 'seta %s "%s"\n' "$2" "$3" >> "$1"; fi; }
# Single-pass awk cvar updater (avoids dozens of grep/sed forks per .cfg file).
# Uses ARGV[1..n] instead of -v with embedded newlines (macOS BSD awk rejects
# literal newlines in -v variable assignments).
cfg_batch() {   # cfg_batch <file> name val [name val ...]
  local cfg=$1 tmp
  shift
  [ $# -ge 2 ] || return 0
  [ -f "$cfg" ] || : > "$cfg"
  tmp=$(mktemp "$cfg.sil.XXXXXX") || return 1
  if awk -v n="$#" '
    BEGIN {
      m = 0
      for (i = 1; i + 1 <= n; i += 2) {
        k = ARGV[i]; v = ARGV[i + 1]
        ARGV[i] = ""; ARGV[i + 1] = ""
        if (k == "") continue
        if (!(k in want)) order[++m] = k
        want[k] = v
      }
    }
    $1 == "seta" && ($2 in want) {
      k = $2; seen[k] = 1
      if (sub(/^seta [^ ]+ "[^"]*"/, "seta " k " \"" want[k] "\"")) { print; next }
      printf "seta %s \"%s\"\n", k, want[k]; next
    }
    { print }
    END {
      for (i = 1; i <= m; i++) {
        k = order[i]
        if (!(k in seen)) printf "seta %s \"%s\"\n", k, want[k]
      }
    }
  ' "$@" "$cfg" > "$tmp"; then
    cmp -s "$tmp" "$cfg" && rm -f "$tmp" || mv -f "$tmp" "$cfg"
    return 0
  else
    rm -f "$tmp"
    return 1
  fi
}
desktop=${dw:+${dw}x$dh}
# Default settings, applied once per game profile (marker file), so what the
# player changes in the game afterwards is kept: fullscreen at the display's
# resolution, sync every frame, automatic texture quality, 16x anisotropy.
defaults_once() {   # defaults_once <cfg> <marker> name value ...
  local cfg=$1 marker=$2; shift 2
  [ -f "$marker" ] && return 0
  cfg_batch "$cfg" "$@" && : > "$marker"
}
common_cvars() {
  local cfg=$1 tmp fs_fix=0 msaa_fix=0 raw_in=0 c_aim=0 intro_val=0 do_startup=1
  [ -f "$cfg" ] || : > "$cfg"
  [ "$t" != t6 ] && [ "${CAPTURE_DISPLAY:-1}" != 0 ] && fs_fix=1
  on MSAA_FIX && msaa_fix=1
  [ "${RAW_INPUT:-1}" = 1 ] && raw_in=1
  [ "${CONSOLE_AIM:-1}" != 0 ] && c_aim=1
  if [ "$t" = t5 ]; then
    [ "${BO1_SKIP_INTRO:-0}" = 1 ] && intro_val=1
  elif on SKIP_INTRO; then
    intro_val=1
  fi
  [ "$t" = t6 ] && do_startup=0
  tmp=$(mktemp "$cfg.sil.XXXXXX") || return 0
  if awk \
    -v t="$t" -v desktop="$desktop" -v fs_fix="$fs_fix" -v msaa_fix="$msaa_fix" \
    -v raw_in="$raw_in" -v c_aim="$c_aim" -v deadzone="${STICK_DEADZONE:-0.08}" \
    -v intro_val="$intro_val" -v do_startup="$do_startup" '
    BEGIN {
      m = 0
      if (raw_in == 1) { order[++m] = "raw_input"; want["raw_input"] = "1"; order[++m] = "m_filter"; want["m_filter"] = "0" }
      if (c_aim == 1) {
        nc = split("aim_accel_turnrate_enabled=1 aim_accel_turnrate_lerp=1200 aim_input_graph_enabled=1 aim_input_graph_index=3 aim_scale_view_axis=1 aim_turnrate_yaw=260 aim_turnrate_pitch=90 aim_turnrate_yaw_ads=90 aim_turnrate_pitch_ads=55 aim_autoaim_enabled=1 aim_lockon_enabled=1 aim_slowdown_enabled=1", a, " ")
        for (i = 1; i <= nc; i++) {
          p = index(a[i], "="); k = substr(a[i], 1, p - 1); v = substr(a[i], p + 1)
          order[++m] = k; want[k] = v
        }
      }
      order[++m] = "gpad_stick_deadzone_min"; want["gpad_stick_deadzone_min"] = deadzone
      order[++m] = "cl_mouseAccel"; want["cl_mouseAccel"] = "0"
      order[++m] = "com_introPlayed"; want["com_introPlayed"] = intro_val
      if (do_startup == 1) { order[++m] = "com_startupIntroPlayed"; want["com_startupIntroPlayed"] = intro_val }
      mon = 0; cur_mode = ""; rmode_w = ""; is_windowed = 0
    }
    {
      lines[NR] = $0
      if ($0 ~ /^seta r_monitor "[0-9]+"/) {
        s = $0; sub(/^seta r_monitor "/, "", s); sub(/".*/, "", s); mon = s + 0
      } else if ($0 ~ /^seta r_mode "[0-9]+x[0-9]+"/) {
        s = $0; sub(/^seta r_mode "/, "", s); sub(/".*/, "", s); cur_mode = s
        w = s; sub(/x.*/, "", w); rmode_w = w
      } else if ($0 ~ /^seta r_fullscreen "0"/) {
        is_windowed = 1
      }
    }
    END {
      fit_mode = 0
      if (desktop != "") {
        if (rmode_w == "800" || ((t != "t6" || mon <= 1) && cur_mode != "" && cur_mode != desktop && !is_windowed)) {
          fit_mode = 1
        }
      }
      for (i = 1; i <= NR; i++) {
        line = lines[i]
        if (fs_fix && line ~ /^seta r_fullscreen "2"/) {
          sub(/^seta r_fullscreen "2"/, "seta r_fullscreen \"1\"", line)
        }
        if (msaa_fix && line ~ /^seta r_aaSamples "(8|16|32)"/) {
          sub(/^seta r_aaSamples "(8|16|32)"/, "seta r_aaSamples \"4\"", line)
        }
        if (fit_mode && line ~ /^seta r_mode "[^"]*"/) {
          sub(/^seta r_mode "[^"]*"/, "seta r_mode \"" desktop "\"", line)
        }
        split(line, f, " ")
        if (f[1] == "seta" && (f[2] in want)) {
          k = f[2]; seen[k] = 1
          if (sub(/^seta [^ ]+ "[^"]*"/, "seta " k " \"" want[k] "\"", line)) { print line; continue }
          printf "seta %s \"%s\"\n", k, want[k]; continue
        }
        print line
      }
      for (i = 1; i <= m; i++) {
        k = order[i]
        if (!(k in seen)) printf "seta %s \"%s\"\n", k, want[k]
      }
      if (desktop != "" && cur_mode == "" && !is_windowed) {
        printf "seta r_mode \"%s\"\n", desktop
      }
    }
  ' "$cfg" > "$tmp"; then
    cmp -s "$tmp" "$cfg" && rm -f "$tmp" || mv -f "$tmp" "$cfg"
  else
    rm -f "$tmp"
  fi
}
t5mp_engine=
prepare_t5mp_engine() {
  local mp_exe="$plutonium/games/t5mp.exe" entry persist="$home/cache/t5mp-engine" new sig mp_stat old
  local renderer="$kit/payload/bo1/mp-d3d9.dll"
  [ -f "$renderer" ] && [ -f "$mp_exe" ] || return 1
  cmp -s "$engine/lib/wine/i386-windows/d3d9.dll" "$kit/payload/i386-windows/d3d9.dll" || return 1
  # Verify this renderer matches this exact t5mp.exe image (cached by mtime:size).
  mp_stat=$(stat -f '%m:%z' "$mp_exe" 2>/dev/null || echo 0:0)
  if [ "$(cat "$persist/.sil-mp-stat" 2>/dev/null)" != "$mp_stat" ]; then
    [ "$(shasum -a 256 < "$mp_exe")" = "6a544494722aaf90ae241d687fca0aebd73f97f0d79412d0f8c311f6c369c3fb  -" ] || return 1
  fi
  # Clean up any legacy random t5mp-engine.* directories left by older builds.
  for old in "$home/cache"/t5mp-engine.*; do
    [ -d "$old" ] && /usr/bin/python3 -I -c 'import shutil, sys; shutil.rmtree(sys.argv[1])' "$old"
  done
  # Persistent stamped clone: eliminates ~18 s of cold LaunchServices bundle
  # registration and preserves macOS's com.apple.metal compiled shader cache
  # (up to 70x faster MoltenVK shard loading) across every BO1 MP Online start.
  sig=$(stat -f '%m:%z' \
    "$engine/siliconium.version" \
    "$engine/lib/wine/x86_64-unix/winemac.so" \
    "$engine/lib/wine/x86_64-unix/winecoreaudio.so" \
    "$engine/lib/wine/x86_64-unix/ntdll.so" \
    "$engine/lib/wine/x86_64-unix/winebus.so" \
    "$engine/lib/wine/i386-windows/xinput1_3.dll" \
    "$engine/lib/wine/i386-windows/dsound.dll" \
    "$engine/lib/wine/x86_64-windows/winebus.sys" \
    "$renderer" 2>/dev/null | tr '\n' ';')
  if [ -x "$persist/lib/wine/x86_64-unix/wine" ] &&
     [ "$(cat "$persist/.sil-stamp" 2>/dev/null)" = "$sig" ]; then
    printf '%s' "$mp_stat" > "$persist/.sil-mp-stat" 2>/dev/null || true
    t5mp_engine=$persist
    return 0
  fi
  new="$persist.new"
  rm -rf "$new"
  mkdir -p "$new/lib" || return 1
  for entry in "$engine"/*; do
    [ "${entry##*/}" = lib ] || ln -s "$entry" "$new/" || { rm -rf "$new"; return 1; }
  done
  for entry in "$engine/lib"/*; do
    [ "${entry##*/}" = wine ] || ln -s "$entry" "$new/lib/" || { rm -rf "$new"; return 1; }
  done
  if cp -cRp "$engine/lib/wine" "$new/lib/wine" &&
     cp "$renderer" "$new/lib/wine/i386-windows/d3d9.dll" &&
     printf '%s' "$sig" > "$new/.sil-stamp" &&
     printf '%s' "$mp_stat" > "$new/.sil-mp-stat" &&
     { rm -rf "$persist" && mv "$new" "$persist"; }; then
    t5mp_engine=$persist
    return 0
  fi
  rm -rf "$new"
  return 1
}

cleanup_t5mp_engine() {
  # Persistent clone is intentionally kept warm across launches.
  t5mp_engine=
}

if [ "$mtld3d_active" = 1 ]; then
  if ! prepare_mtld3d_engine; then
    mtld3d_active=0
    mtld3d_engine=
    clear_env MTLD3D_CONFIG
    clear_env RUST_LOG
  fi
fi

if [ "$t" = t5 ]; then
  # (cleared for every other Black Ops start too: Zombies and the campaign
  # kept an online Multiplayer start's value in the prefix)
  if [ "$mtld3d_active" = 0 ] && [ "$mode" = mp ] && [ "${4:-}" != --lan ] &&
     on BO1_MP_FAST_LOAD && on BO1_WARM && on BO1_ASYNC &&
     prepare_t5mp_engine; then
    set_env DXVK_T5MP_WARM 1
    trap cleanup_t5mp_engine EXIT
  else
    cleanup_t5mp_engine
    clear_env DXVK_T5MP_WARM
  fi
fi

if [ "$t" = t5 ]; then
  players="$plutonium/storage/t5/players"
  # The shipped list was collected in Zombies. Keep BO1 SP/ZM in its own cache
  # (migrating any previously learned entries from the legacy shared cache once).
  # MP learns its own pipelines in cache/bo1-mp as maps load.
  if [ "$mtld3d_active" = 0 ] && [ "$mode" != mp ] && on BO1_SHADER_CACHE; then
    merge_statecache "$bo1_cache/plutonium-bootstrapper-win32.dxvk-cache" \
      "$kit/payload/bo1/pipelines.dxvk-cache" \
      "$home/cache/plutonium-bootstrapper-win32.dxvk-cache" \
      "$dir/plutonium-bootstrapper-win32.dxvk-cache" "$dir"/*/cache/plutonium-bootstrapper-win32.dxvk-cache
  fi
  mkdir -p "$players"
  for c in config.cfg config_mp.cfg; do
    [ -f "$players/$c" ] || printf 'seta %s "%s"\n' com_first_time_pc 0 com_recommendedSet 1 sm_enable 0 \
      r_blur_allowed 0 r_distortion 0 com_maxfps 0 r_fullscreen 1 > "$players/$c"
    defaults_once "$players/$c" "$players/.sil-defaults-$c" r_fullscreen 1 r_mode "${desktop:-1920x1080}" \
      r_vsync 1 r_picmip_manual 0 r_texFilterAnisoMax 16 r_aaSamples 4 r_aspectRatio auto \
      r_dof_enable 1 r_glow_allowed 1 r_shaderWarming 1
    common_cvars "$players/$c"
    [ -n "${hz:-}" ] && set_or_add "$players/$c" r_displayRefresh "$hz Hz"
    on BO1_NO_SHADOWS && set_cvar "$players/$c" sm_enable 0   # shadows froze BO1
    # Under mtld3d, native async shader compilation compiles only the ~300
    # shaders actually drawn instead of BO1's 5,838-shader warming pass (>50 s).
    if [ "$mtld3d_active" = 1 ]; then
      set_or_add "$players/$c" r_shaderWarming 0
    elif [ "$mode:$c" = mp:config_mp.cfg ] && on BO1_MP_FAST_LOAD && [ -z "$t5mp_engine" ]; then
      set_or_add "$players/$c" r_shaderWarming 0
    elif on BO1_WARM; then
      set_or_add "$players/$c" r_shaderWarming 1
    else
      set_or_add "$players/$c" r_shaderWarming 0
    fi
    if [ "${STREAM:-0}" = 1 ]; then sed -i '' '/^seta r_stream "/d' "$players/$c"
    else set_or_add "$players/$c" r_stream 0; fi
    # Avoid Vulkan FIFO + DXVK maxFrameRate double-throttling on high-refresh
    # displays (same as Steam BO1; macOS WindowServer still composites tear-free).
    # BO1_VSYNC=1 keeps the profile's in-game VSync setting.
    if [ "$maxfps" != 0 ] && [ "${BO1_VSYNC:-0}" != 1 ]; then set_or_add "$players/$c" r_vsync 0; fi
    set_or_add "$players/$c" com_maxfps 0
  done
  gamecfg="$players/config.cfg"; [ "$mode" = mp ] && gamecfg="$players/config_mp.cfg"
  # DXVK reads dxvk.conf from the working directory
  dxvk="d3d9.numBackBuffers = 3"$'\n'"dxvk.numCompilerThreads = $dxvk_threads"$'\n'"dxvk.numAsyncThreads = $dxvk_threads"$'\n'
  [ "$maxfps" != 0 ] && dxvk+="d3d9.maxFrameRate = $maxfps"$'\n'
  for d in "$dir" "$plutonium" "$plutonium/bin"; do [ -d "$d" ] && printf '%s' "$dxvk" > "$d/dxvk.conf"; done
  # XAudio2 2.7 from BO1's redist: Wine's leaves BO1's gunfire silent. A BO1
  # folder copied without its redist: the same cab from Black Ops II's folder
  # or from Black Ops / Black Ops II in Siliconium's Steam Library (as for BO2)
  xa="$WINEPREFIX/xaudio2_7.native.dll"
  steam_common="$home/prefix-steam/drive_c/Program Files (x86)/Steam/steamapps/common"
  xa_cabs=("$dir" ${BO2_DIR:+"$BO2_DIR"} "$steam_common/Call of Duty Black Ops" "$steam_common/Call of Duty Black Ops II")
  for cab in "${xa_cabs[@]/%//redist/DirectX/Jun2010_XAudio_x86.cab}"; do
    [ ! -f "$xa" ] && [ -f "$cab" ] || continue
    tmp=$(mktemp -d)
    bsdtar -xf "$cab" -C "$tmp" XAudio2_7.dll 2>/dev/null && cp "$tmp/XAudio2_7.dll" "$xa"
    rm -rf "$tmp"
  done
  if ! on BO1_XAUDIO; then
    reg delete "$bootstrapper\\DllOverrides" /v xaudio2_7 /f
  elif [ -f "$xa" ]; then
    cmp -s "$xa" "$WINEPREFIX/drive_c/windows/syswow64/xaudio2_7.dll" || cp "$xa" "$WINEPREFIX/drive_c/windows/syswow64/xaudio2_7.dll"
    reg add "$bootstrapper\\DllOverrides" /v xaudio2_7 /d native /f
  fi
elif [ "$t" = t4 ]; then
  # World at War: Direct3D 9 like Black Ops, so the same DXVK setup (background
  # pipeline compilation, persistent caches, the x87 accelerator); the game's
  # defaults like BO1's: fullscreen at the display's resolution with sync,
  # full textures, 16x anisotropy, 4x anti-aliasing (what Apple GPUs support)
  players="$plutonium/storage/t4/players"
  # WaW keeps its settings per profile (players/profiles/<name>/config.cfg;
  # "$$$" is the one Plutonium uses offline): set up every profile, and the
  # offline one before the game creates it with windowed 1024x768
  mkdir -p "$players/profiles/\$\$\$"
  offline="$players/profiles/\$\$\$"
  # DXVK compiles every pipeline in its state cache as the map's shaders are
  # registered, so fold in the list gathered on WaW's maps into WaW's own
  # isolated cache (without Black Ops' 22k pipelines).
  [ "$mtld3d_active" = 0 ] && on WAW_PIPELINES && merge_statecache \
    "$t4_cache/plutonium-bootstrapper-win32.dxvk-cache" \
    "$kit/payload/waw/pipelines.dxvk-cache" \
    "$dir/plutonium-bootstrapper-win32.dxvk-cache"
  for f in "$players"/config.cfg "$players"/config_mp.cfg "$offline/config.cfg" "$offline/config_mp.cfg" \
           "$players"/profiles/*/config.cfg "$players"/profiles/*/config_mp.cfg; do
    case "$f" in *'*'*) continue ;; esac
    defaults_once "$f" "$(dirname "$f")/.sil-defaults-$(basename "$f")" r_fullscreen 1 r_mode "${desktop:-1920x1080}" \
      r_vsync 1 r_picmip_manual 0 r_texFilterAnisoMax 16 r_aaSamples 4 r_aspectRatio auto \
      com_recommendedSet 1
    common_cvars "$f"
    # WaW's "Set Optimal Settings?" detection is what left the first profile at
    # the panel's 3840x2160 (not the desktop's 1920x1080), vsync off, 4x
    # anisotropy and an 85 FPS cap, rewriting the settings this script writes:
    # com_recommendedSet=1 says it has already been done. Fit the display
    # every launch too (a profile can still be left at 960x600 in fullscreen);
    # the game's own options rule for everything else.
    on WAW_SCREEN && set_or_add "$f" com_recommendedSet 1
    if on WAW_SCREEN && [ -n "$desktop" ] && grep -q '^seta r_fullscreen "1"' "$f"; then
      set_or_add "$f" r_mode "$desktop"
      set_or_add "$f" r_aspectRatio auto
    fi
    [ -n "${hz:-}" ] && set_or_add "$f" r_displayRefresh "$hz Hz"
    # A profile WaW has just created has no com_maxfps line: set_or_add, not
    # set_cvar, or the game's own cap (85 FPS here) stays.
    set_or_add "$f" com_maxfps 0
    # Avoid Vulkan FIFO + DXVK maxFrameRate double-throttling (WAW_VSYNC=1 keeps VSync).
    if [ "$maxfps" != 0 ] && [ "${WAW_VSYNC:-0}" != 1 ]; then set_or_add "$f" r_vsync 0; fi
    # Allow CPU/GPU frame overlap under mtld3d (eliminates sawtooth frame pacing).
    [ "$mtld3d_active" = 1 ] && set_or_add "$f" r_multiGpu 1
    # Draw every material while the map loads. Under both DXVK_ASYNC=2 and mtld3d
    # (WaW only has ~400 shaders/map), warming on load prevents mid-game shader spikes.
    if on WAW_WARM; then set_or_add "$f" r_shaderWarming 1; else set_or_add "$f" r_shaderWarming 0; fi
  done
  gamecfg="$players/profiles/\$\$\$/config.cfg"; [ "$mode" = mp ] && gamecfg="$players/profiles/\$\$\$/config_mp.cfg"
  dxvk="d3d9.numBackBuffers = 3"$'\n'"dxvk.numCompilerThreads = $dxvk_threads"$'\n'"dxvk.numAsyncThreads = $dxvk_threads"$'\n'
  [ "$maxfps" != 0 ] && dxvk+="d3d9.maxFrameRate = $maxfps"$'\n'
  for d in "$dir" "$plutonium" "$plutonium/bin"; do [ -d "$d" ] && printf '%s' "$dxvk" > "$d/dxvk.conf"; done
  # World at War's audio is XAudio2 2.0, and Wine's builtin xaudio2_0 (FAudio)
  # leaves the game's streamed music/2D sounds silent here (the round-change
  # music, the power-up jingles, the Mystery Box). WaW ships its own native
  # XAudio2_0 in its redist, exactly as BO1 ships XAudio2_7 (see the t5 block);
  # use it for T4 only, since the bootstrapper key is shared with the others.
  xa0="$WINEPREFIX/xaudio2_0.native.dll"
  if on WAW_XAUDIO && [ ! -f "$xa0" ] && [ -f "$dir/redist/DirectX/Mar2008_XAudio_x86.cab" ]; then
    tmp=$(mktemp -d)
    bsdtar -xf "$dir/redist/DirectX/Mar2008_XAudio_x86.cab" -C "$tmp" XAudio2_0.dll 2>/dev/null &&
      cp "$tmp/XAudio2_0.dll" "$xa0"
    rm -rf "$tmp"
  fi
  if on WAW_XAUDIO && [ -f "$xa0" ]; then
    cmp -s "$xa0" "$WINEPREFIX/drive_c/windows/syswow64/xaudio2_0.dll" ||
      cp "$xa0" "$WINEPREFIX/drive_c/windows/syswow64/xaudio2_0.dll"
    reg add "$bootstrapper\\DllOverrides" /v xaudio2_0 /d native /f
  else
    reg delete "$bootstrapper\\DllOverrides" /v xaudio2_0 /f
  fi
elif [ "$t" = iw5 ]; then
  # Modern Warfare 3: Direct3D 9 (DXVK), like Black Ops. Fullscreen at the
  # display's used size with sync, 2x anti-aliasing, 16x anisotropy and full
  # textures on the first start (IW5_GRAPHICS); native pixels were too heavy on
  # an M1 Pro. Afterwards the game's own options rule.
  players="$plutonium/storage/iw5/players"
  mkdir -p "$players"
  cfg="$players/config_mp.cfg"
  if on IW5_GRAPHICS; then
    defaults_once "$cfg" "$players/.sil-defaults-config_mp.cfg" \
      r_displayMode "fullscreen" r_mode "${desktop:-1920x1080}" r_vsync 1 \
      r_aaSamples 2 r_picmip_manual 0 r_texFilterAnisoMax 16
  fi
  [ -f "$cfg" ] || : > "$cfg"
  # The game's shader preload (r_preloadShaders): every material of a map is
  # drawn once on its loading screen, so nothing compiles as play begins, as
  # Black Ops' and World at War's shader warming. Off, a never-loaded map froze
  # for 274 ms as play began (mp_bootleg, 2026-11-23); on, its loading screen
  # took ~6 s longer (2-6 FPS while compiling) and play began at 147 FPS with
  # no frame over 50 ms (mp_carbon). The compiled pipelines stay in the DXVK
  # state cache, so later loads are quick; the very first start also preloads
  # the menu's (a longer first start). IW5_PRELOAD=0: off.
  if [ "$mtld3d_active" = 1 ]; then set_or_add "$cfg" r_preloadShaders 0
  elif on IW5_PRELOAD; then set_or_add "$cfg" r_preloadShaders 1
  else set_or_add "$cfg" r_preloadShaders 0; fi
  # No "Set Optimal Settings?" question at start-up (it waits for a click
  # before the game window opens, and would replace the settings above).
  set_or_add "$cfg" com_recommendedSet 1
  # Straight to the menu: no intro movie (Plutonium's plutonium.bik). Bink
  # decodes on one CPU thread under Rosetta (85-95 % busy, GPU idle) and only
  # reached ~27 of its 30 FPS, so the movie skipped frames.
  if on SKIP_INTRO; then set_or_add "$cfg" intro 0; else set_or_add "$cfg" intro 1; fi
  # Real fullscreen: a borderless window becomes real fullscreen (no display
  # capture: see the Wine settings). A windowed mode the player picked is left alone.
  on CAPTURE_DISPLAY && sed -i '' -E 's/^seta r_displayMode "windowed \(no border\)"/seta r_displayMode "fullscreen"/' "$cfg"
  # Let DXVK's d3d9.maxFrameRate handle sub-ms frame pacing cleanly without
  # fighting the engine's integer-ms com_maxfps (matching BO1, WaW, IW4X, BO2).
  if [ "$maxfps" != 0 ]; then set_or_add "$cfg" com_maxfps 0
  else set_or_add "$cfg" com_maxfps 0; fi
  # Avoid Vulkan FIFO + DXVK maxFrameRate double-throttling (IW5_VSYNC=1 keeps VSync).
  if [ "$maxfps" != 0 ] && [ "${IW5_VSYNC:-0}" != 1 ]; then set_or_add "$cfg" r_vsync 0; fi
  # Apple GPUs support 4x MSAA at most
  on MSAA_FIX && sed -i '' -E 's/^seta r_aaSamples "(8|16|32)"/seta r_aaSamples "4"/' "$cfg"
  gamecfg="$cfg"
elif [ "$t" = iw4 ]; then
  # Modern Warfare 2 (IW4X): Direct3D 9 (DXVK), like Black Ops. Fullscreen at
  # the display's size with sync, 4x anti-aliasing (what Apple GPUs support),
  # 16x anisotropy and full textures on the first start (IW4_GRAPHICS);
  # afterwards the game's own options rule.
  players="$dir/players"
  mkdir -p "$players"
  cfg="$players/iw4x_config.cfg"
  on IW4_GRAPHICS && defaults_once "$cfg" "$players/.sil-defaults-iw4x_config.cfg" \
    r_fullscreen 1 r_noborder 0 r_mode "${desktop:-1920x1080}" r_vsync 1 \
    r_aaSamples 4 r_picmip_manual 0 r_texFilterAnisoMax 16
  [ -f "$cfg" ] || : > "$cfg"
  # Use the D3D9Ex device path for IW4X under DXVK.
  on IW4_GRAPHICS && set_or_add "$cfg" r_useD3D9Ex 1
  if on IW4_MENU_CURSOR; then set_or_add "$cfg" ui_nativeCursor 1; else set_or_add "$cfg" ui_nativeCursor 0; fi
  # IW4X's own shader preload. Off: it made the menu wait on the first run
  # (every pipeline was compiled on the render thread). With DXVK_ASYNC=2 the
  # pipelines are queued instead, so it only warms the map while it loads.
  # IW4_PRELOAD=1 trades a slower first visit to a map for nothing appearing late.
  if [ "${IW4_PRELOAD:-0}" = 1 ]; then set_or_add "$cfg" r_preloadShaders 1; else set_or_add "$cfg" r_preloadShaders 0; fi
  [ -n "${hz:-}" ] && set_or_add "$cfg" r_displayRefresh "$hz Hz"
  set_or_add "$cfg" com_maxfps 0
  # Avoid Vulkan FIFO + DXVK maxFrameRate double-throttling (IW4_VSYNC=1 keeps VSync).
  if [ "$maxfps" != 0 ] && [ "${IW4_VSYNC:-0}" != 1 ]; then set_or_add "$cfg" r_vsync 0; fi
  # IW4X's "Set Optimal Settings?" question waits for a click before the game
  # window opens (it sat hidden behind other windows, so MW2 looked frozen)
  # and would rewrite the settings above: mark the detection as done.
  set_or_add "$cfg" com_recommendedSet 1
  # Fit the display every launch: IW4X's "Set Optimal Settings?" prompt can
  # leave it in a small 960x600 window; this keeps it at the user's screen.
  if on IW4_SCREEN && [ -n "$desktop" ]; then
    set_or_add "$cfg" r_mode "$desktop"
    set_or_add "$cfg" r_aspectRatio auto
  fi
  on MSAA_FIX && sed -i '' -E 's/^seta r_aaSamples "(8|16|32)"/seta r_aaSamples "4"/' "$cfg"
  gamecfg="$cfg"
else
  players="$plutonium/storage/t6/players"
  mkdir -p "$players"
  # an all-zero hardware profile makes BO2 detect a safe one (Apple GPUs stop at 4x MSAA)
  # BO2 keeps its display settings in a binary hardware profile (the cfg's
  # r_fullscreen/r_mode are overwritten from it). New profiles start from one
  # made on an Apple GPU: fullscreen 1920x1080, anti-aliasing Apple GPUs
  # support. Once per profile; the game re-detects if the hardware differs.
  if on BO2_HW_PROFILE; then
    for m in mp zm; do
      if [ ! -f "$players/.sil-defaults-hardware_$m" ]; then
        cp "$kit/payload/bo2/hardware.chp" "$players/hardware_$m.chp" && : > "$players/.sil-defaults-hardware_$m"
      fi
    done
  fi
  mouse_lag_fix=0
  if on BO2_MOUSE_LAG_FIX; then mouse_lag_fix=1; fi
  for c in plutonium_zm.cfg plutonium_mp.cfg; do
    defaults_once "$players/$c" "$players/.sil-defaults-$c" r_fullscreen 1 r_mode "${desktop:-1920x1080}" \
      r_vsync 1 r_monitor 0 r_picmip_manual 0 r_texFilterAnisoMax 16 r_aaSamples 1
    common_cvars "$players/$c"
    set_or_add "$players/$c" fix_mouse_lag "$mouse_lag_fix"
    set_or_add "$players/$c" com_maxfps 0
  done
  bo2_hw_screen "$players" "$players/plutonium_zm.cfg" "$players/hardware_zm.chp"
  bo2_hw_screen "$players" "$players/plutonium_mp.cfg" "$players/hardware_mp.chp"
  gamecfg="$players/plutonium_zm.cfg"; [ "$mode" = mp ] && gamecfg="$players/plutonium_mp.cfg"
  # Black Ops II creates XAudio2 2.7 like Black Ops (the same COM class), and
  # Wine's builtin left its gunfire and most weapon sounds silent on some Macs
  # (GitHub issue #2; not on every Mac). BO2's redist carries the same Microsoft XAudio2_7 as Black Ops'
  # (see the t5 block): use it for T6 only, the bootstrapper key is shared.
  # A BO2 folder copied without its redist: the same cab from Black Ops' folder
  # or from Black Ops / Black Ops II in Siliconium's Steam Library.
  xa="$WINEPREFIX/xaudio2_7.native.dll"
  steam_common="$home/prefix-steam/drive_c/Program Files (x86)/Steam/steamapps/common"
  xa_cabs=("$dir" ${BO1_DIR:+"$BO1_DIR"} "$steam_common/Call of Duty Black Ops II" "$steam_common/Call of Duty Black Ops")
  for cab in "${xa_cabs[@]/%//redist/DirectX/Jun2010_XAudio_x86.cab}"; do
    on BO2_XAUDIO && [ ! -f "$xa" ] && [ -f "$cab" ] || continue
    tmp=$(mktemp -d)
    bsdtar -xf "$cab" -C "$tmp" XAudio2_7.dll 2>/dev/null && cp "$tmp/XAudio2_7.dll" "$xa"
    rm -rf "$tmp"
  done
  if on BO2_XAUDIO && [ -f "$xa" ]; then
    cmp -s "$xa" "$WINEPREFIX/drive_c/windows/syswow64/xaudio2_7.dll" || cp "$xa" "$WINEPREFIX/drive_c/windows/syswow64/xaudio2_7.dll"
    reg add "$bootstrapper\\DllOverrides" /v xaudio2_7 /d native /f
  else
    reg delete "$bootstrapper\\DllOverrides" /v xaudio2_7 /f
  fi
fi

if [ "$t" = iw5 ]; then
  # Fullscreen at the desktop's own resolution, every start, as the other
  # games (common_cvars; IW5_SCREEN=0 keeps the profile's): only the first
  # start set it, so a desktop changed since (2560x1440 -> 1920x1080) kept the
  # old size, its 1x mode was held for the whole game and the refresh setting
  # below (which needs r_mode = the desktop's) was never corrected. (Here,
  # after a borderless profile has been made fullscreen above.)
  if on IW5_SCREEN && [ -n "$desktop" ] && grep -Fxq 'seta r_displayMode "fullscreen"' "$gamecfg" &&
     ! grep -Fxq "seta r_mode \"$desktop\"" "$gamecfg"; then
    set_or_add "$gamecfg" r_mode "$desktop"
  fi
  # With VSync, IW5's saved 60 Hz caps fullscreen at 60 FPS even when
  # com_maxfps and DXVK are set to 160. At the desktop's size its refresh
  # is already known to be available: the game asks for exactly the rate
  # the display runs at, every start, lower too (a 160 Hz saved from an
  # earlier display setting, with the display at 144 Hz, ran at 160 FPS
  # against a 144 Hz vsync, 2026-11-24). Leave other resolutions to the game.
  # (Both modes: online and LAN run the same game and profile.)
  if on DISPLAY_MODE && [[ ${hz:-} =~ ^[1-9][0-9]*$ ]] &&
     grep -Fxq 'seta r_displayMode "fullscreen"' "$gamecfg" &&
     grep -Fxq "seta r_mode \"$desktop\"" "$gamecfg"; then
    set_or_add "$gamecfg" r_displayRefresh "$hz Hz"
  fi
fi
if [ "$t" = iw5 ]; then
  # A 1x display mode of the resolution Modern Warfare 3 runs at, while it is
  # fullscreen (as for BO1/BO2), so a HiDPI desktop is not scaled every frame
  # (hold_1x_size). Both modes: the
  # multiplayer had none, and the other mode passed "1920x1080" as one
  # argument, which displaymode refused (it takes width and height), so it
  # never held either (found by a code audit, 2026-11-23).
  if on DISPLAY_MODE && grep -q '^seta r_displayMode "fullscreen"' "$gamecfg"; then
    hold_1x_size "$(sed -n -E 's/^seta r_mode "([0-9]+)x([0-9]+)"/\1 \2/p' "$gamecfg" | tail -1)"
  fi
else
  hold_1x "$gamecfg"
fi
if [ "$t" = iw4 ] && [ "$display_1x_unavailable" = 1 ]; then
  # Wine's fullscreen swap chain can stay black when the requested 1x mode
  # does not exist. Borderless keeps the current macOS display mode.
  set_or_add "$gamecfg" r_fullscreen 0
  set_or_add "$gamecfg" r_noborder 1
fi

# "Set Optimal Settings?" (asked when the game thinks the hardware changed,
# e.g. a profile from a Windows PC) runs configure[_mp].cfg on "Yes", which
# puts the game's guesses for an unknown GPU over the settings above (lower
# resolution, no anti-aliasing, a 60 Hz mode). A configure file of ours, in a
# folder the game searches first, does nothing: "Yes" then keeps the settings
# exactly as "No" does. The games only run it for that question.
# SETTINGS_GUARD=0 removes ours (a file someone else put there is never touched).
guard_configure() {   # guard_configure <file>
  local f=$1
  if [ -f "$f" ] && ! grep -qE '^// .* settings guard' "$f"; then return 0; fi
  if on SETTINGS_GUARD; then
    mkdir -p "$(dirname -- "$f")" &&
      printf '%s\r\n' '// Siliconium settings guard: "Set Optimal Settings?" keeps your settings.' > "$f"
  else
    rm -f -- "$f"
  fi
}
case "$t" in
  t4|t5) guard_configure "$plutonium/storage/$t/raw/configure.cfg"
         guard_configure "$plutonium/storage/$t/raw/configure_mp.cfg" ;;
  iw5)   guard_configure "$plutonium/storage/iw5/configure_mp.cfg" ;;
  iw4)   guard_configure "$dir/userraw/configure_mp.cfg"
         guard_configure "$dir/userraw/safemode_mp.cfg" ;;
esac

log="$home/logs/$game-$mode.log"
reg_flush
if [ -n "$mtld3d_engine" ]; then
  [ "${prewarm_active:-0}" = 0 ] && [ "$reg_disk_synced" = 0 ] && { "$WINESERVER" -w 2>/dev/null; reg_disk_synced=1; }
  export CX_ROOT="$mtld3d_engine"
  export WINEDLLPATH="$mtld3d_engine/lib/wine/x86_64-windows:$mtld3d_engine/lib/wine/i386-windows:$mtld3d_engine/lib/wine/x86_64-unix"
  export WINEDLLOVERRIDES="${WINEDLLOVERRIDES};d3d9=b"
  use_wine "$mtld3d_engine/lib/wine/x86_64-unix/wine"   # (its own Game Mode bundle)
  if [ "$t" != iw4 ]; then
    if [ ! -f "$dxvk_cache/mtld3d_shaders.bin" ]; then
      plut_mtld3d_seeds=()
      case "$t" in
        t4)  plut_mtld3d_seeds=("$home/cache/steam-waw/sp-mtld3d_shaders.bin" "$home/cache/steam-waw/mp-mtld3d_shaders.bin") ;;
        t5)  plut_mtld3d_seeds=("$home/cache/bo1/mtld3d_shaders.bin" "$home/cache/steam-bo1/sp-mtld3d_shaders.bin" "$home/cache/steam-bo1/mp-mtld3d_shaders.bin") ;;
        iw5) plut_mtld3d_seeds=("$home/cache/own-mw3/sp-mtld3d_shaders.bin" "$home/cache/steam-mw3/mp-mtld3d_shaders.bin") ;;
      esac
      for plut_seed in "${plut_mtld3d_seeds[@]}"; do
        if [ "$plut_seed" != "$dxvk_cache/mtld3d_shaders.bin" ] && [ -s "$plut_seed" ]; then
          mkdir -p "$dxvk_cache" && cp -f "$plut_seed" "$dxvk_cache/mtld3d_shaders.bin" && break
        fi
      done
    fi
    mtld3d_stage_cache "$dxvk_cache/mtld3d_shaders.bin"
  fi
elif [ -n "$t5mp_engine" ]; then
  [ "${prewarm_active:-0}" = 0 ] && [ "$reg_disk_synced" = 0 ] && { "$WINESERVER" -w 2>/dev/null; reg_disk_synced=1; }
  export CX_ROOT="$t5mp_engine"
  export WINEDLLPATH="$t5mp_engine/lib/wine/x86_64-windows:$t5mp_engine/lib/wine/x86_64-unix"
  use_wine "$t5mp_engine/lib/wine/x86_64-unix/wine"   # (its own Game Mode bundle)
fi
if [ "$t" = iw4 ]; then
  cd "$dir" || exit 1
  # Same "did not quit properly / run in safe mode?" marker as Ghosts (IW4's
  # __<exe> files), left by a game stopped from the app or a crash.
  rm -f -- __iw4x __iw4mp __iw4x-sp __iw4sp
  iw4_args=(--arch x86 --no-shortcuts --game-args -stdout --game-args -nointro)
  # GAME_ARGS (e.g. "+devmap mp_rust") are handed to the game too
  # shellcheck disable=SC2206
  for a in ${GAME_ARGS:-}; do iw4_args+=(--game-args "$a"); done
  # IW4X's launcher updates itself and the game, then starts the 32-bit
  # client (--arch x86: our patched D3D9 and x87 paths). Without a network it
  # fails: then the installed client starts directly.
  : > "$log"
  iw4_first=0
  if [ ! -f iw4x.exe ] || [ ! -d iw4x ]; then
    iw4_first=1
    printf '==> %s\n' "Setting up IW4X (first start downloads ~3 GB of maps and assets, please wait)…"
  else
    printf '==> %s\n' "Starting IW4X (checking for updates)…"
  fi
  focus_helper iw4x.exe   # (the launcher starts the client)
  declare -F sil_iw4x_watch_log >/dev/null || . "$kit/tools/iw4x.sh"
  iw4_prev_exit=$(trap -p EXIT | sed -E "s/^trap -- '(.*)' EXIT$/\1/")
  trap "sil_iw4x_stop_watch${iw4_prev_exit:+; $iw4_prev_exit}" EXIT
  if [ -f iw4x-launcher.exe ]; then
    sil_iw4x_watch_log "$log" 1 "$iw4_first"
  fi
  if [ -f iw4x-launcher.exe ] && "$wine" iw4x-launcher.exe "${iw4_args[@]}" --no-connect-protocol >> "$log" 2>&1; then
    sil_iw4x_stop_watch
    printf '==> %s\n' "Starting IW4X…"
  elif [ -f iw4x.exe ]; then
    sil_iw4x_stop_watch
    printf '==> %s\n' "Starting IW4X…"
    printf '\nStarting the installed IW4X client directly.\n' >> "$log"
    # shellcheck disable=SC2086
    if [ "${prewarm_active:-0}" = 1 ]; then
      "$wine" iw4x.exe -stdout -nointro ${GAME_ARGS:-} >> "$log" 2>&1
    else
      exec "$wine" iw4x.exe -stdout -nointro ${GAME_ARGS:-} >> "$log" 2>&1
    fi
  else
    sil_iw4x_stop_watch
    die "The IW4X launcher failed (see logs/$game-$mode.log)."
  fi
  wait_wine_exit 'iw4x(-launcher)?\.exe' 1
  exit
fi
case "$t:$mode" in
  t4:zombies|t4:campaign) pmode=t4sp ;; t4:mp) pmode=t4mp ;;
  t5:zombies|t5:campaign) pmode=t5sp ;; t5:mp) pmode=t5mp ;;
  t6:zombies) pmode=t6zm ;; t6:mp) pmode=t6mp ;;
  iw5:mp) pmode=iw5mp ;;
  *:online) pmode="${t}mp" ;;
  t6:declassified) pmode=t6zm
    [ -f "$plutonium/storage/t6/mods/dlc5/mod.ff" ] || [ -d "$plutonium/storage/t6/mods/dlc5" ] || die "Zombies Declassified is not installed"
    GAME_ARGS="+set fs_game mods/dlc5 ${GAME_ARGS:-}" ;;
esac
# (Plutonium's launcher starts the bootstrapper, which runs the game)
: > "$log"
printf '==> %s\n' "Starting Plutonium…"
focus_helper plutonium-bootstrapper-win32.exe
if [ "${4:-}" != --lan ] && [ "$mode" != declassified ]; then
  launcher="$plutonium/bin/plutonium-launcher-win32.exe"
  [ -f "$launcher" ] || die "Plutonium is not installed in the prefix. Run Install first."
  cd "$plutonium/bin" || exit 1
  if [ "$mode" = online ]; then
    # Opening the launcher also lets the user sign in again if its session expired.
    /usr/bin/python3 -I "$kit/tools/plutonium-config.py" link "$plutonium_cfg" "$t" "$winpath" "$pmode" || true
    exec "$wine" "$launcher" >> "$log" 2>&1
  fi
  /usr/bin/python3 -I "$kit/tools/plutonium-config.py" link "$plutonium_cfg" "$t" "$winpath" ||
    die "Could not load your Plutonium setup. Open Plutonium to sign in again, or run Install."
  # The launcher's URI skips game selection and hands an online session to
  # the bootstrapper. Keep the Wine configuration and patches set above.
  # Stream download speed & ETA if Plutonium downloads first-time game assets
  # or a client update before starting the bootstrapper.
  pl_watch_pid=
  pl_stop_watch() { [ -n "${pl_watch_pid:-}" ] && { kill "$pl_watch_pid" 2>/dev/null; wait "$pl_watch_pid" 2>/dev/null; pl_watch_pid=; } || true; }
  pl_first=0; [ -d "$plutonium/storage/$t" ] || pl_first=1
  pl_kb0=$(du -sk "$plutonium" 2>/dev/null | awk '{print $1}'); pl_kb0=${pl_kb0:-0}
  pl_prev_exit=$(trap -p EXIT | sed -E "s/^trap -- '(.*)' EXIT$/\1/")
  trap "pl_stop_watch${pl_prev_exit:+; $pl_prev_exit}" EXIT
  (
    p_t0="" p_last_kb=$pl_kb0 p_last_msg=""
    while sleep 1.5; do
      sil_wine_running 'plutonium-bootstrapper-win32\.exe' && break
      p_kb=$(du -sk "$plutonium" 2>/dev/null | awk '{print $1}'); p_kb=${p_kb:-0}
      if [ "$p_kb" -gt "$p_last_kb" ]; then
        p_dkb=$((p_kb - pl_kb0))
        if [ "$p_dkb" -gt 256 ]; then
          p_now=$(date +%s)
          [ -z "$p_t0" ] && p_t0=$p_now
          p_mb=$((p_dkb / 1024)); [ "$p_mb" -lt 1 ] && p_mb=1
          p_dt=$((p_now - p_t0))
          p_extra=""
          if [ "$p_dt" -ge 2 ]; then
            p_spd=$(awk -v d="$p_dkb" -v t="$p_dt" 'BEGIN { printf "%.1f MB/s", (d / 1024.0) / t }')
            if [ "$pl_first" = 1 ] && [ "$p_dkb" -lt 81920 ]; then
              p_rem=$(( (81920 - p_dkb) * p_dt / p_dkb ))
              p_extra=" ($p_spd · $(sil_fmt_eta "$p_rem"))"
            else
              p_extra=" ($p_spd)"
            fi
          fi
          p_msg="Updating Plutonium: ${p_mb} MB${p_extra}…"
          if [ "$p_msg" != "$p_last_msg" ]; then
            printf '==> %s\n' "$p_msg"
            p_last_msg=$p_msg
          fi
        fi
        p_last_kb=$p_kb
      fi
    done
  ) &
  pl_watch_pid=$!
  "$wine" "$launcher" "plutonium://play/$pmode" >> "$log" 2>&1 || {
    pl_stop_watch
    die "Plutonium could not start $pmode (see logs/$game-$mode.log). Open Plutonium to check your session."
  }
  pl_stop_watch
  wait_wine_exit 'plutonium-bootstrapper-win32\.exe|plutonium-launcher-win32\.exe' 1
  exit
fi
extra=${GAME_ARGS:-}
[ "$t" = t6 ] && extra="${BO2_MODS:-} $extra"
cd "$plutonium" || exit 1
# shellcheck disable=SC2086
if [ "$t" = iw5 ]; then
  on SKIP_INTRO && extra="+set intro 0 $extra"
  if [ -n "$mtld3d_cache_file" ] || [ "${prewarm_active:-0}" = 1 ]; then
    "$wine" bin/plutonium-bootstrapper-win32.exe "$pmode" "$winpath" +set name "${3:-Player}" -lan $extra >> "$log" 2>&1
    wait_wine_exit 'plutonium-bootstrapper-win32\.exe' 0
    exit
  fi
  exec "$wine" bin/plutonium-bootstrapper-win32.exe "$pmode" "$winpath" +set name "${3:-Player}" -lan $extra >> "$log" 2>&1
fi
# shellcheck disable=SC2086
if [ -n "$mtld3d_cache_file" ] || [ "${prewarm_active:-0}" = 1 ]; then
  "$wine" bin/plutonium-bootstrapper-win32.exe "$pmode" "$winpath" +name "${3:-Player}" -lan $extra >> "$log" 2>&1
  wait_wine_exit 'plutonium-bootstrapper-win32\.exe' 0
  exit
fi
exec "$wine" bin/plutonium-bootstrapper-win32.exe "$pmode" "$winpath" +name "${3:-Player}" -lan $extra >> "$log" 2>&1
