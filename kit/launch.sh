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
#   CAPTURE_DISPLAY=0  fullscreen through the window compositor
#   DISPLAY_MODE=0     keep the desktop's display mode while in fullscreen
#   MSAA_FIX=0         allow the games' 8x+ MSAA (not supported by Apple GPUs)
#   BO1_ASYNC=0        BO1 shaders compile while drawing (stutters)
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
#   IW5_METAL_PARALLEL=0  Metal compiles a few shaders at a time
#   IW4_GRAPHICS=0     Modern Warfare 2 keeps its own first-start video defaults
#   IW4_SCREEN=0       MW2 keeps the resolution set in the game
#   IW4_PRELOAD=1      MW2 preloads a map's shaders while it loads: the first
#                      visit takes longer to load and nothing appears late
#   IW6_TUNE=0         Ghosts keeps its own tessellation/motion blur and may
#                      load NVIDIA's HBAO+/TXAA/APEX libraries
#   CURSOR_FIX=0       on macOS 26+, keep the transparent-cursor fix (a fast
#                      mouse no longer lowers the frame rate) to Black Ops II
#   SKIP_INTRO=0       play the logo movies when WaW, BO1 and BO2 start
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
if [ "${1:-}" = bo2c ] || [ "${1:-}" = bo2s ] || [ "${1:-}" = steam ] || [ "${1:-}" = cod4x ] || [ "${1:-}" = iw7mod ]; then
  # bo2s and the Steam Library (steam): Steam for Windows in its own prefix
  # (steam.sh), which starts the game. CoD4X (cod4x): the same prefix and
  # Steam's Call of Duty 4 multiplayer setup, without Steam; IW7-Mod (iw7mod):
  # the same with Steam's Infinite Warfare setup
  if [ "${1:-}" = bo2c ]; then export WINEPREFIX="$home/prefix-bo2c"; else export WINEPREFIX="$home/prefix-steam"; fi
  # its Wine server runs through a link outside the engine folder, so the app
  # doesn't count the campaign's prefix as a game running
  mkdir -p "$home/campaign"; ln -sfn "$engine/bin/wineserver" "$home/campaign/wineserver"
  export WINESERVER="$home/campaign/wineserver"
elif [ "${1:-}" = iw6 ]; then
  export WINEPREFIX="$home/prefix-iw6"
fi
export WINEDLLPATH="$engine/lib/wine/x86_64-windows:$engine/lib/wine/x86_64-unix"
export WINEMSYNC=1 WINEDEBUG=${WINEDEBUG:--all} WINEDLLOVERRIDES="mscoree,mshtml="
wine="$engine/lib/wine/x86_64-unix/wine"
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
# A community client's copy of a Steam game (CoD4X, IW7-Mod: tools/steam-copy.sh):
# Steam's files leave it a minute after this start ends, however it ends (the
# game quit, Stop, an error); a start in that minute keeps them
copy_release() {
  [ -n "${sil_copy_dir:-}" ] || return 0
  ( /bin/bash "$kit/tools/steam-copy.sh" release "$s_client" "$sil_copy_dir" "$sil_copy_gen" 60 > /dev/null 2>&1 & )
}
. "$kit/tools/winpath.sh"
stop_all() { "$WINESERVER" -k 2>/dev/null; "$WINESERVER" -w 2>/dev/null; }

game=${1:-}; mode=${2:-}
[ "$game:$mode" = stop:iw6 ] && { WINEPREFIX="$home/prefix-iw6" stop_all; exit 0; }
[ "$game" = stop ] && { stop_all; WINEPREFIX="$home/prefix-bo2c" "$WINESERVER" -k 2>/dev/null
  WINEPREFIX="$home/prefix-steam" "$WINESERVER" -k 2>/dev/null; exit 0; }
[ -x "$wine" ] || die "the engine is not installed"
# CoD4X or IW7-Mod without the Steam Library set up yet: Steam's prefix, without
# Steam (as steam.sh setup makes it; Steam for Windows can be added to it later)
if { [ "$game" = cod4x ] || [ "$game" = iw7mod ]; } && [ ! -f "$WINEPREFIX/system.reg" ]; then
  printf '==> %s\n' "Preparing Wine for $([ "$game" = cod4x ] && echo CoD4X || echo IW7-Mod)"
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
  waw:online|waw:zombies|waw:campaign|waw:mp) dir=${WAW_DIR:-} t=t4 ;;
  bo1:online|bo1:zombies|bo1:campaign|bo1:mp) dir=${BO1_DIR:-} t=t5 ;;
  bo2:online|bo2:zombies|bo2:mp|bo2:declassified) dir=${BO2_DIR:-} t=t6 ;;
  iw5:online|iw5:mp) dir=${IW5_DIR:-} t=iw5 ;;
  iw4:play|iw4:launcher) dir=${IW4_DIR:-} t=iw4 ;;
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
    sil_cod4x_prepare "${COD4X_DIR:-}" || die "$c4_error"
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
  *) die "usage: launch.sh waw|bo1|bo2|iw5 online|zombies|campaign|mp [name], launch.sh iw4 play|launcher, launch.sh iw6 play, launch.sh boiii play|launcher, launch.sh steam <game>-<sp|mp|zm>, launch.sh cod4x play, launch.sh iw7mod play, or launch.sh stop" ;;
esac
# (a client's copy was made above: Steam's files leave it after this start)
[ -n "${sil_copy_dir:-}" ] && trap copy_release EXIT
# The community fix the player chose for this Steam game, if any
# (tools/steam-mods.sh; none: nothing here changes). CoD4X is not one of them
if [ "$t" = steam ]; then
  . "$kit/tools/steam-mods.sh"
  [ -n "${s_client:-}" ] || steam_mod_prepare "$dir" || die "$m_error"
fi
if [ "$t" = t7 ]; then
  [ -n "$dir" ] && [ -d "$dir" ] || die "the Black Ops III (Windows) folder is not set"
  # boiii.exe (Ezz's client): downloaded here the first time, checked against
  # its published SHA-256; Ezz's launcher updates it afterwards
  if [ ! -f "$dir/boiii.exe" ]; then
    BOIII_DIR="$dir" bash "$kit/boiii.sh" download ||
      die "Could not download boiii.exe: check your internet connection and press Play again."
  fi
elif [ "$t" = t6 ] || [ "$t" = t6c ] || [ "$t" = t6s ] || [ "$t" = steam ]; then
  :   # BO2 keeps the desktop's mode (see the t6:mp note above); Steam's games were checked above
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
stop_all
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
if [ "$t" = t5 ] || [ "${s_id:-}" = bo1 ]; then   # Black Ops, Plutonium's or Steam's
  install_own_engine_module winecoreaudio.so 570a756b9f72d4e26769431ea419719cebfbd14c9f1c52ddcd8abd2b61510883 \
    fb6c9d52aefb1180e4c716c52f873929f91e6e0290a6955f23fe69cf7ab85c8d ||
    printf '%s\n' 'Warning: could not install the Black Ops audio update.' >&2
