#!/bin/bash
# Siliconium: Steam for Windows, in its own Wine prefix (prefix-steam), apart
# from the other games. The player signs in with their account and downloads
# their Call of Duty games there; Steam starts the games it runs (and checks
# their licenses), and the Plutonium / IW4X / offline games can use the
# folders it downloads.
#
#   steam.sh status            steam=installed|missing  signedin=yes|no  running=yes|no
#   steam.sh library           one line per game in the catalog:
#                              <id>|<state>|<folder>|<part>:<state>,...|<DLC installed>|<tool>:<state>,...
#                              state: installed|downloading|missing (each part,
#                              like Multiplayer or Zombies, is its own Steam app)
#   steam.sh setup             creates prefix-steam, installs Steam for Windows
#                              (Valve's installer) and opens it to sign in
#   steam.sh open              opens Steam's window (sign in, downloads)
#   steam.sh download <id>     opens Steam's install dialog for a catalog game
#                              (each of its Steam apps: campaign, multiplayer…)
#   steam.sh download-all      the same for every catalog game not downloaded yet
#   steam.sh download-tool <id>  the same for a game's tools (Black Ops III:
#                              Mod Tools), never part of download / download-all
#   steam.sh store <id>        opens the game's store page in Steam
#   steam.sh start             starts Steam in the background if it isn't open
#   steam.sh wait              waits (up to 3 minutes) until Steam is signed in
#   steam.sh gamedir <appid>   an app's folder (empty if not installed)
#   steam.sh state <appid>     installed|downloading|missing
#   steam.sh launch <appid>    asks Steam to start an app
#
# Progress lines start with "==> "; errors with "ERROR: ".
set -uo pipefail
kit=$(cd -- "$(dirname -- "$0")" && pwd)
home=${SIL_HOME:-"$HOME/Library/Application Support/Siliconium"}
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/tools/migrate.sh"   # an install of the previous name
engine="$home/engine"
export WINEPREFIX="$home/prefix-steam" WINEMSYNC=1 WINEDEBUG=${WINEDEBUG:--all} CX_ROOT="$engine"
# Steam stays open in the background: its Wine server runs through a link
# outside the engine folder, so the app doesn't count it as a game running
mkdir -p "$home/campaign" "$home/logs"
ln -sfn "$engine/bin/wineserver" "$home/campaign/wineserver"
export WINESERVER="$home/campaign/wineserver"
wine="$engine/lib/wine/x86_64-unix/wine"
steamdir="$WINEPREFIX/drive_c/Program Files (x86)/Steam"
downloads="$home/downloads"
step() { printf '==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# The catalog: <id> <Steam apps, the main one first>. The main app is the one
# whose folder the game uses; the others (multiplayer, zombies) install into
# the same folder and are downloaded with it when the account owns them.
catalog() {
  cat <<'EOF'
cod1 2620:Game
uo 2640:Game
cod2 2630:Game
cod4 7940:Game
waw 10090:Game
mw2 10180:Campaign 10190:Multiplayer
mw3 42680:Campaign 42690:Multiplayer
bo1 42700:Campaign 42710:Multiplayer
bo2 202970:Campaign 202990:Multiplayer 212910:Zombies
ghosts 209160:Campaign 209170:Multiplayer
aw 209650:Campaign 209660:Multiplayer
bo3 311210:Game
iw 292730:Game
wwii 476600:Campaign 476620:Multiplayer
EOF
}
# a game's Steam apps (numbers only), the main one first
apps_of() { catalog | awk -v id="$1" '$1 == id { for (i = 2; i <= NF; i++) { split($i, a, ":"); printf "%s ", a[1] } }'; }
# A game's Steam tools: apps made for creating content, not for playing (Black
# Ops III's Mod Tools: Radiant, the map compiler and linker, installed into
# the game's own folder). Never part of Download / Download all / Download the
# rest: each is downloaded only from its own button (download-tool).
tools() {
  cat <<'EOF'
bo3 455130:ModTools
EOF
}
tool_of() { tools | awk -v id="$1" '$1 == id { split($2, a, ":"); print a[1] }'; }

# signed in now: Steam's latest connection state is "Logged On"
signed_in() {
  grep -oE '^\[[^]]+\] \[[A-Za-z ]+,' "$steamdir/logs/connection_log.txt" 2>/dev/null | tail -1 | grep -q 'Logged On'
}
running() { pgrep -f 'Program Files \(x86\)\\Steam\\[Ss]team\.exe' >/dev/null 2>&1; }

# Steam's libraries: its own folder and any other the player added
libraries() {
  local lib
  { printf '%s\n' "C:\\\\Program Files (x86)\\\\Steam"
    sed -n -E 's/^[[:space:]]*"path"[[:space:]]*"(.*)"/\1/p' "$steamdir/steamapps/libraryfolders.vdf" 2>/dev/null
  } | while IFS= read -r lib; do
    lib=${lib//\\\\/\\}; lib=${lib#[Cc]:}; echo "$WINEPREFIX/drive_c${lib//\\//}"
  done | awk '!seen[$0]++'
}
# An app's manifest: the library holding it
manifest() {
  local lib
  while IFS= read -r lib; do
    [ -f "$lib/steamapps/appmanifest_$1.acf" ] && { echo "$lib/steamapps/appmanifest_$1.acf"; return; }
  done < <(libraries)
}
gamedir() {
  local m dir
  m=$(manifest "$1"); [ -n "$m" ] || return 0
  dir=$(sed -n -E 's/^[[:space:]]*"installdir"[[:space:]]*"(.*)"/\1/p' "$m")
  [ -n "$dir" ] && [ -d "$(dirname "$m")/common/$dir" ] && echo "$(dirname "$m")/common/$dir"
}
# StateFlags 4 = fully installed (other values: downloading, update needed…)
app_state() {
  local m flags
  m=$(manifest "$1"); [ -n "$m" ] || { echo missing; return; }
  flags=$(sed -n -E 's/^[[:space:]]*"StateFlags"[[:space:]]*"([0-9]+)"/\1/p' "$m")
  if [ "$flags" = 4 ] && [ -n "$(gamedir "$1")" ]; then echo installed; else echo downloading; fi
}
# DLC the account owns (map packs…) is downloaded by Steam with the game: its
# depots are listed in the game's manifests with a "dlcappid"
dlc_count() {
  local a m
  for a in $(apps_of "$1"); do
    m=$(manifest "$a"); [ -n "$m" ] || continue
    sed -n -E 's/^[[:space:]]*"dlcappid"[[:space:]]*"([0-9]+)"/\1/p' "$m"
  done | sort -u | grep -c .
}
# A game is installed when its main app is and none of its other apps is
# still downloading; apps the account does not own are never downloaded
game_state() {
  local main extra s
  read -r main extra <<< "$(apps_of "$1")"
  s=$(app_state "$main")
  [ "$s" = installed ] || { echo "$s"; return; }
  for a in $extra; do [ "$(app_state "$a")" = downloading ] && { echo downloading; return; }; done
  echo installed
}

# Steam's web windows draw with the engine's steamwebhelper fix (ntdll); the
# GPU and the sandbox stay off. The in-game overlay is off in Steam's own
# settings (tools/steam-overlay-off.py: it does not draw under Wine). Its DLLs
# stay in place: without them Steam reinstalled itself at every start, and an
# unsigned stand-in made it refuse to start games ("Corrupt file signature").
overlay_off() {
  local f
  # Siliconium 2026-11-19 builds moved the DLLs aside or put a stand-in there
  for f in GameOverlayRenderer.dll GameOverlayRenderer64.dll; do
    if [ -f "$steamdir/$f.off" ] && { [ ! -f "$steamdir/$f" ] || LC_ALL=C grep -aq SiliconiumNoOverlay "$steamdir/$f"; }; then
      mv -f "$steamdir/$f.off" "$steamdir/$f"
    fi
  done
  running && return 0   # Steam rewrites its settings when it exits
  python3 -I "$kit/tools/steam-overlay-off.py" "$steamdir" $(catalog | tr ' ' '\n' | sed -n 's/^\([0-9]*\):.*/\1/p') 2> /dev/null ||
    printf '%s\n' 'Warning: could not turn the Steam overlay off.' >&2
}
# A campaign's Multiplayer / Zombies button (steam://run/<app>) has Steam start
# that part itself: Steam's launch options of these apps put silrelay.exe in
# front, and tools/steam-relay.sh (beside Steam) starts the part through
# launch.sh, with Siliconium's settings and fixes (tools/silrelay.c).
relay_apps="209650 209660 202970 202990 212910 42700 42710 10180 10190 42680 42690 209160 209170"
relay_setup() {
  local pub="$WINEPREFIX/drive_c/users/Public/Siliconium"
  mkdir -p "$pub/relay" || return 1
  cmp -s "$kit/payload/steam/silrelay.exe" "$pub/silrelay.exe" || cp "$kit/payload/steam/silrelay.exe" "$pub/silrelay.exe"
  running || python3 -I "$kit/tools/steam-launch-options.py" "$steamdir" 'C:\\users\\Public\\Siliconium\\silrelay.exe' $relay_apps 2> /dev/null ||
    printf '%s\n' 'Warning: could not set Steam launch options for in-game part switches.' >&2
  (nohup bash "$kit/tools/steam-relay.sh" > /dev/null 2>&1 &)
}
start_steam() {
  . "$kit/tools/configure-ds4.sh"
  configure_ds4_xinput || printf '%s\n' 'Warning: could not set up PlayStation controller XInput mapping.' >&2
  overlay_off
  relay_setup
  (cd "$steamdir" && nohup "$wine" Steam.exe "$@" -cef-disable-gpu -cef-disable-gpu-compositing \
    -cef-disable-sandbox > "$home/logs/steam.log" 2>&1 &)
}
# a URL or command for the Steam that is open (or a new one)
steam_cmd() { (cd "$steamdir" && "$wine" Steam.exe "$@" > /dev/null 2>&1 &); }
# A Steam that is starting drops requests: start it and wait until it has signed in
ensure_running() {
  running && return 0
  local seen
  seen=$(wc -l < "$steamdir/logs/connection_log.txt" 2>/dev/null | tr -d ' '); seen=${seen:-0}
  start_steam
  for _ in $(seq 1 90); do
    tail -n +$((seen + 1)) "$steamdir/logs/connection_log.txt" 2>/dev/null | grep -q '\[Logged On,' && break
    sleep 2
  done
  sleep 3
}
need_steam() { [ -f "$steamdir/Steam.exe" ] || die "Steam is not installed: press Install Steam first"; }

case "${1:-}" in
status)
  [ -f "$steamdir/Steam.exe" ] && echo "steam=installed" || echo "steam=missing"
  signed_in && echo "signedin=yes" || echo "signedin=no"
  running && echo "running=yes" || echo "running=no"
  ;;
library)
  catalog | while read -r id parts; do
    main=${parts%%:*} list= tl=
    for p in $parts; do list+="${p#*:}:$(app_state "${p%%:*}"),"; done
    # (6th field: the game's tools, as <name>:<state>)
    for p in $(tools | awk -v id="$id" '$1 == id { $1 = ""; print }'); do tl+="${p#*:}:$(app_state "${p%%:*}"),"; done
    printf '%s|%s|%s|%s|%s|%s\n' "$id" "$(game_state "$id")" "$(gamedir "$main")" "${list%,}" "$(dlc_count "$id")" "${tl%,}"
  done
  ;;
