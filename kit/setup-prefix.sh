#!/bin/bash
# Siliconium: the Wine prefix the games run in, with Plutonium.
#
#   setup-prefix.sh init                    new prefix only (no Plutonium)
#   setup-prefix.sh init-iw6                isolated Ghosts campaign prefix
#   setup-prefix.sh setup <game> <folder> [installer folder]
#                                           sign in once and link the selected game
#   setup-prefix.sh import <prefix>         copy an existing prefix (keeps the
#                                           Plutonium login and game settings)
#   setup-prefix.sh plutonium <game folder> (re)install Plutonium in the prefix
#
# Progress lines start with "==> "; errors with "ERROR: ".
set -uo pipefail
kit=$(cd -- "$(dirname -- "$0")" && pwd)
home=${SIL_HOME:-"$HOME/Library/Application Support/Siliconium"}
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/tools/migrate.sh"   # an install of the previous name
engine="$home/engine"
export WINEPREFIX="$home/prefix" CX_ROOT="$engine" WINESERVER="$engine/bin/wineserver"
export WINEDLLPATH="$engine/lib/wine/x86_64-windows:$engine/lib/wine/x86_64-unix"
# plutonium.exe (Plutonium's installer, downloaded from plutonium.pw) is a .NET program: keep Wine Mono on
# here (launch.sh turns it off for the games and the launcher, which are not).
export WINEMSYNC=1 WINEDEBUG=-all WINEDLLOVERRIDES="mshtml="
if [ "${1:-}" = init-iw6 ]; then
  export WINEPREFIX="$home/prefix-iw6" WINEDLLOVERRIDES="mscoree,mshtml="
fi
wine="$engine/lib/wine/x86_64-unix/wine"
plutonium="$WINEPREFIX/drive_c/users/crossover/AppData/Local/Plutonium"
cfg="$plutonium/config.json"
. "$kit/tools/winpath.sh"
. "$kit/tools/dl-progress.sh"
step() { printf '==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[ -x "$wine" ] || die "install the engine first"
mkdir -p "$home/logs"

plutonium_ready() {
  [ -f "$plutonium/bin/plutonium-launcher-win32.exe" ] &&
    [ -f "$plutonium/bin/plutonium-bootstrapper-win32.exe" ] &&
    /usr/bin/python3 -I "$kit/tools/plutonium-config.py" signed-in "$cfg"
}

init_prefix() {
  local log=${1:-wineboot.log}
  if [ ! -f "$WINEPREFIX/system.reg" ] || [ ! -d "$WINEPREFIX/drive_c" ]; then
    step "Creating the Wine prefix"
    "$wine" wineboot --init > "$home/logs/$log" 2>&1 ||
      die "Wine could not create the prefix (see logs/$log)"
    "$WINESERVER" -w 2>/dev/null
    [ -f "$WINEPREFIX/system.reg" ] && [ -d "$WINEPREFIX/drive_c" ] ||
      die "Wine could not create the prefix (see logs/$log)"
  fi
}

# Plutonium's official installer (the "Download" button on plutonium.pw)
plutonium_url=https://cdn.plutonium.pw/updater/plutonium.exe

# fetch_plutonium <file>: download the official installer; checks it is a
# Windows program of a sane size before it is used
fetch_plutonium() {
  local out=$1 tmp size
  tmp="$out.part"
  curl -fsSL --proto '=https' --tlsv1.2 --retry 3 --connect-timeout 15 -o "$tmp" "$plutonium_url" || { rm -f "$tmp"; return 1; }
  size=$(stat -f %z "$tmp" 2>/dev/null || echo 0)
  if [ "$size" -lt 1000000 ] || [ "$size" -gt 64000000 ] || [ "$(head -c 2 "$tmp")" != MZ ]; then
    rm -f "$tmp"; return 1
  fi
  mv -f "$tmp" "$out"
}

install_plutonium() {
  local game=${1:-}
  init_prefix
  # Run the installer from a copy in Siliconium's own folder: Plutonium's
  # installer is a .NET program, and .NET cannot open a file below a folder
  # whose name Windows does not allow (a trailing space, as in "CoD ", or a
  # dot): it crashed with DirectoryNotFoundException before its window opened.
  # It is an updater that writes plutonium.new.exe next to itself; keep that
  # out of the game folder too.
  local stage="$home/cache/plutonium-installer"
  rm -rf "$stage"; mkdir -p "$stage" || die "could not prepare Plutonium's installer"
  # The latest installer from plutonium.pw, as for boiii.exe; a plutonium.exe
  # in the game folder is only used when plutonium.pw cannot be reached.
  step "Downloading Plutonium's installer from plutonium.pw"
  if ! fetch_plutonium "$stage/plutonium.exe"; then
    if [ -n "$game" ] && [ -f "$game/plutonium.exe" ]; then
      step "plutonium.pw could not be reached: using the plutonium.exe in the game folder"
      cp "$game/plutonium.exe" "$stage/plutonium.exe" || die "could not copy plutonium.exe from $game"
    else
      die "could not download Plutonium from plutonium.pw: check your internet connection and press Install again"
    fi
  fi
  step "Downloading Plutonium files… sign in when its window opens (Siliconium closes it automatically)"
  (cd "$stage" && exec "$wine" plutonium.exe) > "$home/logs/plutonium-install.log" 2>&1 &
  local installer=$! token= quiet= i p_t0= p_kb0=0 p_last_kb=0 p_kb p_now p_dt p_dkb p_mb p_spd p_rem p_eta p_extra p_ready_shown=0
  for i in $(seq 1 300); do
    if plutonium_ready; then token=1; break; fi
    # Stream live download progress & ETA while plutonium.exe fetches client files (~150 MB)
    if [ $((i % 2)) = 0 ] && [ -d "$plutonium" ]; then
      p_kb=$(du -sk "$plutonium" 2>/dev/null | awk '{print $1}'); p_kb=${p_kb:-0}
      if [ "$p_kb" -gt "$p_last_kb" ]; then
        p_now=$(date +%s)
        [ -z "$p_t0" ] && { p_t0=$p_now; p_kb0=$p_kb; }
        p_mb=$((p_kb / 1024))
        p_dt=$((p_now - p_t0))
        p_dkb=$((p_kb - p_kb0))
        p_extra=""
        if [ "$p_dt" -ge 2 ] && [ "$p_dkb" -gt 256 ]; then
          p_spd=$(awk -v d="$p_dkb" -v t="$p_dt" 'BEGIN { printf "%.1f MB/s", (d / 1024.0) / t }')
          if [ "$p_kb" -lt 153600 ]; then
            p_rem=$(( (153600 - p_kb) * p_dt / p_dkb ))
            p_extra=" ($p_spd · $(sil_fmt_eta "$p_rem"))"
          else
            p_extra=" ($p_spd)"
          fi
        fi
        step "Downloading Plutonium: ${p_mb} MB${p_extra} — sign in when its window opens"
        p_last_kb=$p_kb
      elif [ "$p_ready_shown" = 0 ] && [ -f "$plutonium/bin/plutonium-launcher-win32.exe" ]; then
        step "Plutonium downloaded: sign in in its window (Siliconium closes it automatically when you are in)"
        p_ready_shown=1
      fi
    fi
    # plutonium.exe is an updater: it downloads plutonium.new.exe and exits
    # before the new installer opens the launcher. Do not mistake that exit
    # for a failed install (which used to kill wineserver too early).
    if pgrep -f 'plutonium(\.new)?\.exe|plutonium-(launcher|bootstrapper)-win32\.exe' >/dev/null 2>&1; then
      quiet=0
    else
      quiet=$((quiet + 1))
      [ "$quiet" -ge 30 ] && break
    fi
    sleep 1
  done
  if [ -n "$token" ]; then
    step "Signed in to Plutonium; closing it"
    sleep 1   # let the launcher flush config.json
  fi
  "$WINESERVER" -k 2>/dev/null
  "$WINESERVER" -w 2>/dev/null
  wait "$installer" 2>/dev/null || true
  [ -f "$plutonium/bin/plutonium-launcher-win32.exe" ] ||
    die "Plutonium did not finish installing (see logs/plutonium-install.log)"
  plutonium_ready ||
    die "Plutonium is installed, but you did not sign in. Run Install again and sign in in Plutonium's window; Siliconium closes it when you are in."
  step "Plutonium installed and signed in"
}

case "${1:-}" in
init)
  # a prefix without Plutonium (Black Ops III for Windows through boiii)
  init_prefix
  step "Prefix ready"
  ;;