fi
# The cursor fix (see SIL_BO2_TRANSPARENT_CURSOR below): Black Ops II always;
# on macOS 26 and later every game, since there the stall it fixes (a fast
# mouse dropping the frame rate) is the system's, not BO2's. CURSOR_FIX=0
# keeps it to Black Ops II.
macos_major=$(sw_vers -productVersion 2>/dev/null); macos_major=${macos_major%%.*}
cursor_fix=0
case "$t" in
  t6|t6c|t6s) cursor_fix=1 ;;
  iw6) cursor_fix=1 ;;   # Ghosts turns it on itself; it needs the module too
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
if [ "$cursor_fix" = 1 ]; then
  # Accept the original and earlier cursor modules so existing engines can update.
  install_own_engine_module winemac.so \
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
    eb5eb337107f33cf3fe728e2abd6b3ee6b84bc000768ff0f9d790e045b00108e ||
    printf '%s\n' 'Warning: could not install the Black Ops II cursor update.' >&2
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
fullscreen_cfg() { [ "${CAPTURE_DISPLAY:-1}" != 0 ] && [ -f "$1" ] && sed -i '' 's/^seta r_fullscreen "2"/seta r_fullscreen "1"/' "$1"; return 0; }
hold_1x() { # <game cfg>
  fullscreen_cfg "$1"
  [ -f "$1" ] && grep -qE '^seta r_fullscreen "[12]"' "$1" || return 0
  hold_1x_size "$(sed -n -E 's/^seta r_mode "([0-9]+)x([0-9]+)"/\1 \2/p' "$1")"
}
hold_1x_size() { # "<width> <height>"
  [ -z "$held_1x" ] && [ "${DISPLAY_MODE:-1}" != 0 ] && [ -n "$1" ] || return 0
  local res=$1 log="$home/logs/displaymode.log" size i launch_pid=$$
  ( while kill -0 "$launch_pid" 2>/dev/null; do sleep 2; done
    sleep 3   # the launcher may close a moment before the game window is up
    while pgrep -qf 'plutonium-bootstrapper-win32\.exe|t6sp\.exe|iw4x(-launcher)?\.exe'; do sleep 2; done
  ) > /dev/null 2>&1 &
  stop_displaymode
  log_cap "$log"
  size=$(stat -f %z "$log" 2>/dev/null || echo 0)
  # shellcheck disable=SC2086
  "$kit/tools/displaymode" $res $! >> "$log" 2>&1 &
  held_1x=1
  for i in $(seq 25); do   # wait (up to 5 s) for the switch
    if [ "$(stat -f %z "$log" 2>/dev/null || echo 0)" != "$size" ]; then
      case "$(tail -n 1 "$log")" in
        "displaymode: no 1x "*|"displaymode: could not switch mode") display_1x_unavailable=1 ;;
      esac
      break
    fi
    sleep 0.2
  done
}
# Controller aim as on the consoles: turn acceleration, the console turn
# rates (260/90 degrees/s left-right/up-down, 90/55 aiming down sights) and
# aim assist (slowdown and lock-on over targets). Mouse aim is not affected.
console_aim() { # <game cfg>
  [ "${CONSOLE_AIM:-1}" != 0 ] && [ -f "$1" ] || return 0
  local v
  for v in aim_accel_turnrate_enabled=1 aim_accel_turnrate_lerp=1200 aim_input_graph_enabled=1 \
           aim_input_graph_index=3 aim_scale_view_axis=1 aim_turnrate_yaw=260 aim_turnrate_pitch=90 \
           aim_turnrate_yaw_ads=90 aim_turnrate_pitch_ads=55 aim_autoaim_enabled=1 \
           aim_lockon_enabled=1 aim_slowdown_enabled=1; do
    if grep -q "^seta ${v%%=*} " "$1"; then sed -i '' -E "s/^seta ${v%%=*} \"[^\"]*\"/seta ${v%%=*} \"${v#*=}\"/" "$1"
    else printf 'seta %s "%s"\n' "${v%%=*}" "${v#*=}" >> "$1"; fi
  done
}
# Patches and settings are on unless set to 0 (used before the display block).
on() { [ "${!1:-1}" != 0 ]; }
# The desktop's logical size and refresh rate. Read before the display block:
# hold_1x_size starts the body from there, and on a first run there is no game
# profile to read the size from.
read -r dw dh hz < <("$kit/tools/displaymode" current 2>/dev/null || true)
# Games held in a 1x mode of the desktop's size (see hold_1x) get that mode's
# refresh rate, which can be higher than the HiDPI desktop's: a 2560x1440
# panel scaled from 5120x2880 stops at 154 Hz, its 1x mode runs at 160 Hz.
# The frame-rate cap and the games' refresh settings follow it.
case "$t" in
  t4|t5|iw4|iw5|t7|steam)
    # Steam's Ghosts runs borderless on the desktop as Siliconium's own Ghosts
    # (t=iw6, not in this list): the desktop's rate, not the 1x mode's
    desktop_rate=0
    case "$t:${s_exe:-}" in steam:iw6sp64_ship.exe|steam:iw6mp64_ship.exe) desktop_rate=1 ;; esac
    if [ "$desktop_rate" = 0 ] && on DISPLAY_MODE && [ -n "${dw:-}" ] && [ -n "${dh:-}" ]; then
      best_hz=$("$kit/tools/displaymode" best "$dw" "$dh" 2>/dev/null)
      [[ ${best_hz:-} =~ ^[1-9][0-9]*$ ]] && [ "$best_hz" -gt "${hz:-0}" ] && hz=$best_hz
    fi ;;
esac
maxfps=${MAXFPS:-${hz:-0}}
# DXVK's shader compiler threads: one per performance core, at most 8 (what an
# M1 Pro/Max uses). On a 4-performance-core Mac (M1, M2, M3) 8 threads competed
# with the game's own threads on the efficiency cores and made hitches longer.
dxvk_threads=$(sysctl -n hw.perflevel0.logicalcpu 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 8)
[[ $dxvk_threads =~ ^[0-9]+$ ]] || dxvk_threads=8
[ "$dxvk_threads" -gt 8 ] && dxvk_threads=8
[ "$dxvk_threads" -lt 2 ] && dxvk_threads=2
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
  steam:*)
    case "$s_api:$s_kind" in
      gl:*|d3d9:*|d3d9x64:*|d3d11:t6|d3d11x64:s1|d3d11x64:t7|d3d11x64:iw7) [ -n "${dw:-}" ] && [ -n "${dh:-}" ] && hold_1x_size "$dw $dh" ;;
    esac ;;
  t5:mp) hold_1x "$plutonium/storage/t5/players/config_mp.cfg" ;;
  t5:*) hold_1x "$plutonium/storage/t5/players/config.cfg" ;;
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
iw4_env_snapshot=
if [ "$t" = iw4 ] && [ -r "$WINEPREFIX/user.reg" ]; then
  # stop_all has flushed Wine's registry. Avoid starting a reg.exe process
  # for every setting that already matches on repeated IW4X launches.
  iw4_env_snapshot=$(awk '/^\[Environment\]/{ in_env=1; print; next } /^\[/{ in_env=0 } in_env' "$WINEPREFIX/user.reg")
