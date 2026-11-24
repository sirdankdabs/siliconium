# Siliconium: the Battle.net section's games and Battle.net itself, sourced by
# battlenet.sh (needs WINEPREFIX, wine, home, kit).
#
# The catalog: <id> <Battle.net product (its Agent's uid)> <launch code>
# <executable> <name>. Battle.net starts a game from its launch code
# (Battle.net.exe --exec="launch <code>", with the app open and signed in).
bnet_catalog() {
  cat <<'EOF'
bo4 viper VIPR BlackOps4.exe Call of Duty: Black Ops 4
EOF
}
# bnet_field <id> <n>: a catalog column (5 = the name, which has spaces)
bnet_field() { bnet_catalog | awk -v id="$1" -v n="$2" '$1 == id { if (n < 5) print $n; else { $1 = $2 = $3 = $4 = ""; sub(/^ +/, ""); print } }'; }

bnet_dir="$WINEPREFIX/drive_c/Program Files (x86)/Battle.net"
bnet_data="$WINEPREFIX/drive_c/ProgramData/Battle.net"
bnet_installed() { [ -f "$bnet_dir/Battle.net.exe" ] || [ -f "$bnet_dir/Battle.net Launcher.exe" ]; }
# Battle.net's app is open (its command line names it with \ or /: the
# installer started it as C:/Program Files (x86)/Battle.net/Battle.net.exe)
bnet_running() { pgrep -f 'Battle\.net[\\/]Battle\.net(\.[0-9]+[\\/]Battle\.net)?\.exe' > /dev/null 2>&1; }

bnet_local="$WINEPREFIX/drive_c/users/crossover/AppData/Local"
# Signed in: Battle.net's newest log (a new one at every start) says
# "[BNLogin] … Logged into Battle.net successfully." (2.53.8, 2026-11-22).
# bnet_signed_in <file>: only a log written after <file> (made just before a
# start) counts, so a launch command never goes to a Battle.net still signing in
bnet_signed_in() {
  local f
  f=$(ls -t "$bnet_local/Battle.net/Logs"/battle.net-*.log 2> /dev/null | head -1)
  [ -n "$f" ] || return 1
  [ -z "${1:-}" ] || [ "$f" -nt "$1" ] || return 1
  grep -aq '\[BNLogin\].*Logged into Battle.net successfully' "$f"
}

