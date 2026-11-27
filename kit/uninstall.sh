#!/bin/bash
# Siliconium: remove a game's setup so it can be set up again from scratch.
# Everything removed goes to the Trash (nothing is deleted for good), and the
# games themselves are never touched.
#
#   uninstall.sh waw    forget the World at War folder
#   uninstall.sh bo1    forget the Black Ops folder; its shader caches go
#   uninstall.sh bo2    forget the Black Ops II folder
#   uninstall.sh iw5    forget the Modern Warfare 3 folder
#   uninstall.sh iw4    forget the Modern Warfare 2 (IW4X) folder
#   uninstall.sh cod4x  forget the Call of Duty 4 (CoD4X) folder; CoD4X's copy of
#                       a Steam download goes to the Trash
#   uninstall.sh iw7mod forget the Infinite Warfare (IW7-Mod) folder and its
#                       switches; IW7-Mod's copy of a Steam download goes to
#                       the Trash (its profile and saves are kept)
#   uninstall.sh iw6    forget the Ghosts folder and trash its campaign prefix
#   uninstall.sh boiii  forget the Black Ops III (Windows) folder
#   uninstall.sh bo2s   Black Ops II campaign through Steam: Steam's prefix
#                       (Steam, its sign-in, the game it downloaded) to the Trash
#   uninstall.sh bo2c   the offline Black Ops II campaign of Siliconium 1.0-1.2.0:
#                       puts the original t6sp.exe back and removes its Wine
#                       prefixes; the game itself stays
#   uninstall.sh all    the engine, the Wine prefix (Plutonium and its login),
#                       caches, logs and settings: Black Ops and Black Ops II
#                       both start from the beginning (Black Ops III untouched)
#   uninstall.sh bo3    BO3 Mac Client: Steam's launcher goes back into the
#                       game, BO3MacFix and the server browser go; the identity
#                       key is kept for the next install
#
# Progress lines start with "==> "; errors with "ERROR: ".
set -uo pipefail
kit=$(cd -- "$(dirname -- "$0")" && pwd)
home=${SIL_HOME:-"$HOME/Library/Application Support/Siliconium"}
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/tools/migrate.sh"   # an install of the previous name
step() { printf '==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# Move to the Trash under a unique name.
trash() {
  local p=$1 name
  [ -e "$p" ] || return 0
  name="$(basename "$p") (Siliconium $(date '+%Y-%m-%d %H.%M.%S'))"
  mkdir -p "$HOME/.Trash"
  mv "$p" "$HOME/.Trash/$name" || die "cannot move $p to the Trash"
}
forget() {  # remove settings.conf lines
  local k
  [ -f "$home/settings.conf" ] || return 0
  for k in "$@"; do sed -i '' "/^$k=/d" "$home/settings.conf"; done
}
stop_games() { [ -x "$kit/launch.sh" ] && bash "$kit/launch.sh" stop >/dev/null 2>&1; true; }

case "${1:-}" in
waw)
  stop_games
  step "Removing the World at War setup"
  forget WAW_DIR
  step "World at War can be set up again"
  ;;
bo1)
  stop_games
  step "Removing the Black Ops setup"
  forget BO1_DIR
  trash "$home/cache/plutonium-bootstrapper-win32.dxvk-cache"
  for f in "$home"/engine/lib64/mvkcache.bin.*; do trash "$f"; done
  step "Black Ops can be set up again"
  ;;
boiii)
  stop_games
  step "Removing the Black Ops III (Windows) setup"
  forget BOIII_DIR
  step "Black Ops III (Windows) can be set up again"
  ;;
bo2s)
  WINEPREFIX="$home/prefix-steam" "$home/engine/bin/wineserver" -k 2>/dev/null
  step "Removing Steam for Windows and its campaign"
  [ -d "$home/prefix-steam" ] && trash "$home/prefix-steam"
  step "Steam's prefix is in the Trash"
  ;;
bo2c)
  WINEPREFIX="$home/prefix-bo2c" "$home/engine/bin/wineserver" -k 2>/dev/null
  step "Removing the Black Ops II campaign setup"
  g=$(sed -n 's/^BO2C_DIR=//p' "$home/settings.conf" 2>/dev/null | tail -1)
  if [ -n "$g" ] && [ -d "$g" ]; then
    if [ -f "$g/t6sp.exe.steam" ]; then
      step "Putting the original t6sp.exe back"
      mv -f "$g/t6sp.exe.steam" "$g/t6sp.exe"
    fi
    rm -f "$g/steam_appid.txt"
    if [ -d "$g/Plugins.campaign-off" ] && [ ! -d "$g/Plugins" ]; then
      mv "$g/Plugins.campaign-off" "$g/Plugins"
    fi
    if [ -f "$g/players/.sil-defaults-hardware" ]; then
      trash "$g/players/hardware.chp"; rm -f "$g/players/.sil-defaults-hardware"
    fi
  fi
  forget BO2C_DIR
  trash "$home/prefix-bo2c"
  trash "$home/prefix-steamless"
  trash "$home/campaign"
  step "The campaign can be set up again"
  ;;
