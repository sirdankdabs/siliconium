#!/bin/bash
# Siliconium: IW4X's local player stats (players/iw4x.stat) in one zip.
#
#   iw4-stats.sh backup <folder>   saves the stats in one zip there
#   iw4-stats.sh restore <zip>     puts a backup back (close IW4X first);
#                                  what it replaces goes to the Trash
#
# Progress lines start with "==> "; errors with "ERROR: ".
set -uo pipefail
home=${SIL_HOME:-"$HOME/Library/Application Support/Siliconium"}
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/tools/migrate.sh"   # an install of the previous name
step() { printf '==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
dir=${IW4_DIR:-}
if [ -z "$dir" ] && [ -f "$home/settings.conf" ]; then
  dir=$(sed -n 's/^IW4_DIR=//p' "$home/settings.conf" | tail -1)
fi
[ -d "$dir/players" ] || die "choose the Modern Warfare 2 (IW4X) folder first"
stat_file="$dir/players/iw4x.stat"
trash() {
  [ -e "$1" ] || return 0
  mkdir -p "$HOME/.Trash"
  mv "$1" "$HOME/.Trash/$(basename "$1") (Siliconium $(date '+%Y-%m-%d %H.%M.%S'))"
}

case "${1:-}" in
backup)
  out=${2:-}
  [ -d "$out" ] || die "choose a folder for the backup"
  [ -f "$stat_file" ] || die "there are no stats yet: play IW4X once first"
  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
  b="$tmp/IW4X Stats"
  mkdir -p "$b/players"
  ditto --norsrc --noextattr "$stat_file" "$b/players/iw4x.stat"
  [ -f "$stat_file.bak" ] && cp -p "$stat_file.bak" "$b/players/"
  cat > "$b/README.txt" <<'TXT'
IW4X player stats, made by Siliconium.

players/iw4x.stat  XP, level, unlocks and challenges, as the IW4X client keeps
                   them locally (the game folder's players/ directory).
Restore with Siliconium's Restore Stats (close IW4X first); on Windows, copy it
into the game folder's players/ directory.

Your settings (iw4x_config.cfg) are not included, so restoring does not change
them. Keep this file private: it is your progress.
TXT
  find "$b" -name .DS_Store -delete
  zip_name="IW4X Stats $(date '+%Y-%m-%d %H.%M').zip"
  (cd "$tmp" && ditto -c -k --norsrc --noextattr --keepParent "IW4X Stats" "$out/$zip_name") ||
    die "cannot write the backup"
  step "Saved $out/$zip_name"
  ;;
restore)
  zip=${2:-}
  [ -f "$zip" ] || die "choose a backup zip"
  pgrep -f 'iw4x(-launcher)?\.exe' >/dev/null && die "quit IW4X first"
  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
  ditto -x -k "$zip" "$tmp" || die "this is not an IW4X stats backup"
  found=$(find "$tmp" -type f -name iw4x.stat -print -quit)
  [ -n "$found" ] || die "this is not an IW4X stats backup"
  trash "$stat_file"
  cp -p "$found" "$stat_file"
  [ -f "$(dirname "$found")/iw4x.stat.bak" ] && cp -p "$(dirname "$found")/iw4x.stat.bak" "$stat_file.bak"
  step "Stats restored"
  ;;
*)
  die "usage: iw4-stats.sh backup <folder> | restore <zip>"
  ;;
esac