# The Agent's database of installed games (ProgramData/Battle.net/Agent/product.db):
# <uid>|<install folder (Windows)>|<installed 0/1>|<playable 0/1>, one per game
bnet_products() {
  [ -f "$bnet_data/Agent/product.db" ] || return 0
  /usr/bin/python3 -I "$kit/tools/battlenet-products.py" "$bnet_data/Agent/product.db" 2> /dev/null
}
# A Windows folder (C:/… or C:\…) as a Mac path in this prefix's drives
bnet_macpath() {
  local p=${1//\\//} d rest
  d=$(printf '%s' "${p%%:*}" | tr 'A-Z' 'a-z'); rest=${p#*:}
  [ -e "$WINEPREFIX/dosdevices/$d:" ] || return 0
  printf '%s\n' "$(cd "$WINEPREFIX/dosdevices/$d:" 2> /dev/null && pwd -P)$rest"
}
bnet_gamedir() {
  local uid exe line path
  uid=$(bnet_field "$1" 2) exe=$(bnet_field "$1" 4)
  [ -n "$uid" ] || return 0
  line=$(bnet_products | awk -F'|' -v u="$uid" '$1 == u' | head -1)
  [ -n "$line" ] || return 0
  path=$(bnet_macpath "$(printf '%s' "$line" | cut -d'|' -f2)")
  [ -n "$path" ] && [ -f "$path/$exe" ] && echo "$path"
}
# installed = its download finished (Battle.net recorded the installed version)
# and the game's program is in its folder; downloading = it is in Battle.net's
# list but its first download has not finished.
# Not Battle.net's "playable" flag: under Wine the Agent clears it at every
# start after the install, "Build marked non-playable for viper: Permissions
# check failure (2123)" (it cannot check or fix the folder's permissions: its
# helper service fails, "validate_helper_service … Failed Install Handler -
# 2110"), with the game complete and current (local_version = current_version);
# Battle.net still starts it (`--exec="launch VIPR"`, measured 2026-11-22). The
# version stays empty during the first download (Agent log: local_version "").
bnet_state() {
  local uid line
  uid=$(bnet_field "$1" 2)
  line=$(bnet_products | awk -F'|' -v u="$uid" '$1 == u' | head -1)
  [ -n "$line" ] || { echo missing; return; }
  if { [ "$(printf '%s' "$line" | cut -d'|' -f4)" = 1 ] \
       || { [ "$(printf '%s' "$line" | cut -d'|' -f3)" = 1 ] && [ -n "$(printf '%s' "$line" | cut -d'|' -f5)" ]; }; } \
     && [ -n "$(bnet_gamedir "$1")" ]; then echo installed
  else echo downloading; fi
}

# Battle.net's app: Battle.net.exe in its folder starts the newest version it
# keeps beside it (Battle.net.<build>\Battle.net.exe; 2.53.8, 32-bit, with
# Chromium 108 for its windows). Two things it needs under Wine (measured
# 2026-11-22, Siliconium's notes):
# - WINE_SIMULATE_WRITECOPY=1 (CrossOver's hack 22996 in our ntdll): Chromium
#   makes some of libcef.dll's data read-only and checks the page was
#   read-write before (VirtualProtect); Wine reported it copy-on-write, so its
#   page process stopped itself at that check every ~5 s (int3 at libcef+0x16d00e1)
#   and the login never showed. Battle.net's processes (and the game it starts,
#   which inherits it) see read-write, as on Windows.
# - --in-process-gpu: Chromium's GPU work runs in Battle.net's own process; in
#   its own process it could not draw into Battle.net's window ("cross-process
#   swapchain not supported yet") and the login stayed black.
bnet_exe() { if [ -f "$bnet_dir/Battle.net.exe" ]; then echo "$bnet_dir/Battle.net.exe"; else echo "$bnet_dir/Battle.net Launcher.exe"; fi; }

# Battle.net's engine: a clone of the engine with two Wine modules of our own,
# for the Battle.net section only (payload/battlenet/, from patches/battlenet/;
# the engine and every other game are unchanged). Measured with Black Ops 4,
# 2026-11-22:
# - ntdll.so (wine-ntdll-rosetta-privileged.patch): Rosetta raises "invalid
#   opcode" for privileged instructions where an x86 CPU raises a protection
#   fault; Windows reports those as privileged instructions. Black Ops 4's
#   anti-debugging reads a debug register (mov rax, dr0) on its own stack and
#   handles only that code: Wine reported an illegal instruction instead, could
#   not dispatch it on that stack and ended the game 2-8 s into fullscreen.
# - win32u.so (wine-win32u-memory-size.patch): the GPU's memory in the display
#   registry (HardwareInformation.MemorySize, 32 bits) was written as 0 when it
#   is a multiple of 4 GB (Wine used the Mac's 64-bit ULONG_MAX); Windows clamps
#   it. Black Ops 4 read 0: its "at least 2 GB of video memory" warning.
# The clone is made again (APFS: ~0.3 s, no disk space) whenever Battle.net is
# started, so it always follows the engine. Only over our own engine build.
bnet_engine="$home/battlenet/engine"
bnet_engine_prepare() {
  local new="$bnet_engine.new" entry
  grep -Fxq 'base=own 0.2.3' "$engine/siliconium.version" 2> /dev/null || return 1
  [ -f "$kit/payload/battlenet/ntdll.so" ] && [ -f "$kit/payload/battlenet/win32u.so" ] || return 1
  # (a Battle.net still open keeps the clone it runs from)
  if bnet_running && [ -x "$bnet_engine/lib/wine/x86_64-unix/wine" ]; then return 0; fi
  rm -rf "$new"; mkdir -p "$new/lib" || return 1
  for entry in "$engine"/*; do [ "${entry##*/}" = lib ] || ln -s "$entry" "$new/"; done
  for entry in "$engine/lib"/*; do [ "${entry##*/}" = wine ] || ln -s "$entry" "$new/lib/"; done
  if cp -cRp "$engine/lib/wine" "$new/lib/wine" &&
     cp "$kit/payload/battlenet/ntdll.so" "$new/lib/wine/x86_64-unix/ntdll.so" &&
     cp "$kit/payload/battlenet/win32u.so" "$new/lib/wine/x86_64-unix/win32u.so" &&
     codesign -fs - "$new/lib/wine/x86_64-unix/ntdll.so" "$new/lib/wine/x86_64-unix/win32u.so" 2> /dev/null; then
    rm -rf "$bnet_engine" && mv "$new" "$bnet_engine"
  else
    rm -rf "$new"; return 1
  fi
}
# bnet_use_engine: Wine for Battle.net and its games (BNET_ENGINE=<folder>,
# development only: an engine folder under test instead)
bnet_use_engine() {
  local root=${BNET_ENGINE:-}
  if [ -z "$root" ] || [ ! -x "$root/lib/wine/x86_64-unix/wine" ]; then
    root=$engine
    if bnet_engine_prepare; then root=$bnet_engine
    else printf '%s\n' "Warning: Battle.net's engine fixes are missing; Black Ops 4 may close right after it starts." >&2; fi
  fi
  export CX_ROOT="$root" WINEDLLPATH="$root/lib/wine/x86_64-windows:$root/lib/wine/x86_64-unix"
  # macOS Game Mode: Battle.net and its games from this engine's bundle
  # (tools/game-bundle.sh; GAME_MODE=0: off)
  . "$kit/tools/game-bundle.sh" && use_wine "$root/lib/wine/x86_64-unix/wine" ||
    { unset WINELOADER; wine="$root/lib/wine/x86_64-unix/wine"; }
}
bnet_start_client() {
  local exe; exe=$(bnet_exe)
  (cd "$bnet_dir" && WINE_SIMULATE_WRITECOPY=${WINE_SIMULATE_WRITECOPY:-1} \
    nohup "$wine" "$exe" --in-process-gpu ${BNET_ARGS:-} "$@" > "$home/logs/battlenet.log" 2>&1 &)
}
# a command for the Battle.net that is open (Battle.net.exe hands it over)
# (with the same settings, in case it starts Battle.net itself)
bnet_cmd() {
  local exe; exe=$(bnet_exe)
  (cd "$bnet_dir" && WINE_SIMULATE_WRITECOPY=${WINE_SIMULATE_WRITECOPY:-1} \
    "$wine" "$exe" --in-process-gpu "$@" > /dev/null 2>&1 &)
}
# A Battle.net that is starting ignores commands: start it, wait for its login
bnet_ensure_running() {
  bnet_running && return 0
  local mark="$home/cache/.battlenet-start"
  mkdir -p "$home/cache"; : > "$mark"
  bnet_start_client
  for _ in $(seq 1 90); do bnet_signed_in "$mark" && break; sleep 2; done
  sleep 3
}