fi
# Registry changes are queued and written by one regedit run (reg_flush)
# before the next Wine program starts: one reg.exe per value took ~0.3 s
# each, about 12 s of every launch.
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
  local file line
  file=$(mktemp "$home/cache/sil-reg.XXXXXX") || return 0
  # Version 5 files are UTF-16 (a folder name can be any language)
  { printf '\xff\xfe'
    { printf 'Windows Registry Editor Version 5.00\r\n\r\n'
      for line in "${reg_pending[@]}"; do printf '%s\r\n' "$line"; done
    } | iconv -f UTF-8 -t UTF-16LE
  } > "$file"
  "$wine" regedit /S "$(sil_winpath "$file")" > /dev/null 2>&1 || true
  rm -f "$file"
  reg_pending=()
}
set_env() {
  export "$1=$2"
  if [ -n "$iw4_env_snapshot" ]; then
    local encoded=${2//\\/\\\\}
    encoded=${encoded//\"/\\\"}
    grep -Fxq "\"$1\"=\"$encoded\"" <<< "$iw4_env_snapshot" && return 0
  fi
  reg add 'HKCU\Environment' /v "$1" /d "$2" /f
}
clear_env() {
  unset "$1"
  if [ -n "$iw4_env_snapshot" ] && ! grep -Fiq "\"$1\"=" <<< "$iw4_env_snapshot"; then return 0; fi
  reg delete 'HKCU\Environment' /v "$1" /f
}
# Variables an install of the previous name left in the prefix's environment
legacy_env=$(printf 'B%sM_' O)
grep -oE "^\"(__CX_UNIX_)?${legacy_env}[A-Z0-9_]+\"=" "$WINEPREFIX/user.reg" 2>/dev/null | tr -d '"=' |
  while IFS= read -r v; do clear_env "$v"; done

# The D3D11 games share DXMT's shader and frame-pacing settings.
dxmt_config() {
  local settings=$1 cap=$2 config
  if on "${settings}_ASYNC"; then config="d3d11.asyncPipelineCompile=True;"
  else config="d3d11.asyncPipelineCompile=False;"; fi
  if [ "$cap" != 0 ] && on "${settings}_FRAME_PACING"; then
    config="d3d11.preferredMaxFrameRate=$cap;$config"
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
    staged=$(mktemp "$profile.XXXXXX") || die "Could not stage the Ghosts video settings."
    if awk -v once="$tune_once" '
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
          # textures at full resolution: on "automatic" (r_picmip_manual 0)
          # Ghosts sizes them for the video memory it detects, and picked low
          # ones on Apple GPUs
          n = split("r_mbEnable=0 r_mbEnableA=0 r_fur_shader=0 r_picmip_manual=1 r_picmip=0 r_picmip_bump=0 r_picmip_spec=0 r_picmip_water=0", a, " ")
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
  "$wine" reg add 'HKCU\Software\Wine\AppDefaults\iw6sp64_ship.exe\Mac Driver' \
    /v CaptureDisplaysForFullscreen /d n /f > "$log" 2>&1 ||
    die "Ghosts could not configure its Wine prefix (see logs/iw6-play.log)"
  "$WINESERVER" -w 2>/dev/null
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
  "$kit/payload/iw6/iw6-focus" "$game_pid" "$wine" "$kit/payload/iw6/iw6-restore.exe" >> "$log" 2>&1 &
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

if [ "${X87:-1}" = 1 ] && [ -x "$engine/bin/x87sidecar" ]; then
  set_env X87_SIDECAR_PATH "$engine/bin/x87sidecar"
  # Plutonium's games, the campaign's t6sp.exe (it crashed under an older
  # sidecar; with x87sidecar 1.9 it runs, and is CPU-bound without it),
  # Modern Warfare 3's iw5mp.exe and Modern Warfare 2's iw4x.exe
  if [ "$t" = steam ]; then set_env X87_SIDECAR_PROGRAMS "t6sp.exe:$steam_x87_programs"
  else set_env X87_SIDECAR_PROGRAMS plutonium-bootstrapper-win32.exe:t6sp.exe:iw5mp.exe:iw4x.exe:iw4x-sp.exe; fi
else
  # X87=0: Rosetta's own x87 emulation (exact, if slower)
  clear_env X87_SIDECAR_PATH; clear_env X87_SIDECAR_PROGRAMS
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
    # Steam Library: each game its own pipeline list and settings
    shader_settings=STEAM
    dxvk_config_dir="$dxvk_cache/steam-$s_id"
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
  # T5 goes back to 1 (the 0.8.1 behaviour): with 2, and a cold MoltenVK cache,
  # new in-game materials were drawn black until their pipeline finished (they
  # took minutes to compile on this fresh engine). 1 compiles a new in-game
  # pipeline on the render thread (a small hitch) and never draws it black;
  # T4 keeps 2 (there it only queues while the map loads).
  if on BO1_ASYNC; then
    if [ "$t" = t4 ]; then set_env DXVK_ASYNC 2; else set_env DXVK_ASYNC 1; fi
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
bo1_mp_cache="$home/cache/bo1-mp"
if [ "$t:$mode" = t5:mp ]; then
  mkdir -p "$bo1_mp_cache" || die "Could not create the Black Ops Multiplayer graphics cache directory."
  dxvk_cache="$bo1_mp_cache"
fi
set_env DXVK_STATE_CACHE_PATH "Z:${dxvk_cache//\//\\}"
# MoltenVK compiles Metal libraries while deserializing a pipeline cache.
# Keep IW4X, IW5 MP and BO1 MP from replaying other games' shaders.
iw4_mvk_cache="$home/cache/iw4/mvkcache.bin"
iw5_mvk_cache="$home/cache/iw5/mvkcache.bin"
bo1_mp_mvk_cache="$bo1_mp_cache/mvkcache.bin"
if [ "$t" = iw4 ]; then
  set_env MVKCACHE_FILE "${MVKCACHE_FILE:-$iw4_mvk_cache}"
elif [ "$t:$mode" = iw5:mp ]; then
  set_env MVKCACHE_FILE "${MVKCACHE_FILE:-$iw5_mvk_cache}"
elif [ "$t:$mode" = t5:mp ]; then
  set_env MVKCACHE_FILE "$bo1_mp_mvk_cache"
elif [ "$t" = steam ]; then
  # Black Ops Multiplayer keeps its own, as with Plutonium (bo1-mp)
  if [ "${s_exe:-}" = BlackOpsMP.exe ]; then mkdir -p "$home/cache/steam-$s_id/mp"; set_env MVKCACHE_FILE "${MVKCACHE_FILE:-$home/cache/steam-$s_id/mp/mvkcache.bin}"
  else set_env MVKCACHE_FILE "${MVKCACHE_FILE:-$home/cache/steam-$s_id/mvkcache.bin}"; fi
elif grep -Fxq -e "\"MVKCACHE_FILE\"=\"$iw4_mvk_cache\"" \
                -e "\"MVKCACHE_FILE\"=\"$iw5_mvk_cache\"" \
                -e "\"MVKCACHE_FILE\"=\"$bo1_mp_mvk_cache\"" "$WINEPREFIX/user.reg" 2>/dev/null; then
  reg delete 'HKCU\Environment' /v MVKCACHE_FILE /f
fi
set_env DXMT_CONFIG "$(dxmt_config BO2 "$maxfps")"
if [ "$t" = steam ] && [ "$s_kind" = iw6 ]; then
  steam_ids=; on IW6_GPU_ID && steam_ids="dxgi.customVendorId=1002;dxgi.customDeviceId=67df;"
  set_env DXMT_CONFIG "$steam_ids$(dxmt_config IW6 "$maxfps")"
fi
# Advanced Warfare: DXMT's defaults (async pipelines, pacing at the refresh
# rate) without Ghosts' AMD GPU id; AW_ASYNC / AW_FRAME_PACING=0 turn them off
[ "$t" = steam ] && [ "${s_kind:-}" = s1 ] && set_env DXMT_CONFIG "$(dxmt_config AW "$maxfps")"
# Infinite Warfare: the same defaults under its own switches (IW7_ASYNC /
# IW7_FRAME_PACING=0), no GPU id change (it reads the Apple GPU as is)
[ "$t" = steam ] && [ "${s_kind:-}" = iw7 ] && set_env DXMT_CONFIG "$(dxmt_config IW7 "$maxfps")"
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
# Advanced Warfare with its own shader translator (AW_DXMT_FIX, when one is in the kit: see the Steam
# block): its own translated-shader database, since DXMT keys translations by
# shader and variant only and would reuse the ones the engine's translator made
elif [ "$t" = steam ] && [ "${s_kind:-}" = s1 ] && { [ -f "${AW_DXMT_DIR:-/nonexistent}/x86_64-unix/winemetal.so" ] ||
     { on AW_DXMT_FIX && [ -f "$kit/payload/steam/aw-winemetal.so" ]; }; }; then
  aw_cache="$(getconf DARWIN_USER_CACHE_DIR 2>/dev/null)dxmt/$s_exe/airconv-aw5"
  # a whole DXMT build under test (AW_DXMT_DIR): its own database
  [ -f "${AW_DXMT_DIR:-/nonexistent}/x86_64-unix/winemetal.so" ] && aw_cache="${aw_cache%/*}/test-$(basename "$AW_DXMT_DIR")"
  if [ "${aw_cache#/}" != "$aw_cache" ] && mkdir -p "$aw_cache"; then set_env DXMT_SHADER_CACHE_PATH "$aw_cache"
  else clear_env DXMT_SHADER_CACHE_PATH; fi
# Infinite Warfare with the same translator (IW7_DXMT_FIX, see the Steam block):
# its own database too, only when the clone will really be made. IW7-Mod
# (iw7-mod.exe) draws the same game's shaders: it uses Steam's Infinite
# Warfare's database and Metal's compiled shaders (iw7_ship.exe's, a link as
# for Black Ops II above), so neither starts cold after the other was played
# (the first cold "Preloading Shaders" took ~3.5 min, session 20)
elif [ "$t" = steam ] && [ "${s_kind:-}" = iw7 ] && on IW7_DXMT_FIX && [ -f "$kit/payload/steam/aw-winemetal.so" ] &&
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
# a MetalFX setting left by an earlier Siliconium build
{ grep -q '^"DXMT_METALFX_SPATIAL_SWAPCHAIN"=' "$WINEPREFIX/user.reg" 2>/dev/null &&
  clear_env DXMT_METALFX_SPATIAL_SWAPCHAIN; }
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
# Fullscreen: Wine captures the display, macOS shows the frames directly.
if on CAPTURE_DISPLAY; then reg add "$bootstrapper\\Mac Driver" /v CaptureDisplaysForFullscreen /d y /f
else reg add "$bootstrapper\\Mac Driver" /v CaptureDisplaysForFullscreen /d n /f; fi
if [ "$t" = iw5 ]; then
  for exe in iw5mp.exe iw5sp.exe; do
    if on CAPTURE_DISPLAY; then reg add "HKCU\\Software\\Wine\\AppDefaults\\$exe\\Mac Driver" /v CaptureDisplaysForFullscreen /d y /f
    else reg add "HKCU\\Software\\Wine\\AppDefaults\\$exe\\Mac Driver" /v CaptureDisplaysForFullscreen /d n /f; fi
  done
fi
if [ "$t" = iw4 ]; then
  for exe in iw4x.exe iw4x-sp.exe iw4sp.exe; do
    if on CAPTURE_DISPLAY; then reg add "HKCU\\Software\\Wine\\AppDefaults\\$exe\\Mac Driver" /v CaptureDisplaysForFullscreen /d y /f
    else reg add "HKCU\\Software\\Wine\\AppDefaults\\$exe\\Mac Driver" /v CaptureDisplaysForFullscreen /d n /f; fi
  done
fi
# The Plutonium launcher's window is drawn with OpenGL.
reg add 'HKCU\Software\Wine\AppDefaults\plutonium-launcher-win32.exe\Direct3D' /v renderer /d gl /f
reg_flush
[ "$t" = t6c ] || [ "$t" = steam ] || "$WINESERVER" -w 2>/dev/null   # the campaign's Steam never exits

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

# --- The Steam Library (prefix-steam) -------------------------------------------
# Steam (restarted above, so it and the game it starts get this environment
# and the 1x display mode) signs in by itself and starts the game: as its own
# Steam app when the part has one, else its executable with Steam's app ID.
if [ "$t" = steam ]; then
  steamdir="$WINEPREFIX/drive_c/Program Files (x86)/Steam"
  log="$home/logs/steam-$s_id-$s_part.log"
  [ -n "${s_client:-}" ] && log="$home/logs/$s_client.log"
  log_cap "$log"
  case "$s_kind" in
    iw6) capture=n ;;            # borderless
    t6)  capture=n ;;            # BO2 keeps the desktop's mode
    *)   if on CAPTURE_DISPLAY; then capture=y; else capture=n; fi ;;
  esac
  reg add "HKCU\\Software\\Wine\\AppDefaults\\$s_exe\\Mac Driver" /v CaptureDisplaysForFullscreen /d "$capture" /f
  if [ "$s_api" = d3d9x64 ]; then
    steam_dxvk64 "$WINEPREFIX" "$kit" ||
      die "Could not install DXVK for $s_name (64-bit Direct3D 9): reinstall Siliconium."
    reg add "HKCU\\Software\\Wine\\AppDefaults\\$s_exe\\DllOverrides" /v d3d9 /d native /f
  fi
  # Black Ops Multiplayer: Plutonium's multiplayer renderer (payload/bo1/
  # mp-d3d9.dll, our DXVK with the multiplayer warming flag, DXVK_T5MP_WARM;
  # Steam's BlackOpsMP.exe is the executable Plutonium runs) for that
  # executable only, from Steam's 32-bit system folder; every other 32-bit
  # Direct3D 9 game of the section keeps the engine's own DXVK (builtin)
  if [ "$s_api" = d3d9 ]; then
    if [ "$s_exe" = BlackOpsMP.exe ] && on BO1_MP_FAST_LOAD && on BO1_WARM && on BO1_ASYNC &&
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
  # Advanced Warfare with its own shader translator (winemetal.so, the unix
  # half of DXMT, kit/payload/steam/aw-winemetal.so = v0.80 +
  # patches/dxmt-airconv-ts-workloads-v0.80.patch): DXMT's emulated
  # tessellation declared fewer mesh workloads than its quad generator emits,
  # and AW's GPU page-faulted seconds into play. winemetal.so is shared by
  # every Direct3D 11 game and Wine prefers the built-in modules next to its
  # own loader, so AW runs from a clone of the engine's lib/wine with that
  # file replaced (as Black Ops Multiplayer's renderer); every other game
  # keeps the engine untouched. AW_DXMT_DIR (development only, see above)
  # puts a whole DXMT build in that clone.
  aw_engine=
  sil_so=
  [ -f "${SIL_DXMT_SO:-/nonexistent}" ] && case "${SIL_DXMT_CACHE:-}" in /?*) true ;; *) false ;; esac && sil_so=$SIL_DXMT_SO
  # Infinite Warfare (iw7, IW7_DXMT_FIX) runs from the same clone: its
  # tessellation shaders use the same quad generator (dxmt.generate_workload.
  # quad.integer) and with only the DLL above its GPU page-faulted ~1.5 min
  # into its first mission, as AW's did (session 20)
  if [ -n "${aw_dxmt_dir:-}" ] || [ -n "$sil_so" ] || { { { [ "${s_kind:-}" = s1 ] && on AW_DXMT_FIX; } || { [ "${s_kind:-}" = iw7 ] && on IW7_DXMT_FIX; }; } &&
     [ -f "$kit/payload/steam/aw-winemetal.so" ] &&
     cmp -s "$engine/lib/wine/x86_64-windows/winemetal.dll" "$kit/payload/dxmt/x86_64-windows/winemetal.dll"; }; then
    # (the PE half it must pair with: DXMT v0.80's; the engine's .so is re-signed, so not byte-equal)
    for old in "$home/cache"/aw-engine.*; do   # left by a run that did not end normally
      [ -d "$old" ] && /usr/bin/python3 -I -c 'import shutil, sys; shutil.rmtree(sys.argv[1])' "$old"
    done
    if aw_engine=$(mktemp -d "$home/cache/aw-engine.XXXXXX") && mkdir "$aw_engine/lib"; then
      for entry in "$engine"/*; do [ "${entry##*/}" = lib ] || ln -s "$entry" "$aw_engine/"; done
      for entry in "$engine/lib"/*; do [ "${entry##*/}" = wine ] || ln -s "$entry" "$aw_engine/lib/"; done
      aw_so="$kit/payload/steam/aw-winemetal.so"; [ -n "${aw_dxmt_dir:-}" ] && aw_so="$aw_dxmt_dir/x86_64-unix/winemetal.so"
      [ -n "$sil_so" ] && aw_so=$sil_so
      if ! { cp -cRp "$engine/lib/wine" "$aw_engine/lib/wine" &&
             { [ -z "${aw_dxmt_dir:-}" ] || cp "$aw_dxmt_dir"/x86_64-windows/*.dll "$aw_engine/lib/wine/x86_64-windows/"; } &&
             cp "$aw_so" "$aw_engine/lib/wine/x86_64-unix/winemetal.so" &&
             codesign -fs - "$aw_engine/lib/wine/x86_64-unix/winemetal.so" 2>/dev/null; }; then
        /usr/bin/python3 -I -c 'import shutil, sys; shutil.rmtree(sys.argv[1])' "$aw_engine"; aw_engine=
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
  case "$s_exe" in
    BlackOps.exe) on BO1_SHADER_CACHE && /usr/bin/python3 -I "$kit/tools/statecache-merge.py" \
      "$home/cache/steam-bo1/BlackOps.dxvk-cache" "$kit/payload/bo1/pipelines.dxvk-cache" \
      "$home/cache/plutonium-bootstrapper-win32.dxvk-cache" 2>/dev/null || true ;;
    CoDWaW.exe|CoDWaWmp.exe) on WAW_PIPELINES && /usr/bin/python3 -I "$kit/tools/statecache-merge.py" \
      "$home/cache/steam-waw/${s_exe%.exe}.dxvk-cache" "$kit/payload/waw/pipelines.dxvk-cache" \
      "$home/cache/plutonium-bootstrapper-win32.dxvk-cache" 2>/dev/null || true ;;
  esac
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
    for cab in "$dir/redist/DirectX/$xa_cab" "$dir/DirectX/$xa_cab"; do   # Steam's WaW: DirectX/
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
  # Black Ops II: the hardware profile made on an Apple GPU, once (as for the campaign)
  if [ "$s_kind" = t6 ] && on BO2_HW_PROFILE && [ ! -f "$dir/players/.sil-defaults-hardware" ]; then
    mkdir -p "$dir/players"
    cp "$kit/payload/bo2/hardware.chp" "$dir/players/hardware.chp" && : > "$dir/players/.sil-defaults-hardware"
  fi
  # Controller aim as on the consoles, in the games with controller support
  case "$s_kind" in
    t6)  for c in "$dir"/players/*.cfg; do console_aim "$c"; done ;;
    iw6) for c in "$dir"/players2/*.cfg; do console_aim "$c"; done ;;
  esac
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
  marker="$home/cache/steam-$s_id/.started-$s_part"; mkdir -p "$home/cache/steam-$s_id"
  [ -n "${s_client:-}" ] && marker="$home/cache/steam-$s_id/.started-$s_client"
  first=1; [ -f "$marker" ] && first=0
  steam_args "${dw:-}" "${dh:-}" "${hz:-}" "$first"
  if [ "${s_client:-}" = cod4x ]; then
    # CoD4X keeps its profiles in its AppData folder (fs_savepath
    # %LOCALAPPDATA%\CallofDuty4MW: players\profiles\<name>, seen on its first
    # start 2026-11-21), not in the game's folder: its settings go there
    mkdir -p "$c4_home/players/profiles"
    steam_config "$c4_home" "${dw:-}" "${dh:-}" "${hz:-}" "$home/cache/steam-$s_id/$s_client-home"
  elif [ -n "${s_client:-}" ]; then
    # IW7-Mod moves the game's profile to <game>\iw7-mod\players2 (its
    # filesystem.cpp) and writes the dvars without a readable name as the game
    # does (setcl <checksum>): the same two values, in its profile
    steam_config "$dir/iw7-mod" "${dw:-}" "${dh:-}" "${hz:-}" "$home/cache/steam-$s_id/$s_client-home"
  else
    steam_config "$dir" "${dw:-}" "${dh:-}" "${hz:-}" "$home/cache/steam-$s_id"
  fi
  # shellcheck disable=SC2206
  [ -n "${GAME_ARGS:-}" ] && s_argv+=($GAME_ARGS)
  [ -n "${s_client:-}" ] || steam_mod_args "$dir"
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
  if bash "$kit/steam.sh" start; then :
  elif [ -n "${s_client:-}" ]; then use_steam=0
  else exit 1; fi
  signed=
  # Steam's sign-in: up to 3 minutes (CoD4X: 90 s, then it starts anyway)
  tries=90; [ -n "${s_client:-}" ] && tries=45
  [ "$use_steam" = 1 ] && for _ in $(seq 1 "$tries"); do
    tail -n +$((seen + 1)) "$clog" 2>/dev/null | grep '\[Logged On,' > /dev/null && { signed=1; break; }
    sleep 2
  done
  if [ -n "$signed" ] && [ -n "${s_client:-}" ]; then
    printf '%s\n' "--- $(date) Steam signed in: running in the background for $s_name" >> "$log"
  elif [ -n "${s_client:-}" ]; then
    printf '%s\n' "--- $(date) Steam did not sign in: $s_name starts without Steam (servers that require Steam will refuse it)" >> "$log"
  elif [ -z "$signed" ]; then
    bash "$kit/steam.sh" open
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
  if [ -f "$guard" ]; then
    "$wine" "$guard" 21600 > /dev/null 2>&1 &
    guard_pid=$!
    trap '[ -n "$guard_pid" ] && kill "$guard_pid" 2>/dev/null; pkill -f "dialog-guard\.exe|pad-mapper\.exe" 2>/dev/null; copy_release; true' EXIT
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
             "$wine" "$kit/payload/steam/pad-mapper.exe" 21600 $pad_ads > /dev/null 2>&1 &
           fi ;;
  esac
  if [ "$s_own" = 1 ]; then
    # this start is Steam's own: the in-game switch relay (tools/steam-relay.sh) lets it through
    mkdir -p "$WINEPREFIX/drive_c/users/Public/Siliconium/relay" &&
      : > "$WINEPREFIX/drive_c/users/Public/Siliconium/relay/bypass-$s_app"
    (cd "$steamdir" && "$wine" Steam.exe -applaunch "$s_app" ${s_argv[@]+"${s_argv[@]}"} >> "$log" 2>&1 &)
  else
    # Call of Duty and Call of Duty 2 load steam.dll by name ("Failed to find
    # Steam." otherwise): Steam's folder on their search path, as when Steam
    # starts them
    steam_env=(SteamAppId="$s_app" SteamGameId="$s_app")
    [ "$s_kind" = q3 ] && steam_env+=(WINEPATH='C:\Program Files (x86)\Steam')
    game_wine=$wine
    [ -n "${aw_engine:-}" ] && game_wine="$aw_engine/lib/wine/x86_64-unix/wine"
    # (a fix's launcher, m_start, starts the game itself with these arguments)
    (cd "$dir" && env "${steam_env[@]}" "$game_wine" "./${m_start:-$s_exe}" ${s_argv[@]+"${s_argv[@]}"} >> "$log" 2>&1 &)
  fi
  # The game is running when its executable works the CPU; Steam says right
  # away when it will not start it
  exe_re=${s_exe//./\\.}
  game_pid=
  # (IW7-Mod's updater fetches its data files, ~376 MB, before the game opens
  # the first time, at a low CPU load: up to 20 minutes)
  start_wait=180; [ "${s_client:-}" = iw7mod ] && start_wait=1200
  for _ in $(seq 1 "$start_wait"); do
    for pid in $(pgrep -f "$exe_re"); do
      cpu=$(ps -o %cpu= -p "$pid" 2>/dev/null | tr -d ' '); cpu=${cpu%%.*}
      [ "${cpu:-0}" -gt 20 ] && { game_pid=$pid; break 2; }
    done
    err=$(tail -n +$((cseen + 1)) "$console" 2>/dev/null | grep -oE "AppID $s_app.*LaunchApp failed with [A-Za-z_]+[0-9]*" | grep -oE '[A-Za-z]+Error_[0-9]+|k_E[A-Za-z0-9_]+' | tail -1)
    case "$err" in
      AppError_5) die "Steam has no license for $s_name on this account: sign in with the account that owns it (Open Steam)" ;;
      ?*) bash "$kit/steam.sh" open; die "Steam could not start $s_name ($err): look at Steam's window" ;;
    esac
    sleep 1
  done
  if [ -z "$game_pid" ] && [ -n "${s_client:-}" ]; then
    die "$s_name did not start (see logs/${log##*/})"
  elif [ -z "$game_pid" ]; then
    bash "$kit/steam.sh" open
    die "Steam did not start $s_name: look at Steam's window (license, an update, or a first-time setup step)"
  fi
  : > "$marker"
  # Call of Duty 2 minimizes its fullscreen window when it loses focus, and
  # Wine did not restore it when the player came back (black screen): Ghosts'
  # helper restores the game's window when its Mac app is activated again
  focus_pid=
  # (Call of Duty and United Offensive through GLDirect draw with Direct3D 9
  # too: same black screen)
  if { [ "$s_kind:$s_api" = q3:d3d9 ] || steam_gldirect; } &&
     [ -x "$kit/payload/iw6/iw6-focus" ]; then
    # The helper needs the game's own Mac process: the one found above can be
    # Wine's start.exe (its command line names the game too), which is never
    # the frontmost app, so the window was never restored (Call of Duty)
    app_pid=$game_pid
    # (Call of Duty 2's campaign had the same wrong pid: after Cmd+Tab its window
    # stayed minimized, keys only beeped). Every part: the multiplayer
    # executables start the same way
    if [ "$s_kind" = q3 ]; then
      for pid in $(pgrep -f "$exe_re"); do
        case "$(ps -o comm= -p "$pid" 2>/dev/null)" in *"$s_exe") app_pid=$pid; break ;; esac
      done
    fi
    "$kit/payload/iw6/iw6-focus" "$app_pid" "$wine" "$kit/payload/iw6/iw6-restore.exe" "$s_exe" >> "$log" 2>&1 &
    focus_pid=$!
  elif [ "$s_exe" = iw6sp64_ship.exe ] && [ -x "$kit/payload/iw6/iw6-focus" ]; then
    # Ghosts' campaign: the helper exactly as Siliconium's own Ghosts runs it
    # (no executable name: it also hides Ghosts' black fullscreen window while
    # another app is in front)
    "$kit/payload/iw6/iw6-focus" "$game_pid" "$wine" "$kit/payload/iw6/iw6-restore.exe" >> "$log" 2>&1 &
    focus_pid=$!
  elif [ "$s_exe" = iw6mp64_ship.exe ] && [ -x "$kit/payload/iw6/iw6-focus" ]; then
    # Ghosts' multiplayer (same engine and window): the same helper, told its
    # executable (a Ghosts name keeps the hiding)
    "$kit/payload/iw6/iw6-focus" "$game_pid" "$wine" "$kit/payload/iw6/iw6-restore.exe" "$s_exe" >> "$log" 2>&1 &
    focus_pid=$!
  fi
  while pgrep -f "$exe_re" > /dev/null; do sleep 2; done
  [ -n "${s_client:-}" ] || steam_mod_remove "$dir"   # the fix's files go with the game
  [ -n "$focus_pid" ] && kill "$focus_pid" 2>/dev/null
  # Advanced Warfare's clone goes a while later: a game handing over to its other
  # part as it quits (Exo Zombies: steam.exe steam://run/…, started from this
  # clone) lost that request when the clone was removed at once
  [ -n "${aw_engine:-}" ] &&
    (sleep 120; /usr/bin/python3 -I -c 'import shutil, sys; shutil.rmtree(sys.argv[1])' "$aw_engine") > /dev/null 2>&1 &
  exit 0