init-iw6)
  init_prefix iw6-wineboot.log
  step "Ghosts prefix ready"
  ;;
setup)
  game=${2:-}; folder=${3:-}; installer=${4:-$folder}
  case "$game" in
    t4|t5|t6|iw5) ;;
    *) die "unknown Plutonium game" ;;
  esac
  [ -n "$folder" ] && [ -d "$folder/zone" ] || die "choose the game folder containing zone/"
  if [ "$game" = iw5 ]; then
    [ -d "$folder/main" ] && [ -f "$folder/mss32.dll" ] || die "choose the 32-bit Modern Warfare 3 folder"
  fi
  if ! plutonium_ready; then install_plutonium "$installer"; fi
  /usr/bin/python3 -I "$kit/tools/plutonium-config.py" link "$cfg" "$game" "$(sil_winpath "$folder")" ||
    die "Could not save the game folder in Plutonium. Close Plutonium and try Install again."
  step "Game folder linked to Plutonium"
  ;;
create)
  game=${2:-}
  [ -d "$game/zone" ] || die "pick the game folder (the one with zone/)"
  install_plutonium "$game"
  ;;
import)
  src=${2:-}
  [ -f "$src/system.reg" ] && [ -d "$src/drive_c" ] || die "not a Wine prefix: $src"
  [ -e "$WINEPREFIX" ] && die "a prefix already exists in $WINEPREFIX"
  step "Copying the prefix (Plutonium login and game settings included)"
  cp -cR "$src" "$WINEPREFIX" 2>/dev/null || cp -R "$src" "$WINEPREFIX"
  step "Updating it for this engine"
  "$wine" wineboot -u > "$home/logs/wineboot.log" 2>&1
  "$WINESERVER" -w 2>/dev/null
  step "Prefix ready"
  ;;
plutonium)
  install_plutonium "${2:-}"
  ;;
*)
  die "usage: setup-prefix.sh init | init-iw6 | setup <game> <folder> [installer folder] | import <prefix>"
  ;;
esac