setup)
  [ -x "$wine" ] || die "install the Siliconium engine first"
  mkdir -p "$downloads"
  if [ ! -f "$WINEPREFIX/system.reg" ]; then
    step "Creating Steam's own Wine prefix"
    WINEDLLOVERRIDES="mscoree,mshtml=" "$wine" wineboot --init > "$home/logs/steam-wineboot.log" 2>&1
    "$WINESERVER" -w
    [ -f "$WINEPREFIX/system.reg" ] || die "Wine could not create Steam's prefix (see logs/steam-wineboot.log)"
  fi
  if [ ! -f "$steamdir/Steam.exe" ]; then
    step "Downloading Steam for Windows (Valve)"
    curl -fsSL --retry 3 -o "$downloads/SteamSetup.exe.part" \
      https://cdn.cloudflare.steamstatic.com/client/installer/SteamSetup.exe || {
      rm -f "$downloads/SteamSetup.exe.part"; die "cannot download Steam"; }
    mv -f "$downloads/SteamSetup.exe.part" "$downloads/SteamSetup.exe"
    strings -a "$downloads/SteamSetup.exe" | grep -q "Valve Corp" || { rm -f "$downloads/SteamSetup.exe"; die "unexpected Steam installer"; }
    step "Installing Steam for Windows"
    "$wine" "$downloads/SteamSetup.exe" /S > /dev/null 2>&1
    "$WINESERVER" -w
    # (the installer is not kept: Steam updates itself, a new setup downloads it again)
    rm -f "$downloads/SteamSetup.exe"; rmdir "$downloads" 2> /dev/null || true
    [ -f "$steamdir/Steam.exe" ] || die "Steam did not install"
  fi
  step "Opening Steam: sign in with your account (tick Remember me)"
  running || start_steam
  ;;