# --- Playing (sourced by launch.sh: t=bnet) -----------------------------------
# bnet_title <id>: the game's table entry for launch.sh
#   b_id b_uid b_code b_exe b_name
#   b_dxmt  the DXMT switches' prefix in settings.conf (<b_dxmt>_ASYNC, _FRAME_PACING)
bnet_title() {
  local line
  line=$(bnet_catalog | awk -v id="$1" '$1 == id') || return 1
  [ -n "$line" ] || return 1
  b_id=$1 b_uid=$(bnet_field "$1" 2) b_code=$(bnet_field "$1" 3) b_exe=$(bnet_field "$1" 4) b_name=$(bnet_field "$1" 5)
  case "$1" in bo4) b_dxmt=BO4 ;; *) b_dxmt=BNET ;; esac
}
# bnet_play: launch.sh's start of a Battle.net game (everything it set up above
# is in this shell: the environment, reg/reg_flush, the 1x display mode hold).
# Battle.net was stopped with everything in its prefix (stop_all): started
# again here, it and the game it starts get this environment. Returns when the
# game has quit; Battle.net stays open in the background (downloads, friends).
bnet_play() {
  local log="$home/logs/battlenet-$b_id.log" capture game_pid cpu pid
  log_cap "$log"
  if on CAPTURE_DISPLAY; then capture=y; else capture=n; fi
  reg add "HKCU\\Software\\Wine\\AppDefaults\\$b_exe\\Mac Driver" /v CaptureDisplaysForFullscreen /d "$capture" /f
  reg_flush
  # Wine's mouse look as for the Steam Library's Black Ops III (the game draws
  # its own menu pointer: 2 keeps Wine's cursor where it was)
  export WINE_MAC_MOUSELOOK="${WINE_MAC_MOUSELOOK:-2}"
  # BNET_WINEDEBUG (settings.conf, development only): a Wine trace for
  # Battle.net and its game only (logs/battlenet.log), e.g. -all,+seh,+process
  [ -n "${BNET_WINEDEBUG:-}" ] && export WINEDEBUG="$BNET_WINEDEBUG"
  # Battle.net's engine (bnet_use_engine: the clone with our two modules)
  bnet_use_engine
  [ -n "${BNET_ENGINE:-}" ] && printf 'Engine under test: %s\n' "$BNET_ENGINE" >> "$log"
  printf '\n--- %s: Battle.net start for %s\n' "$(date)" "$b_name" >> "$log"
  # Black Ops 4 leaves BlackOps4.start behind when it does not quit normally
  # (seen 2026-11-22, as Black Ops III's BlackOps3.start): the next start would
  # offer Safe Mode, which lowers the graphics settings. The app starts the
  # game only when it is not running, so the marker is stale here.
  [ "$b_id" = bo4 ] && rm -f "$dir/BlackOps4.start"
  bnet_config "$dir" "${dw:-}" "${dh:-}" "${hz:-}" "${maxfps:-${hz:-}}"
  bnet_prefix_settings
  # A community fix chosen in the app (settings.conf STEAM_MOD_<GAME>, the
  # Steam Library's fixes: tools/steam-mods.sh): checked and put into the
  # game's folder only while it runs, taken out when it quits (or, after a
  # crash, at its next start). Shield starts the game itself, below.
  local s_id=$b_id s_part=all s_exe=$b_exe s_argv=()
  m_mod=none m_error=
  if . "$kit/tools/steam-mods.sh"; then
    steam_mod_prepare "$dir" || die "$m_error"
    steam_mod_args "$dir"
    reg_flush
  fi
  local mark="$home/cache/.battlenet-start"
  : > "$mark"
  # macOS Game Mode for the game Battle.net starts: our ntdll.so
  # (patches/battlenet/wine-ntdll-game-bundle.patch) runs the programs
  # SIL_GAME_EXES names from a copy of Wine's loader inside an app bundle of the
  # games category (gamepolicyd's condition), not from Wine's bare link, so
  # Game Mode can be on while the game plays fullscreen (WWII's campaign: +40 %
  # FPS with it, 2026-11-23). Battle.net passes its environment to the game.
  if [ "${GAME_MODE:-1}" != 0 ]; then export SIL_GAME_EXES="$b_exe"; else unset SIL_GAME_EXES; fi
  if [ "$m_mod" != shield ]; then
    # In the background, as Steam (-silent): --autostarted is what Windows' log-in
    # start passes, and Battle.net then keeps its window minimized when its "start
    # minimized" setting is on (its default, Client.AutoStartMinimized)
    bnet_start_client --autostarted
    # Battle.net hands a launch command over only once it is signed in (this start's log)
    local signed=0
    for _ in $(seq 1 90); do bnet_signed_in "$mark" && { signed=1; break; }; sleep 2; done
    if [ "$signed" = 0 ]; then
      die "Battle.net is not signed in: sign in in its window (tick Keep me logged in), then press Play again"
    fi
    sleep 3
  fi
  # The game's questions in Windows message boxes (tools/bnet-guard.c): "Yes"
  # to Black Ops 4's minimum-requirements warning (seen while Wine reported the
  # GPU's memory as 0; kept for Macs whose GPU memory is still read low), "No"
  # to Safe Mode; it ends with the game
  bnet_guard_pid=
  if [ -f "$kit/payload/battlenet/bnet-guard.exe" ]; then
    "$wine" "$kit/payload/battlenet/bnet-guard.exe" 21600 >> "$log" 2> /dev/null &
    bnet_guard_pid=$!
    trap '[ -n "${bnet_guard_pid:-}" ] && kill "$bnet_guard_pid" 2> /dev/null; pkill -f "bnet-guard\.exe" 2> /dev/null; true' EXIT
  fi
  if [ "$m_mod" = shield ]; then
    # Shield: the game started as its instructions say (BlackOps4.exe, no
    # Battle.net: its own Demonware emulator), with this same environment
    printf 'Fix %s: %s started directly, without Battle.net\n' "$m_mod" "$b_exe" >> "$log"
    (cd "$dir" && WINE_SIMULATE_WRITECOPY=${WINE_SIMULATE_WRITECOPY:-1} \
      nohup "$wine" "$b_exe" >> "$log" 2>&1 &)
  else
    bnet_cmd --exec="launch $b_code"
    printf 'Asked Battle.net: --exec="launch %s"\n' "$b_code" >> "$log"
  fi
  # The game is running when its executable works the CPU. Battle.net may first
  # update it or ask something in its window (up to 10 minutes)
  game_pid=
  for _ in $(seq 1 600); do
    for pid in $(bnet_game_pids); do
      cpu=$(ps -o %cpu= -p "$pid" 2> /dev/null | tr -d ' '); cpu=${cpu%%.*}
      [ "${cpu:-0}" -gt 20 ] && { game_pid=$pid; break 2; }
    done
    sleep 1
  done
  if [ -z "$game_pid" ]; then
    if [ "$m_mod" = shield ]; then
      steam_mod_remove "$dir"
      die "$b_name did not start with Shield: choose No fix in its Fixes menu to play through Battle.net"
    fi
    bnet_cmd
    die "Battle.net did not start $b_name: look at Battle.net's window (an update, a question, or the licence)"
  fi
  printf 'Game running: pid %s\n' "$game_pid" >> "$log"
  # Back from another app (Cmd-Tab, or minimized): Wine left the fullscreen
  # window minimized and the screen black, as Call of Duty 2's; Ghosts' helper
  # restores it when the game's Mac app is active again (restore only).
  # SIL_FOCUS_FROM: macOS does not bring forward a game that Battle.net starts
  # (keys went to Siliconium, Game Mode stayed off until a click, 4 of 4 starts
  # 2026-11-23): the helper makes it the active app once its window is up, only
  # if Siliconium or Battle.net is in front then (never over another app)
  local focus_pid=
  if [ -x "$kit/payload/iw6/iw6-focus" ] && [ -f "$kit/payload/iw6/iw6-restore.exe" ]; then
    SIL_FOCUS_FROM="io.github.siliconium:Battle.net.exe:Battle.net Launcher.exe" \
      "$kit/payload/iw6/iw6-focus" "$game_pid" "$wine" "$kit/payload/iw6/iw6-restore.exe" "$b_exe" >> "$log" 2>&1 &
    focus_pid=$!
  fi
  while [ -n "$(bnet_game_pids)" ]; do sleep 2; done
  [ -n "$focus_pid" ] && kill "$focus_pid" 2> /dev/null
  [ "$m_mod" = none ] || steam_mod_remove "$dir"   # the fix's files go with the game
  printf -- '--- %s: %s quit\n' "$(date)" "$b_name" >> "$log"
  return 0
}
# The game's Mac processes, by their exact name (a command line that merely
# mentions the executable, as a shell's, is not the game). pgrep's name of a
# Wine process is its Windows program as started: "BlackOps4.exe" when
# Battle.net starts it, a full "C:\…\BlackOps4.exe" when another program
# names the path (measured 2026-11-23) — both match. Names longer than macOS
# keeps (16 characters): by command line
bnet_game_pids() {
  if [ "${#b_exe}" -le 16 ]; then pgrep -x "(.*[\\/])?${b_exe//./\\.}"; else pgrep -f "${b_exe//./\\.}"; fi
}

