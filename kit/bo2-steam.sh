#!/bin/bash
# Siliconium: Black Ops II's campaign through Steam for Windows. Steam runs in its
# own Wine prefix (prefix-steam), separate from the other games; the player
# signs in with their account and downloads Black Ops II there, and Steam
# starts the game (and checks its license) when the campaign is played.
#
#   bo2-steam.sh status      steam=installed|missing  signedin=yes|no
#                            running=yes|no  game=installed|downloading|missing
#                            dir=<game folder>
#   bo2-steam.sh setup       creates prefix-steam, installs Steam for Windows
#                            (Valve's installer) and opens it to sign in
#   bo2-steam.sh open        opens Steam's window (sign in, downloads)
#   bo2-steam.sh download    opens Steam's install dialog for Black Ops II
#   bo2-steam.sh start       starts Steam in the background if it isn't open
#   bo2-steam.sh wait        waits (up to 3 minutes) until Steam is signed in
#   bo2-steam.sh gamedir     the game's folder (empty if not installed)
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
appid=202970
step() { printf '==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# signed in now: Steam's latest connection state is "Logged On"
signed_in() {
  grep -oE '^\[[^]]+\] \[[A-Za-z ]+,' "$steamdir/logs/connection_log.txt" 2>/dev/null | tail -1 | grep -q 'Logged On'
}
running() { pgrep -f 'Program Files \(x86\)\\Steam\\[Ss]team\.exe' >/dev/null 2>&1; }

# The game's folder: the library (Steam's own or another one) holding its manifest
manifest() {
  local lib
  { printf '%s\n' "C:\\\\Program Files (x86)\\\\Steam"
    sed -n -E 's/^[[:space:]]*"path"[[:space:]]*"(.*)"/\1/p' "$steamdir/steamapps/libraryfolders.vdf" 2>/dev/null
  } | while IFS= read -r lib; do
    lib=${lib//\\\\/\\}; lib=${lib#[Cc]:}; lib="$WINEPREFIX/drive_c${lib//\\//}"
    [ -f "$lib/steamapps/appmanifest_$appid.acf" ] && { echo "$lib/steamapps/appmanifest_$appid.acf"; break; }
  done
}
gamedir() {
  local m dir
  m=$(manifest); [ -n "$m" ] || return 0
  dir=$(sed -n -E 's/^[[:space:]]*"installdir"[[:space:]]*"(.*)"/\1/p' "$m")
  [ -n "$dir" ] && echo "$(dirname "$m")/common/$dir"
}
# StateFlags 4 = fully installed (other values: downloading, update needed…)
game_state() {
  local m flags dir
  m=$(manifest); [ -n "$m" ] || { echo missing; return; }
  flags=$(sed -n -E 's/^[[:space:]]*"StateFlags"[[:space:]]*"([0-9]+)"/\1/p' "$m")
  dir=$(gamedir)
  if [ "$flags" = 4 ] && [ -f "$dir/t6sp.exe" ]; then echo installed; else echo downloading; fi
}

# Steam's web windows draw with the engine's steamwebhelper fix (ntdll); the
# GPU and the sandbox stay off. The in-game overlay is off: it is injected
# into the game and does not render under Wine (Steam may restore the files
# when it updates itself, so this runs every time).
start_steam() {
  . "$kit/tools/configure-ds4.sh"
  configure_ds4_xinput || printf '%s\n' 'Warning: could not set up PlayStation controller XInput mapping.' >&2
  for f in GameOverlayRenderer.dll GameOverlayRenderer64.dll; do
    [ -f "$steamdir/$f" ] && mv -f "$steamdir/$f" "$steamdir/$f.off"
  done
  (cd "$steamdir" && nohup "$wine" Steam.exe "$@" -cef-disable-gpu -cef-disable-gpu-compositing \
    -cef-disable-sandbox > "$home/logs/bo2-steam.log" 2>&1 &)
}
# a URL or command for the Steam that is open (or a new one)
steam_cmd() { (cd "$steamdir" && "$wine" Steam.exe "$@" > /dev/null 2>&1 &); }

case "${1:-}" in
status)
  [ -f "$steamdir/Steam.exe" ] && echo "steam=installed" || echo "steam=missing"
  signed_in && echo "signedin=yes" || echo "signedin=no"
  running && echo "running=yes" || echo "running=no"
  echo "game=$(game_state)"
  echo "dir=$(gamedir)"
  ;;
setup)
  [ -x "$wine" ] || die "install the Siliconium engine first"
  mkdir -p "$downloads"
  if [ ! -f "$WINEPREFIX/system.reg" ]; then
    step "Creating Steam's own Wine prefix"
    WINEDLLOVERRIDES="mscoree,mshtml=" "$wine" wineboot --init > "$home/logs/bo2-steam-wineboot.log" 2>&1
    "$WINESERVER" -w
    [ -f "$WINEPREFIX/system.reg" ] || die "Wine could not create Steam's prefix (see logs/bo2-steam-wineboot.log)"
  fi
  if [ ! -f "$steamdir/Steam.exe" ]; then
    step "Downloading Steam for Windows (Valve)"
    curl -fsSL --retry 3 -o "$downloads/SteamSetup.exe.part" \
      https://cdn.cloudflare.steamstatic.com/client/installer/SteamSetup.exe || die "cannot download Steam"
    mv -f "$downloads/SteamSetup.exe.part" "$downloads/SteamSetup.exe"
    strings -a "$downloads/SteamSetup.exe" | grep -q "Valve Corp" || die "unexpected Steam installer"
    step "Installing Steam for Windows"
    "$wine" "$downloads/SteamSetup.exe" /S > /dev/null 2>&1
    "$WINESERVER" -w
    [ -f "$steamdir/Steam.exe" ] || die "Steam did not install"
  fi
  step "Opening Steam: sign in with your account (tick Remember me), then download Black Ops II"
  running || start_steam
  ;;
open)
  [ -f "$steamdir/Steam.exe" ] || die "Steam is not installed"
  if running; then steam_cmd steam://open/main; else start_steam; fi
  ;;
download)
  [ -f "$steamdir/Steam.exe" ] || die "Steam is not installed"
  if ! running; then
    # a Steam that is starting drops the request: wait until it has signed in
    seen=$(wc -l < "$steamdir/logs/connection_log.txt" 2>/dev/null | tr -d ' '); seen=${seen:-0}
    start_steam
    for _ in $(seq 1 90); do
      tail -n +$((seen + 1)) "$steamdir/logs/connection_log.txt" 2>/dev/null | grep -q '\[Logged On,' && break
      sleep 2
    done
    sleep 3
  fi
  steam_cmd "steam://install/$appid"
  ;;
start)
  [ -f "$steamdir/Steam.exe" ] || die "Steam is not installed"
  running || start_steam -silent
  ;;
wait)
  for _ in $(seq 1 90); do signed_in && exit 0; sleep 2; done
  die "Steam did not sign in: sign in in Steam's window (tick Remember me), then press Play Campaign again"
  ;;
gamedir)
  gamedir
  ;;
launch)
  steam_cmd -applaunch "$appid"
  ;;
*)
  die "usage: bo2-steam.sh status | setup | open | download | start | wait | gamedir | launch"
  ;;
esac
