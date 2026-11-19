#!/bin/bash
# Siliconium: Black Ops II's campaign through Steam for Windows, on the shared
# Steam of steam.sh (prefix-steam). Same commands as before:
#
#   bo2-steam.sh status      steam=installed|missing  signedin=yes|no
#                            running=yes|no  game=installed|downloading|missing
#                            dir=<game folder>
#   bo2-steam.sh setup | open | start | wait     as steam.sh
#   bo2-steam.sh download    opens Steam's install dialog for Black Ops II
#   bo2-steam.sh gamedir     the game's folder (empty if not installed)
#   bo2-steam.sh launch      asks Steam to start the campaign
set -uo pipefail
kit=$(cd -- "$(dirname -- "$0")" && pwd)
s="$kit/steam.sh"
appid=202970
case "${1:-}" in
status)
  bash "$s" status
  dir=$(bash "$s" gamedir "$appid")
  st=$(bash "$s" state "$appid")
  [ "$st" = installed ] && [ ! -f "$dir/t6sp.exe" ] && st=downloading
  echo "game=$st"
  echo "dir=$dir"
  ;;
download) exec bash "$s" download bo2 ;;
gamedir) exec bash "$s" gamedir "$appid" ;;
launch) exec bash "$s" launch "$appid" ;;
setup | open | start | wait) exec bash "$s" "$1" ;;
*) printf 'ERROR: %s\n' "usage: bo2-steam.sh status | setup | open | download | start | wait | gamedir | launch" >&2; exit 1 ;;
esac