fi

# --- Black Ops II's campaign through Steam for Windows (prefix-steam) ----------
# Steam (restarted above, so Wine sees the 1x display mode and Steam gets this
# environment: x87 accelerator, DXMT settings) signs in by itself and starts
# the game, checking its license; Siliconium's patches are in the engine and the
# environment, the game's files are Steam's own.
if [ "$t" = t6s ]; then
  if on CAPTURE_DISPLAY; then reg add 'HKCU\Software\Wine\AppDefaults\t6sp.exe\Mac Driver' /v CaptureDisplaysForFullscreen /d y /f
  else reg add 'HKCU\Software\Wine\AppDefaults\t6sp.exe\Mac Driver' /v CaptureDisplaysForFullscreen /d n /f; fi
  # a hardware profile made on an Apple GPU (fullscreen 1920x1080), once, as for BO2
  if on BO2_HW_PROFILE && [ ! -f "$dir/players/.sil-defaults-hardware" ]; then
    mkdir -p "$dir/players"
    cp "$kit/payload/bo2/hardware.chp" "$dir/players/hardware.chp" && : > "$dir/players/.sil-defaults-hardware"
  fi
  bs="$kit/bo2-steam.sh"
  clog="$WINEPREFIX/drive_c/Program Files (x86)/Steam/logs/connection_log.txt"
  seen=$(wc -l < "$clog" 2>/dev/null | tr -d ' '); seen=${seen:-0}
  reg_flush
  bash "$bs" start || exit 1
  signed=
  for _ in $(seq 1 90); do   # this Steam's sign-in (up to 3 minutes)
    tail -n +$((seen + 1)) "$clog" 2>/dev/null | grep '\[Logged On,' > /dev/null && { signed=1; break; }
    sleep 2
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
  for _ in $(seq 1 180); do
    for pid in $(pgrep -f 't6sp\.exe'); do
      cpu=$(ps -o %cpu= -p "$pid" 2>/dev/null | tr -d ' '); cpu=${cpu%%.*}
      [ "${cpu:-0}" -gt 20 ] && { game_pid=$pid; break 2; }
    done
    err=$(tail -n +$((cseen + 1)) "$console" 2>/dev/null | grep -oE 'AppID 202970.*LaunchApp failed with [A-Za-z_]+[0-9]*' | grep -oE '[A-Za-z]+Error_[0-9]+|k_E[A-Za-z0-9_]+' | tail -1)
    case "$err" in
      AppError_5) die "Steam has no license for Black Ops II on this account: sign in with the account that owns it (Open Steam)" ;;
      ?*) bash "$bs" open; die "Steam could not start the campaign ($err): look at Steam's window" ;;
    esac
    sleep 1
  done
  if [ -z "$game_pid" ]; then
    bash "$bs" open
    die "Steam did not start the campaign: look at Steam's window (license, an update, or a first-time setup step)"
  fi
  while pgrep -f 't6sp\.exe' >/dev/null; do sleep 2; done
  exit 0