bo2)
  stop_games
  step "Removing the Black Ops II setup"
  forget BO2_DIR BO2_MODS
  step "Black Ops II can be set up again"
  ;;
iw5)
  stop_games
  step "Removing the Modern Warfare 3 setup"
  forget IW5_DIR
  step "Modern Warfare 3 can be set up again"
  ;;
iw4)
  stop_games
  step "Removing the Modern Warfare 2 setup"
  forget IW4_DIR
  step "Modern Warfare 2 can be set up again"
  ;;
cod4x)
  stop_games
  step "Removing the CoD4X setup"
  forget COD4X_DIR
  # CoD4X's copy of Steam's Call of Duty 4 (APFS clones, made again by Play);
  # CoD4X's profiles and identity stay in Steam's prefix (AppData\Local\CallofDuty4MW).
  # Steam's files leave it first, so the Trash never holds the game itself
  bash "$kit/tools/steam-copy.sh" release-all cod4x > /dev/null 2>&1
  trash "$home/cod4x"
  step "CoD4X can be set up again"
  ;;
iw7mod)
  stop_games
  step "Removing the IW7-Mod setup"
  forget IW7MOD_DIR IW7MOD_DXMT_FIX IW7MOD_SCREEN IW7MOD_DISPLAY_MODE IW7MOD_ASYNC IW7MOD_FRAME_PACING STEAM_MOD_IW
  # its download, and its APFS copies of Steam's Infinite Warfare (made again
  # by Play); each copy's iw7-mod folder (profile, saves) is kept and comes
  # back with the next copy. A folder the player chose keeps iw7-mod.exe;
  # IW7-Mod's identity and data stay in Steam's prefix. Steam's files leave
  # the copies first, so the Trash never holds the game itself
  bash "$kit/tools/steam-copy.sh" release-all iw7mod > /dev/null 2>&1
  trash "$home/mods/iw7mod"
  for c in "$home/iw7mod"/*; do
    [ -d "$c/iw7-mod" ] || continue
    mkdir -p "$home/iw7mod/kept/${c##*/}" && trash "$home/iw7mod/kept/${c##*/}/iw7-mod" &&
      mv "$c/iw7-mod" "$home/iw7mod/kept/${c##*/}/iw7-mod"
  done
  for c in "$home/iw7mod"/*; do [ "${c##*/}" = kept ] || trash "$c"; done
  step "IW7-Mod can be set up again"
  ;;
iw6)
  [ ! -d "$home/prefix-iw6" ] ||
    WINEPREFIX="$home/prefix-iw6" "$home/engine/bin/wineserver" -k 2>/dev/null
  step "Removing the Ghosts campaign setup"
  forget IW6_DIR IW6_ASYNC IW6_FRAME_PACING IW6_CAPTURE_DISPLAY IW6_MAXFPS
  trash "$home/prefix-iw6"
  step "Ghosts can be set up again"
  ;;
all)
  stop_games
  step "Removing the engine, Plutonium and settings"
  for d in engine prefix cache logs downloads; do trash "$home/$d"; done
  # BO3's choice stays with BO3
  if [ -f "$home/settings.conf" ]; then
    grep '^BO3_' "$home/settings.conf" > "$home/settings.keep" || true
    trash "$home/settings.conf"
    if [ -s "$home/settings.keep" ]; then mv "$home/settings.keep" "$home/settings.conf"; else rm -f "$home/settings.keep"; fi
  fi
  step "Black Ops, Black Ops II, Modern Warfare 2 and Modern Warfare 3 can be set up again"
  ;;
bo3)
  pgrep -f CoDBlkOps3_Exe >/dev/null && die "quit Black Ops III first"
  osascript -e 'quit app id "io.github.bo3macclient"' >/dev/null 2>&1
  g=$(bash "$kit/bo3.sh" status 2>/dev/null | sed -n 's/^game=//p')
  step "Removing BO3 Mac Client"
  if [ -n "$g" ] && [ -d "$g/BO3MacFix" ]; then
    # keep the identity key (rank and VIP on community servers): the
    # installer restores identity-key-*.dat from bo3/Personal
    if [ -f "$g/BO3MacFix/boiii_key.dat" ]; then
      mkdir -p "$home/bo3/Personal"
      cp -p "$g/BO3MacFix/boiii_key.dat" "$home/bo3/Personal/identity-key-saved.dat"
      step "Identity key kept in Siliconium/bo3/Personal"
    fi
    m="$g/CoDBlkOps3.app/Contents/MacOS"
    if [ -f "$m/AppBundleExe_backup" ]; then
      mv -f "$m/AppBundleExe_backup" "$m/AppBundleExe" || die "cannot restore Steam's launcher"
      step "Steam's launcher is back in the game"
    fi
    trash "$g/BO3MacFix"
  fi
  trash "$home/bo3/T7 Server Browser.app"
  rm -f "$home/bo3/version"
  step "BO3 Mac Client removed"
  ;;
*)
  die "usage: uninstall.sh waw | bo1 | bo2 | iw5 | iw4 | cod4x | iw7mod | iw6 | bo2s | bo2c | boiii | all | bo3"
  ;;
esac
