#!/bin/bash
# Siliconium: Battle.net (Blizzard's desktop app for Windows), in its own Wine
# prefix (prefix-battlenet), apart from Steam and the other games. The player
# signs in with their Battle.net account and installs their Call of Duty games
# there (Black Ops 4 is sold only on Battle.net); Battle.net starts them (and
# checks their licences).
#
# Its own prefix, not Steam's: a game start stops everything in its prefix
# (launch.sh restarts the launcher so it and the game get Siliconium's
# settings), so in Steam's prefix every Steam game would have closed Battle.net
# and its downloads, and every Battle.net game Steam.
#
#   battlenet.sh status          battlenet=installed|missing  signedin=yes|no  running=yes|no
#   battlenet.sh library         one line per game in the catalog:
#                                <id>|<state>|<folder>   state: installed|downloading|missing
#   battlenet.sh setup           creates prefix-battlenet, downloads Blizzard's
#                                installer, installs Battle.net (its window) and
#                                opens it to sign in
#   battlenet.sh open            opens Battle.net's window (sign in, installs)
#   battlenet.sh download <id>   opens the game's page in Battle.net (Install there)
#   battlenet.sh start           starts Battle.net in the background if it isn't open
#   battlenet.sh wait            waits (up to 3 minutes) until Battle.net is signed in
#   battlenet.sh gamedir <id>    the game's folder (empty if not installed)
#   battlenet.sh state <id>      installed|downloading|missing
#   battlenet.sh launch <id>     asks Battle.net to start the game
#   battlenet.sh stop            closes Battle.net (everything in its prefix)
#
# Progress lines start with "==> "; errors with "ERROR: ".
set -uo pipefail
kit=$(cd -- "$(dirname -- "$0")" && pwd)
home=${SIL_HOME:-"$HOME/Library/Application Support/Siliconium"}
. "$kit/tools/migrate.sh"   # an install of the previous name
engine="$home/engine"
export WINEPREFIX="$home/prefix-battlenet" WINEMSYNC=1 WINEDEBUG=${WINEDEBUG:--all} CX_ROOT="$engine"
# Battle.net stays open in the background: its Wine server runs through a link
# outside the engine folder (as Steam's), so the app doesn't count it as a game
mkdir -p "$home/campaign" "$home/logs"
ln -sfn "$engine/bin/wineserver" "$home/campaign/wineserver"
export WINESERVER="$home/campaign/wineserver"
wine="$engine/lib/wine/x86_64-unix/wine"
. "$kit/tools/battlenet-games.sh"
# Battle.net runs from its own clone of the engine (bnet_use_engine, see
# tools/battlenet-games.sh), for every command that may start it
case "${1:-}" in setup|open|download|start|launch) bnet_use_engine ;; esac
downloads="$home/downloads"
step() { printf '==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

case "${1:-}" in
status)
  bnet_installed && echo "battlenet=installed" || echo "battlenet=missing"
  bnet_signed_in && echo "signedin=yes" || echo "signedin=no"
  bnet_running && echo "running=yes" || echo "running=no"
  ;;
library)
  bnet_catalog | while read -r id _; do
    printf '%s|%s|%s\n' "$id" "$(bnet_state "$id")" "$(bnet_gamedir "$id")"
  done
  ;;
setup)
  [ -x "$wine" ] || die "install the Siliconium engine first"
  if [ ! -f "$WINEPREFIX/system.reg" ]; then
    step "Creating Battle.net's own Wine prefix"
    WINEDLLOVERRIDES="mscoree,mshtml=" "$wine" wineboot --init > "$home/logs/battlenet-wineboot.log" 2>&1
    "$WINESERVER" -w
    [ -f "$WINEPREFIX/system.reg" ] || die "Wine could not create Battle.net's prefix (see logs/battlenet-wineboot.log)"
  fi
  bnet_prefix_settings
  if ! bnet_installed; then
    mkdir -p "$downloads"
    step "Downloading Battle.net for Windows (Blizzard)"
    curl -fsSL --retry 3 -o "$downloads/Battle.net-Setup.exe.part" \
      "https://www.battle.net/download/getInstallerForGame?os=win&gameProgram=BATTLENET_APP&version=Live" || {
      rm -f "$downloads/Battle.net-Setup.exe.part"; die "cannot download Battle.net"; }
    mv -f "$downloads/Battle.net-Setup.exe.part" "$downloads/Battle.net-Setup.exe"
    # Blizzard's signed installer (its signing certificate names the company).
    # grep reads the file itself: `strings | grep -q` ends strings early with
    # SIGPIPE, which pipefail counts as a failure (exit 141)
    LC_ALL=C grep -aq 'Blizzard Entertainment, Inc\.' "$downloads/Battle.net-Setup.exe" ||
      { rm -f "$downloads/Battle.net-Setup.exe"; die "unexpected Battle.net installer"; }
    step "Installing Battle.net: confirm in its window (Continue)"
    "$wine" "$downloads/Battle.net-Setup.exe" --lang=enUS \
      --installpath="C:\\Program Files (x86)\\Battle.net" > "$home/logs/battlenet-setup.log" 2>&1
    # (the installer opens Battle.net itself when it is done; Battle.net
    # updates itself, a new setup downloads the installer again)
    for _ in $(seq 1 300); do bnet_installed && break; sleep 2; done
    rm -f "$downloads/Battle.net-Setup.exe"; rmdir "$downloads" 2> /dev/null || true
    bnet_installed || die "Battle.net did not install (see logs/battlenet-setup.log)"
  fi
  step "Opening Battle.net: sign in with your account (tick Keep me logged in)"
  bnet_running || bnet_start_client
  ;;
open)
  bnet_installed || die "Battle.net is not installed: press Install Battle.net first"
  bnet_prefix_settings
  if bnet_running; then bnet_cmd; else bnet_start_client; fi
  ;;
download)
  bnet_installed || die "Battle.net is not installed: press Install Battle.net first"
  code=$(bnet_field "${2:-}" 3); [ -n "$code" ] || die "unknown game: ${2:-}"
  bnet_ensure_running
  bnet_cmd --game="$(bnet_field "$2" 2)"
  ;;
start)
  bnet_installed || die "Battle.net is not installed: press Install Battle.net first"
  bnet_prefix_settings
  # in the background (its window stays minimized), as Steam's -silent
  bnet_running || bnet_start_client --autostarted
  ;;
wait)
  for _ in $(seq 1 90); do bnet_signed_in && exit 0; sleep 2; done
  die "Battle.net did not sign in: sign in in Battle.net's window, then try again"
  ;;
gamedir) bnet_gamedir "${2:?id}" ;;
state) bnet_state "${2:?id}" ;;
launch)
  code=$(bnet_field "${2:-}" 3); [ -n "$code" ] || die "unknown game: ${2:-}"
  bnet_cmd --exec="launch $code"
  ;;
stop) "$WINESERVER" -k 2> /dev/null; "$WINESERVER" -w 2> /dev/null; true ;;
*)
  die "usage: battlenet.sh status | library | setup | open | download <id> | start | wait | gamedir <id> | state <id> | launch <id> | stop"
  ;;
esac
