#!/bin/bash
# Siliconium: update IW4X with its own launcher.
#
# Update the client and game data in the Steam MW2 folder without playing.
#
# Progress lines start with "==> "; errors with "ERROR: ".
set -uo pipefail
kit=$(cd -- "$(dirname -- "$0")" && pwd)
home=${SIL_HOME:-"$HOME/Library/Application Support/Siliconium"}
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/tools/migrate.sh"   # an install of the previous name
engine="$home/engine"
export WINEPREFIX="$home/prefix" CX_ROOT="$engine" WINESERVER="$engine/bin/wineserver"
export WINEDLLPATH="$engine/lib/wine/x86_64-windows:$engine/lib/wine/x86_64-unix"
export WINEMSYNC=1 WINEDEBUG=-all
wine="$engine/lib/wine/x86_64-unix/wine"
step() { printf '==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[ -x "$wine" ] || die "install the engine first"
[ -d "$WINEPREFIX/drive_c" ] || die "the Wine prefix is not set up"
mkdir -p "$home/logs"
dir=$(sed -n 's/^IW4_DIR=//p' "$home/settings.conf" 2>/dev/null | tail -1)
[ -n "$dir" ] || dir=$(sed -n 's/^OWN_MW2_DIR=//p' "$home/settings.conf" 2>/dev/null | tail -1)
[ -n "$dir" ] && [ -d "$dir" ] || die "choose the IW4X game folder first"
. "$kit/tools/iw4x.sh"
sil_iw4x_prepare "$dir" force || die "could not download the latest IW4X launcher"

. "$kit/tools/winpath.sh"
sil_winpath "$dir" > /dev/null   # a drive letter if Windows cannot name the folder
step "Verifying and updating IW4X files"
log="$home/logs/iw4-update.log"
: > "$log"
trap 'sil_iw4x_stop_watch' EXIT
sil_iw4x_watch_log "$log" 0 0
cd "$dir" || exit 1
"$wine" iw4x-launcher.exe --arch x86 --no-self-update --skip-launch --no-shortcuts --no-connect-protocol >> "$log" 2>&1 || {
  sil_iw4x_stop_watch
  die "the IW4X launcher could not update the game (see logs/iw4-update.log)"
}
sil_iw4x_stop_watch
step "IW4X is up to date"