fi

# --- Black Ops III for Windows through boiii (BOIII / Ezz client) ----------------
# boiii.exe sits in the game folder and starts the game from there (it is the
# working directory), on DXMT (Direct3D 11 -> Metal, 64-bit).
if [ "$t" = t7 ]; then
  for exe in boiii.exe boiii-beta.exe BlackOps3.exe; do
    if on CAPTURE_DISPLAY; then reg add "HKCU\\Software\\Wine\\AppDefaults\\$exe\\Mac Driver" /v CaptureDisplaysForFullscreen /d y /f
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
    local dxmt=$1 shared own a b
    case "$dxmt" in /?*/dxmt) ;; *) return 0 ;; esac
    shared="$dxmt/BlackOps3.exe/com.apple.metal" own="$dxmt/boiii.exe/com.apple.metal"
    [ -L "$own" ] && return 0
    pgrep -f '[B]lackOps3\.exe|[b]oiii\.exe' > /dev/null && return 0
    mkdir -p "$dxmt/boiii.exe" "$dxmt/BlackOps3.exe" || return 0
    if [ -d "$own" ]; then
      a=$(du -sk "$own" 2>/dev/null | cut -f1) b=$(du -sk "$shared" 2>/dev/null | cut -f1)
      if [ "${a:-0}" -gt "${b:-0}" ]; then rm -rf "$shared" && mv "$own" "$shared" || return 0
      else rm -rf "$own" || return 0; fi
    fi
    mkdir -p "$shared" && ln -s "$shared" "$own"
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
    WINEDLLOVERRIDES="mscoree=" "$wine" regsvr32 /s mshtml.dll > /dev/null 2>&1 &&
    WINEDLLOVERRIDES="mscoree=" "$wine" 'C:\windows\syswow64\regsvr32.exe' /s mshtml.dll > /dev/null 2>&1 &&
      : > "$WINEPREFIX/.sil-mshtml"
  fi
  # Prefixes made before the engine had winegstreamer: register it once.
  sys="$WINEPREFIX/drive_c/windows"
  if [ ! -f "$sys/system32/winegstreamer.dll" ] && [ -f "$engine/lib/wine/x86_64-windows/winegstreamer.dll" ]; then
    cp "$engine/lib/wine/x86_64-windows/winegstreamer.dll" "$sys/system32/"
    cp "$engine/lib/wine/i386-windows/winegstreamer.dll" "$sys/syswow64/" 2>/dev/null
    "$wine" regsvr32 /s winegstreamer.dll > /dev/null 2>&1
    "$wine" 'C:\windows\syswow64\regsvr32.exe' /s winegstreamer.dll > /dev/null 2>&1
  fi
  "$WINESERVER" -w 2>/dev/null
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
  export WINEDLLOVERRIDES="mscoree="
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
  /usr/bin/python3 -I - "$dir/boiii_players/properties.json" "${3:-${PLAYER_NAME:-}}" <<'PY' 2>/dev/null || true
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
PY
  # First start: the game's auto-detect picks for an unknown GPU (half
  # resolution, no shadows, no ambient occlusion). Set it up once like BO1 and
  # BO2 instead: fullscreen at the desktop's size and refresh rate with sync,
  # full resolution and full detail. Afterwards the game's own options rule.
  ini="$dir/boiii_players/config.ini"
  if on BOIII_GRAPHICS && [ ! -f "$dir/boiii_players/.sil-defaults-config.ini" ] && [ -n "${dw:-}" ]; then
    mkdir -p "$dir/boiii_players"; touch "$ini"
    ini_set() {   # ini_set key value: replace the line or add it
      if grep -q "^$1 = " "$ini"; then sed -i '' -E "s|^($1 = )\"[^\"]*\"|\1\"$2\"|" "$ini"
      else printf '%s = "%s"\n' "$1" "$2" >> "$ini"; fi
    }
    ini_set AutoDetectHasRun 1;           ini_set RestrictGraphicsOptions 0
    ini_set FullScreenMode 1;             ini_set WindowSize "${dw}x${dh}"
    ini_set RefreshRate "${hz:-60}";      ini_set Vsync 1
    ini_set ResolutionPercent 100;        ini_set MeshQuality 0
    ini_set TextureQuality 0;             ini_set TextureFilter 2
    ini_set DisableDynamicLightShadows 0; ini_set DisableDynamicSunShadows 0
    # Volumetric lighting and subsurface scattering are full-screen passes
    # that cost the most frame time on Apple GPUs for the least visible
    # change; they start off (the game's options can turn them on).
    ini_set ShadowFiltering 1;            ini_set VolumetricLightingEnabled 0
    ini_set SSAOTechnique "GTAO Medium Quality"
    ini_set AATechnique "Filmic SMAA T2x"; ini_set SubsurfaceScattering 0
    ini_set MotionBlur Off
    : > "$dir/boiii_players/.sil-defaults-config.ini"
  fi
  # Every launch (BOIII_SCREEN=0 leaves it to the game): fullscreen at the
  # display's size and refresh rate, and the game's frame cap at that rate. Its
  # own default cap is 60 (MaxFPS = "60"), and a crash or the launcher could
  # leave it windowed at a smaller size (2560x1387 here).
  if on BOIII_SCREEN && [ -n "${dw:-}" ] && [ -n "${dh:-}" ]; then
    mkdir -p "$dir/boiii_players"; touch "$ini"
    ini_put() {   # ini_put key value: replace the value (keeping its comment) or add the line
      if grep -q "^$1 = " "$ini"; then sed -i '' -E "s|^($1 = )\"[^\"]*\"|\1\"$2\"|" "$ini"
      else printf '%s = "%s"\n' "$1" "$2" >> "$ini"; fi
    }
    ini_put FullScreenMode 1
    ini_put WindowSize "${dw}x${dh}"
    [ -n "${hz:-}" ] && ini_put RefreshRate "$hz"
    ini_put MaxFPS "${maxfps:-0}"
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
    "$kit/tools/displaymode" "$dw" "$dh" $$ >> "$home/logs/displaymode.log" 2>&1 &
    sleep 2   # the switch first: Wine reads the desktop mode as the game starts
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
  boiii_version=$(/usr/bin/python3 -I -c 'import json,sys
try: print(json.load(open(sys.argv[1], encoding="utf-8-sig")).get("selectedVersion", ""))
except Exception: pass' boiii_players/properties.json 2>/dev/null)
  if [ "$mode" != launcher ] && [ "$boiii_version" = beta ] && [ -f versions/boiii-beta.exe ]; then
    boiii_exe=versions/boiii-beta.exe
    case " ${GAME_ARGS:-} " in *" -noupdate "*) ;; *) GAME_ARGS="${GAME_ARGS:+$GAME_ARGS }-noupdate" ;; esac
  fi
  # shellcheck disable=SC2086
  "$wine" "$boiii_exe" ${GAME_ARGS:-} > "$log" 2>&1
  boiii_status=$?
  "$WINESERVER" -w 2>/dev/null
  exit "$boiii_status"