open)
  need_steam
  if running; then steam_cmd steam://open/main; else start_steam; fi
  ;;
download)
  need_steam
  apps=$(apps_of "${2:-}"); [ -n "$apps" ] || die "unknown game: ${2:-}"
  ensure_running
  for a in $apps; do
    [ "$(app_state "$a")" = missing ] || continue
    steam_cmd "steam://install/$a"; sleep 2
  done
  ;;
download-all)
  need_steam
  ensure_running
  # Steam queues the downloads; its install dialogs come one after another
  for id in $(catalog | awk '{print $1}'); do
    for a in $(apps_of "$id"); do
      [ "$(app_state "$a")" = missing ] || continue
      step "Asking Steam to download $id ($a)"
      steam_cmd "steam://install/$a"; sleep 4
    done
  done
  step "Confirm each download in Steam's window"
  ;;
# A game's tools (Black Ops III: Mod Tools), only when asked for: Steam's
# install dialog for that app (Steam checks the account may have it)
download-tool)
  need_steam
  a=$(tool_of "${2:-}"); [ -n "$a" ] || die "no tools for: ${2:-}"
  ensure_running
  if [ "$(app_state "$a")" = missing ]; then steam_cmd "steam://install/$a"; fi
  ;;
store)
  need_steam
  read -r main _ <<< "$(apps_of "${2:-}")"; [ -n "${main:-}" ] || die "unknown game: ${2:-}"
  ensure_running
  steam_cmd "steam://store/$main"
  ;;
# The game's Steam Workshop page (mods and maps): Steam downloads what the
# player subscribes to and the game lists it (Black Ops III: its Mods menu)
workshop)
  need_steam
  read -r main _ <<< "$(apps_of "${2:-}")"; [ -n "${main:-}" ] || die "unknown game: ${2:-}"
  ensure_running
  steam_cmd "steam://url/SteamWorkshopPage/$main"
  ;;
start)
  need_steam
  running || start_steam -silent
  ;;
wait)
  for _ in $(seq 1 90); do signed_in && exit 0; sleep 2; done
  die "Steam did not sign in: sign in in Steam's window (tick Remember me), then try again"
  ;;
gamedir) gamedir "${2:?appid}" ;;
state) app_state "${2:?appid}" ;;
launch) steam_cmd -applaunch "${2:?appid}" ;;
*)
  die "usage: steam.sh status | library | setup | open | download <id> | download-all | download-tool <id> | store <id> | workshop <id> | start | wait | gamedir <appid> | state <appid> | launch <appid>"
  ;;
esac