# Settings of Battle.net's prefix, once (a marker per version of this list):
# - Wine's crash dialog off: Battle.net's web view restarts a crashed helper
#   by itself, and the dialog ("Battle.net.exe has encountered a serious
#   problem") took the screen; the crash's backtrace goes to the log instead
bnet_prefix_settings() {
  local mark="$WINEPREFIX/.sil-battlenet-settings-1"
  [ -f "$mark" ] && return 0
  "$wine" reg add 'HKCU\Software\Wine\WineDbg' /v ShowCrashDialog /t REG_DWORD /d 0 /f > /dev/null 2>&1 &&
    : > "$mark"
}

# bnet_ini_set <file> <key> <value>: Black Ops 4's players/config.ini lines are
# `key = "value" // comment`; the value is replaced (comment kept) or the line added
bnet_ini_set() {
  local f=$1 k=$2 v=$3
  if grep -q "^$k = \"" "$f"; then
    sed -i '' -E "s|^($k = \")[^\"]*(\".*)$|\\1$v\\2|" "$f"
  else
    printf '%s = "%s"\n' "$k" "$v" >> "$f"
  fi
}
# bnet_config <game folder> <width> <height> <Hz> <frame cap>: the game's
# settings before every start (launch.sh's environment: on, home)
bnet_config() {
  local dir=$1 w=$2 h=$3 hz=$4 cap=$5 marks="$home/cache/battlenet-$b_id" f p
  case "$b_id" in
    bo4)
      # Black Ops 4: players/config.ini (made by its first start; the game
      # also keeps one per signed-in profile, applied after its login: the same
      # values go into every one found). Every start (BO4_SCREEN): exclusive
      # fullscreen at the desktop's size and the refresh rate of the mode
      # launch.sh holds, the frame cap at that rate (its own default: none).
      # Once (BO4_GRAPHICS): its auto-detect saw no video memory (Wine reports
      # 0 to WMI) and chose the lowest of everything with the scene drawn at
      # half resolution; Black Ops III's choices for Apple GPUs instead (full
      # resolution and detail, volumetric lighting and subsurface scattering
      # off, motion blur off). SKIP_INTRO: no intro movies.
      mkdir -p "$marks"
      while IFS= read -r f; do
        [ -f "$f" ] || continue
        if on BO4_GRAPHICS && [ ! -f "$marks/.defaults-$(printf '%s' "$f" | shasum | cut -c1-12)" ]; then
          for p in resolution_percent=100 mesh_quality=0 texture_filter=2 texture_quality=0 texture_quality_fx=0 \
                   texture_quality_probes=0 texture_quality_baked_sun_shadows=0 disable_dynamic_light_shadows=0 \
                   disable_dynamic_sun_shadows=0 shadow_filtering=1 "ssao_technique=GTAO Medium Quality" \
                   "aa_technique=Filmic SMAA T2x" motion_blur=Off subsurface_scattering=0 volumetric_light_quality=0 \
                   local_ambient_lighting=0; do
            bnet_ini_set "$f" "${p%%=*}" "${p#*=}"
          done
          : > "$marks/.defaults-$(printf '%s' "$f" | shasum | cut -c1-12)"
        fi
        if on BO4_SCREEN && [ -n "$w" ] && [ -n "$h" ]; then
          bnet_ini_set "$f" fullscreen_mode 1
          bnet_ini_set "$f" fullscreen_preferred_mode 1
          bnet_ini_set "$f" fullscreen_resolution "${w}x$h"
          [ -n "$hz" ] && bnet_ini_set "$f" refresh_rate "$hz"
          [ -n "$cap" ] && bnet_ini_set "$f" max_fps "$cap"
        fi
        if on SKIP_INTRO; then bnet_ini_set "$f" play_intro_movies 0; else bnet_ini_set "$f" play_intro_movies 1; fi
      done < <(find "$dir/players" -maxdepth 3 -name config.ini 2> /dev/null)
      ;;
  esac
  return 0
}