fi

# --- Plutonium and game settings -----------------------------------------------
winpath=$(sil_winpath "$dir")
plutonium_cfg="$plutonium/config.json"
set_cvar() { sed -i '' -E "s/^seta $2 \"[^\"]*\"/seta $2 \"$3\"/" "$1"; }
set_or_add() { if grep -q "^seta $2 " "$1"; then set_cvar "$@"; else printf 'seta %s "%s"\n' "$2" "$3" >> "$1"; fi; }
desktop=${dw:+${dw}x$dh}
# Default settings, applied once per game profile (marker file), so what the
# player changes in the game afterwards is kept: fullscreen at the display's
# resolution, sync every frame, automatic texture quality, 16x anisotropy.
defaults_once() {   # defaults_once <cfg> <marker> name value ...
  local cfg=$1 marker=$2; shift 2
  [ -f "$marker" ] && return 0
  [ -f "$cfg" ] || : > "$cfg"
  while [ $# -ge 2 ]; do set_or_add "$cfg" "$1" "$2"; shift 2; done
  : > "$marker"
}
common_cvars() {
  fullscreen_cfg "$1"
  on MSAA_FIX && sed -i '' -E 's/^seta r_aaSamples "(8|16|32)"/seta r_aaSamples "4"/' "$1"
  if [ -n "$desktop" ]; then
    local rmode
    rmode=$(sed -n -E 's/^seta r_mode "([0-9]+)x[0-9]+"/\1/p' "$1")
    # BO2 can render on a different monitor, and its saved pixel resolution
    # can exceed the desktop's logical width even when using the same display.
    if [ "$rmode" = 800 ] || { [ "$t" != t6 ] && [ -n "$rmode" ] && [ "$rmode" -gt "${desktop%x*}" ]; }; then
      set_cvar "$1" r_mode "$desktop"
    fi
  fi
  if [ "${RAW_INPUT:-1}" = 1 ]; then set_or_add "$1" raw_input 1; set_or_add "$1" m_filter 0; fi
  console_aim "$1"
  set_or_add "$1" gpad_stick_deadzone_min "${STICK_DEADZONE:-0.08}"
  set_or_add "$1" cl_mouseAccel 0
  # Straight to the menu: the publisher/studio logo movies are not played
  # (every start decoded them before the menu could load).
  if on SKIP_INTRO; then
    set_or_add "$1" com_introPlayed 1
    [ "$t" = t6 ] || set_or_add "$1" com_startupIntroPlayed 1
  fi
}
t5mp_engine=
prepare_t5mp_engine() {
  local mp_exe="$plutonium/games/t5mp.exe" entry
  local renderer="$kit/payload/bo1/mp-d3d9.dll"
  [ -f "$renderer" ] && [ -f "$mp_exe" ] || return 1
  # This renderer identifies the warming pass of this specific T5 image.
  [ "$(shasum -a 256 < "$mp_exe")" = "6a544494722aaf90ae241d687fca0aebd73f97f0d79412d0f8c311f6c369c3fb  -" ] || return 1
  cmp -s "$engine/lib/wine/i386-windows/d3d9.dll" "$kit/payload/i386-windows/d3d9.dll" || return 1

  # Wine prefers built-in DLLs next to its own loader. Clone that directory
  # for MP so the installed renderer and all other games keep their DLL.
  t5mp_engine=$(mktemp -d "$home/cache/t5mp-engine.XXXXXX") || return 1
  mkdir "$t5mp_engine/lib" || return 1
  for entry in "$engine"/*; do
    [ "${entry##*/}" = lib ] || ln -s "$entry" "$t5mp_engine/" || return 1
  done
  for entry in "$engine/lib"/*; do
    [ "${entry##*/}" = wine ] || ln -s "$entry" "$t5mp_engine/lib/" || return 1
  done
  cp -cRp "$engine/lib/wine" "$t5mp_engine/lib/wine" &&
    cp "$renderer" "$t5mp_engine/lib/wine/i386-windows/d3d9.dll"
}

cleanup_t5mp_engine() {
  [ -n "$t5mp_engine" ] || return 0
  /usr/bin/python3 -I -c 'import shutil, sys; shutil.rmtree(sys.argv[1])' "$t5mp_engine"
  t5mp_engine=
}

if [ "$t:$mode" = t5:mp ] && [ "${4:-}" != --lan ]; then
  if on BO1_MP_FAST_LOAD && on BO1_WARM && on BO1_ASYNC && prepare_t5mp_engine; then
    set_env DXVK_T5MP_WARM 1
    trap cleanup_t5mp_engine EXIT
  else
    cleanup_t5mp_engine
    clear_env DXVK_T5MP_WARM
  fi
fi

if [ "$t" = t5 ]; then
  players="$plutonium/storage/t5/players"
  # The shipped list was collected in Zombies. Keep it and the legacy
  # imports in the shared cache. MP learns its own pipelines as maps load.
  if [ "$mode" != mp ] && on BO1_SHADER_CACHE; then
    /usr/bin/python3 -I "$kit/tools/statecache-merge.py" "$home/cache/plutonium-bootstrapper-win32.dxvk-cache" \
      "$kit/payload/bo1/pipelines.dxvk-cache" \
      "$dir/plutonium-bootstrapper-win32.dxvk-cache" "$dir"/*/cache/plutonium-bootstrapper-win32.dxvk-cache 2>/dev/null || true
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
    # The MP renderer queues new pipelines during the normal map load. Other
    # client builds keep cache-only loading, avoiding a synchronous warm pass.
    if [ "$mode:$c" = mp:config_mp.cfg ] && on BO1_MP_FAST_LOAD && [ -z "$t5mp_engine" ]; then
      set_or_add "$players/$c" r_shaderWarming 0
    elif on BO1_WARM; then
      set_or_add "$players/$c" r_shaderWarming 1
    else
      set_or_add "$players/$c" r_shaderWarming 0
    fi
    if [ "${STREAM:-0}" = 1 ]; then sed -i '' '/^seta r_stream "/d' "$players/$c"
    else set_or_add "$players/$c" r_stream 0; fi
    set_cvar "$players/$c" com_maxfps 0
  done
  gamecfg="$players/config.cfg"; [ "$mode" = mp ] && gamecfg="$players/config_mp.cfg"
  # DXVK reads dxvk.conf from the working directory
  dxvk="d3d9.numBackBuffers = 3"$'\n'"dxvk.numCompilerThreads = $dxvk_threads"$'\n'"dxvk.numAsyncThreads = $dxvk_threads"$'\n'
  [ "$maxfps" != 0 ] && dxvk+="d3d9.maxFrameRate = $maxfps"$'\n'
  for d in "$dir" "$plutonium" "$plutonium/bin"; do [ -d "$d" ] && printf '%s' "$dxvk" > "$d/dxvk.conf"; done
  # XAudio2 2.7 from BO1's redist: Wine's leaves BO1's gunfire silent
  xa="$WINEPREFIX/xaudio2_7.native.dll"
  if [ ! -f "$xa" ] && [ -f "$dir/redist/DirectX/Jun2010_XAudio_x86.cab" ]; then
    tmp=$(mktemp -d)
    bsdtar -xf "$dir/redist/DirectX/Jun2010_XAudio_x86.cab" -C "$tmp" XAudio2_7.dll 2>/dev/null && cp "$tmp/XAudio2_7.dll" "$xa"
    rm -rf "$tmp"
  fi
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
  # registered, so fold in the list gathered on the zombies maps (and any an
  # older setup left): the load screen then compiles a map's materials instead
  # of the game compiling them one by one while the player is already looking
  # at them (the weapon, the character and map objects appeared late). The
  # bootstrapper's cache is shared with Black Ops.
  on WAW_PIPELINES && /usr/bin/python3 -I "$kit/tools/statecache-merge.py" \
    "$home/cache/plutonium-bootstrapper-win32.dxvk-cache" \
    "$kit/payload/waw/pipelines.dxvk-cache" \
    "$dir/plutonium-bootstrapper-win32.dxvk-cache" 2>/dev/null || true
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
    # Draw every material while the map loads. With DXVK_ASYNC=2 the pipelines
    # compile in the background during the loading screen (and are written to
    # DXVK's cache) instead of popping in once play starts.
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
  # The game's shader preload (r_preloadShaders) stalled the menu/loading screen
  # for about a minute on its first run: keep it off. Compiled pipelines are
  # saved in the DXVK state cache instead, so later visits do not compile them.
  set_or_add "$cfg" r_preloadShaders 0
  # No "Set Optimal Settings?" question at start-up (it waits for a click
  # before the game window opens, and would replace the settings above).
  set_or_add "$cfg" com_recommendedSet 1
  # Straight to the menu: no intro movie (Plutonium's plutonium.bik). Bink
  # decodes on one CPU thread under Rosetta (85-95 % busy, GPU idle) and only
  # reached ~27 of its 30 FPS, so the movie skipped frames.
  if on SKIP_INTRO; then set_or_add "$cfg" intro 0; fi
  # Direct fullscreen: a borderless window becomes real fullscreen (Wine
  # captures the display). A windowed mode the player picked is left alone.
  on CAPTURE_DISPLAY && sed -i '' -E 's/^seta r_displayMode "windowed \(no border\)"/seta r_displayMode "fullscreen"/' "$cfg"
  # The app's frame-rate cap (the game's default is 300)
  set_or_add "$cfg" com_maxfps "${maxfps:-0}"
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
    r_fullscreen 1 r_noborder 0 r_mode "1920x1080" r_vsync 1 \
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
    set_cvar "$players/$c" com_maxfps 0
  done
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

if [ "$t:$mode" = iw5:mp ]; then
  # With VSync, IW5's saved 60 Hz caps fullscreen at 60 FPS even when
  # com_maxfps and DXVK are set to 160. At the desktop's size its refresh
  # is already known to be available. Leave other resolutions to the game.
  if on DISPLAY_MODE && [[ ${hz:-} =~ ^[1-9][0-9]*$ ]] &&
     grep -Fxq 'seta r_displayMode "fullscreen"' "$gamecfg" &&
     grep -Fxq "seta r_mode \"$desktop\"" "$gamecfg"; then
    saved_hz=$(sed -n -E 's/^seta r_displayRefresh "([0-9]+) Hz"/\1/p' "$gamecfg" | tail -1)
    if [ "${saved_hz:-0}" -lt "$hz" ]; then
      set_or_add "$gamecfg" r_displayRefresh "$hz Hz"
    fi
  fi
elif [ "$t" = iw5 ]; then
  # A 1x display mode of the resolution Modern Warfare 3 runs at, while it is
  # fullscreen (as for BO1/BO2), so a HiDPI desktop is not scaled every frame.
  if on DISPLAY_MODE && grep -q '^seta r_displayMode "fullscreen"' "$gamecfg"; then
    hold_1x_size "$(sed -n -E 's/^seta r_mode "([0-9]+x[0-9]+)"/\1/p' "$gamecfg" | tail -1)"
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
if [ -n "$t5mp_engine" ]; then
  export CX_ROOT="$t5mp_engine"
  export WINEDLLPATH="$t5mp_engine/lib/wine/x86_64-windows:$t5mp_engine/lib/wine/x86_64-unix"
  wine="$t5mp_engine/lib/wine/x86_64-unix/wine"
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
  if [ -f iw4x-launcher.exe ] && "$wine" iw4x-launcher.exe "${iw4_args[@]}" --no-connect-protocol > "$log" 2>&1; then
    :
  elif [ -f iw4x.exe ]; then
    printf '\nStarting the installed IW4X client directly.\n' >> "$log"
    # shellcheck disable=SC2086
    exec "$wine" iw4x.exe -stdout -nointro ${GAME_ARGS:-} >> "$log" 2>&1
  else
    die "The IW4X launcher failed (see logs/$game-$mode.log)."
  fi
  "$WINESERVER" -w 2>/dev/null
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
if [ "${4:-}" != --lan ] && [ "$mode" != declassified ]; then
  launcher="$plutonium/bin/plutonium-launcher-win32.exe"
  [ -f "$launcher" ] || die "Plutonium is not installed in the prefix. Run Install first."
  cd "$plutonium/bin" || exit 1
  if [ "$mode" = online ]; then
    # Opening the launcher also lets the user sign in again if its session expired.
    /usr/bin/python3 -I "$kit/tools/plutonium-config.py" link "$plutonium_cfg" "$t" "$winpath" "$pmode" || true
    exec "$wine" "$launcher" > "$log" 2>&1
  fi
  /usr/bin/python3 -I "$kit/tools/plutonium-config.py" link "$plutonium_cfg" "$t" "$winpath" ||
    die "Could not load your Plutonium setup. Open Plutonium to sign in again, or run Install."
  # The launcher's URI skips game selection and hands an online session to
  # the bootstrapper. Keep the Wine configuration and patches set above.
  "$wine" "$launcher" "plutonium://play/$pmode" > "$log" 2>&1 ||
    die "Plutonium could not start $pmode (see logs/$game-$mode.log). Open Plutonium to check your session."
  "$WINESERVER" -w 2>/dev/null
  exit
fi
extra=${GAME_ARGS:-}
[ "$t" = t6 ] && extra="${BO2_MODS:-} $extra"
cd "$plutonium" || exit 1
# shellcheck disable=SC2086
if [ "$t" = iw5 ]; then
  on SKIP_INTRO && extra="+set intro 0 $extra"
  exec "$wine" bin/plutonium-bootstrapper-win32.exe "$pmode" "$winpath" +set name "${3:-Player}" -lan $extra > "$log" 2>&1
fi
# shellcheck disable=SC2086
exec "$wine" bin/plutonium-bootstrapper-win32.exe "$pmode" "$winpath" +name "${3:-Player}" -lan $extra > "$log" 2>&1
