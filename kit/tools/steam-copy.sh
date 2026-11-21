# Siliconium: the copies of Steam games that community clients play from
# (CoD4X: tools/cod4x.sh, IW7-Mod: tools/iw7mod.sh), sourced by them. Also run:
#
#   steam-copy.sh tidy                    every copy nobody is using: Steam's
#                                         files leave it (launch.sh before a
#                                         start, the app when it opens)
#   steam-copy.sh release <client> <copy> <generation> [seconds]
#                                         after a game (launch.sh): the same for
#                                         that copy, after a wait, unless it was
#                                         made again or is in use meanwhile
#   steam-copy.sh release-all <client>    (uninstall.sh) every copy of a client
#
# Steam's own game folder is never changed. A client that must change or add
# files in it (CoD4X replaces iw3mp.exe and mss32.dll, IW7-Mod adds
# iw7-mod.exe) plays from a copy of it in Siliconium's folder, made with APFS
# clones at each start: a whole game in a fraction of a second and no disk
# space (Infinite Warfare, 1753 files, ~100 GB: 0.29 s; going through it file
# by file, as before, took 8.5 s). A minute after the game quits, Steam's files
# leave the copy again, so between games it holds only the client's own files
# (its executable, profile, saves, logs, what it downloaded). So:
#  - a game uninstalled in Steam gives its space back (the copy no longer
#    holds it); files Steam updates or removes are not held either;
#  - each start has Steam's files as they are now;
#  - Time Machine does not back the game up a second time: the copy is
#    excluded while it holds Steam's files (its sticky xattr, as tmutil
#    addexclusion writes it), then included again for the client's files.
# Which files are Steam's: the list made when the copy was cloned
# (.siliconium-steam-files: "f <file>" and "d <folder>"; empty between games).
# The client's are the ones its list below names (as they were kept before)
# and any file that did not come from Steam's folder. A copy made by an older
# Siliconium (no list) is read against Steam's folder as it is now.
# Without clones (Steam's library on another volume) the copy takes real
# space: CoD4X then keeps it between games and copies again only what Steam
# changed (IW7-Mod refuses instead, ~100 GB); Steam's files leave it once the
# game is no longer in Steam.

sil_copy_home=${home:-${SIL_HOME:-"$HOME/Library/Application Support/Siliconium"}}
sil_copy_error= sil_copy_dir= sil_copy_gen=
# com.apple.metadata:com_apple_backup_excludeItem = "com.apple.backupd" (bplist)
sil_copy_tm=62706C69737430305F1011636F6D2E6170706C652E6261636B75706408000000000000010100000000000000010000000000000000000000000000001C

# The client's own files in its copy (Siliconium's state files too)
sil_copy_own() {   # <client> <path in the copy>
  case "$2" in .siliconium-*) return 0 ;; esac
  case "$1" in
    cod4x) case "$2" in iw3mp.exe|mss32.dll|miles32.dll|players/*|__*|*.log) return 0 ;; esac ;;
    iw7mod) case "$2" in iw7-mod.exe|iw7-mod.exe.old|iw7-mod/*|players2/*|minidumps/*|*.log) return 0 ;; esac ;;
  esac
  return 1
}
# The client's game process (its copy is in use while it runs)
sil_copy_exe() { case "$1" in cod4x) echo 'iw3mp\.exe' ;; iw7mod) echo 'iw7-mod\.exe' ;; esac; }
sil_copy_main() { case "$1" in cod4x) echo iw3mp.exe ;; iw7mod) echo iw7_ship.exe ;; esac; }

sil_copy_files() {   # <folder>: its files, one path per line, sorted
  (cd "$1" && find . -mindepth 1 \( -type f -o -type l \) -print) | sed -e 's|^\./||' -e '/^\.siliconium-/d' | LC_ALL=C sort
}
sil_copy_list() {    # <client> <Steam's folder or its fresh copy>: Steam's files and folders
  local rel
  sil_copy_files "$2" | while IFS= read -r rel; do
    sil_copy_own "$1" "$rel" || printf 'f %s\n' "$rel"
  done
  (cd "$2" && find . -mindepth 1 -type d -print) | sed 's|^\./||' | LC_ALL=C sort | sed 's|^|d |'
}

# One change to a copy at a time (a start, the release after a game, tidy)
sil_copy_lock() {    # <copy>
  local l="$1.lock" p i empty=0
  for i in $(seq 1 120); do
    if mkdir "$l" 2> /dev/null; then echo $$ > "$l/pid"; return 0; fi
    p=$(cat "$l/pid" 2> /dev/null)
    if [ -n "$p" ]; then
      kill -0 "$p" 2> /dev/null || { rm -rf "$l"; continue; }   # its holder is gone
    else
      empty=$((empty + 1)); [ "$empty" -lt 60 ] || { rm -rf "$l"; continue; }
    fi
    sleep 0.5
  done
  return 1
}
sil_copy_unlock() { rm -rf "$1.lock"; }
# A change stopped half way (Siliconium quit, the Mac went off): the copy is
# the previous one or the new one, never lost
sil_copy_recover() { # <copy>
  [ ! -d "$1" ] && [ -d "$1.old" ] && mv "$1.old" "$1"
  [ -d "$1" ] && rm -rf "$1.old"
  rm -rf "$1.part"
}
# In use: a start that made it is still running, or the client's game is
sil_copy_busy() {    # <client> <copy>
  local p
  p=$(cat "$2/.siliconium-in-use" 2> /dev/null)
  [ -n "$p" ] && kill -0 "$p" 2> /dev/null && return 0
  pgrep -f "$(sil_copy_exe "$1")" > /dev/null && return 0
  return 1
}
# Steam's folder an older Siliconium's copy came from, when the game is there
sil_copy_source() {  # <client> <copy>
  local name=${2##*/} key s
  case "$1" in cod4x) key=COD4X_DIR ;; iw7mod) key=IW7MOD_DIR ;; *) return 1 ;; esac
  for s in "$(sed -n "s/^$key=//p" "$sil_copy_home/settings.conf" 2> /dev/null | tail -1)" \
           "$sil_copy_home/prefix-steam/drive_c/Program Files (x86)/Steam/steamapps/common/$name"; do
    [ -n "$s" ] && [ "${s##*/}" = "$name" ] && [ -f "$s/$(sil_copy_main "$1")" ] || continue
    case "$s/" in */steamapps/common/*) printf '%s\n' "$s"; return 0 ;; esac
  done
  return 1
}

# The client's files from the previous copy into the new one: its own files,
# and the files that neither were Steam's then nor are in Steam's folder now
# (a file of Steam's in both is Steam's current one, as before)
sil_copy_carry() {   # <client> <previous copy> <new copy>
  local client=$1 old=$2 new=$3 t rel d
  t=$(mktemp -d "${TMPDIR:-/tmp}/siliconium-copy.XXXXXX") || return 1
  sil_copy_files "$old" > "$t/old"
  sil_copy_files "$new" > "$t/new"
  if [ -f "$old/.siliconium-steam-files" ]; then
    sed -n 's/^f //p' "$old/.siliconium-steam-files" | LC_ALL=C sort > "$t/steam"
  else
    cp "$t/new" "$t/steam"
  fi
  { while IFS= read -r rel; do sil_copy_own "$client" "$rel" && printf '%s\n' "$rel"; done < "$t/old"
    LC_ALL=C comm -23 "$t/old" "$t/steam" | LC_ALL=C comm -23 - "$t/new"; } | LC_ALL=C sort -u > "$t/carry"
  while IFS= read -r rel; do
    d=$(dirname -- "$new/$rel")
    mkdir -p "$d" && rm -f "$new/$rel" || { rm -rf "$t"; return 1; }
    if [ -L "$old/$rel" ]; then
      ln -s "$(readlink "$old/$rel")" "$new/$rel"
    else
      cp -cp "$old/$rel" "$new/$rel" 2> /dev/null || cp -p "$old/$rel" "$new/$rel"
    fi || { rm -rf "$t"; return 1; }
  done < "$t/carry"
  # (empty folders the client made)
  (cd "$old" && find . -mindepth 1 -type d -empty -print) | sed 's|^\./||' |
    while IFS= read -r rel; do mkdir -p "$new/$rel"; done
  rm -rf "$t"
  return 0
}

# A full copy (no clones) brought up to date: what Steam changed is copied
# again, what Steam removed goes
sil_copy_sync_full() {   # <client> <Steam's folder> <copy>
  local client=$1 src=$2 dst=$3 s d rel
  while IFS= read -r -d '' s; do
    rel=${s#"$src"/}
    sil_copy_own "$client" "$rel" && continue
    d="$dst/$rel"
    [ -f "$d" ] && [ "$(stat -f '%z %m' "$s")" = "$(stat -f '%z %m' "$d")" ] && continue
    mkdir -p "$(dirname "$d")" && rm -f "$d" && { cp -cp "$s" "$d" 2> /dev/null || cp -p "$s" "$d"; } || return 1
  done < <(find "$src" -type f -print0)
  sil_copy_list "$client" "$src" > "$dst/.siliconium-steam-files.new" || return 1
  LC_ALL=C comm -23 <(sed -n 's/^f //p' "$dst/.siliconium-steam-files" 2> /dev/null | LC_ALL=C sort) \
    <(sed -n 's/^f //p' "$dst/.siliconium-steam-files.new" | LC_ALL=C sort) |
    while IFS= read -r rel; do rm -f "$dst/$rel"; done
  mv -f "$dst/.siliconium-steam-files.new" "$dst/.siliconium-steam-files"
}

# sil_copy_make <client> <Steam's folder> <copy>: the copy for this start,
# with Steam's current files and the client's own. Sets sil_copy_dir and
# sil_copy_gen when Steam's files are to leave it after the game (clones);
# sil_copy_error says why it failed ("clones": no APFS clones, for IW7-Mod).
sil_copy_make() {
  local client=$1 src=$2 dst=$3 part="$3.part" old="$3.old" full=
  sil_copy_error= sil_copy_dir= sil_copy_gen=
  case "$dst" in "$sil_copy_home/cod4x/"?*|"$sil_copy_home/iw7mod/"?*) ;; *) sil_copy_error="unexpected copy folder: $dst"; return 1 ;; esac
  mkdir -p "$(dirname "$dst")" || return 1
  sil_copy_lock "$dst" || { sil_copy_error="Siliconium is still updating its copy of the game: press Play again in a moment."; return 1; }
  sil_copy_recover "$dst"
  if ! cp -cRp "$src" "$part" 2> /dev/null; then
    rm -rf "$part"
    if [ "$client" != cod4x ]; then sil_copy_error=clones; sil_copy_unlock "$dst"; return 1; fi
    if [ -f "$dst/.siliconium-full-copy" ]; then   # kept between games: brought up to date
      sil_copy_sync_full "$client" "$src" "$dst" || { sil_copy_unlock "$dst"; return 1; }
      printf '%s\n' "$src" > "$dst/.siliconium-full-copy"
      echo $$ > "$dst/.siliconium-in-use"
      sil_copy_unlock "$dst"
      return 0
    fi
    printf '==> %s\n' "Copying Call of Duty 4 for CoD4X (Steam's library is on another disk: Steam's files stay untouched)"
    cp -Rp "$src" "$part" || { rm -rf "$part"; sil_copy_unlock "$dst"; return 1; }
    full=1
  fi
  sil_copy_list "$client" "$part" > "$part/.siliconium-steam-files" &&
    { [ ! -d "$dst" ] || sil_copy_carry "$client" "$dst" "$part"; } || {
    rm -rf "$part"; sil_copy_unlock "$dst"; return 1; }
  if [ -n "$full" ]; then printf '%s\n' "$src" > "$part/.siliconium-full-copy"; fi
  echo $$ > "$part/.siliconium-in-use"
  # Time Machine: Steam's files are backed up from Steam's folder already
  xattr -wx com.apple.metadata:com_apple_backup_excludeItem "$sil_copy_tm" "$part" 2> /dev/null
  if [ -d "$dst" ]; then mv "$dst" "$old" || { rm -rf "$part"; sil_copy_unlock "$dst"; return 1; }; fi
  if ! mv "$part" "$dst"; then
    [ -d "$old" ] && mv "$old" "$dst"
    rm -rf "$part"; sil_copy_unlock "$dst"; return 1
  fi
  rm -rf "$old"
  if [ -z "$full" ]; then
    sil_copy_dir=$dst
    sil_copy_gen=$(stat -f %i "$dst/.siliconium-steam-files")
  fi
  sil_copy_unlock "$dst"
  return 0
}

# sil_copy_release <client> <copy> [generation]: Steam's files leave the copy
# (a full copy only when the game is no longer in Steam). Nothing happens
# while it is in use, or when it was made again since <generation>.
sil_copy_release() {
  local client=$1 dst=$2 gen=${3:-} list="$2/.siliconium-steam-files" src
  [ -d "$dst" ] || return 0
  # (between games already: only the client's files)
  [ -f "$list" ] && [ ! -s "$list" ] && [ ! -e "$dst/.siliconium-in-use" ] && [ ! -e "$dst.part" ] && [ ! -e "$dst.old" ] && return 0
  sil_copy_lock "$dst" || return 1
  sil_copy_recover "$dst"
  if [ -n "$gen" ] && [ "$(stat -f %i "$list" 2> /dev/null)" != "$gen" ]; then sil_copy_unlock "$dst"; return 1; fi
  if sil_copy_busy "$client" "$dst"; then sil_copy_unlock "$dst"; return 1; fi
  if [ -f "$dst/.siliconium-full-copy" ]; then
    src=$(cat "$dst/.siliconium-full-copy")
    if [ -f "$src/$(sil_copy_main "$client")" ]; then
      rm -f "$dst/.siliconium-in-use"; sil_copy_unlock "$dst"; return 0
    fi
  elif [ ! -f "$list" ]; then
    # an older Siliconium's copy: Steam's files are those in Steam's folder now
    src=$(sil_copy_source "$client" "$dst") || { sil_copy_unlock "$dst"; return 1; }
    sil_copy_list "$client" "$src" > "$list" || { rm -f "$list"; sil_copy_unlock "$dst"; return 1; }
  fi
  (cd "$dst" && sed -n 's/^f //p' "$list" | tr '\n' '\0' | xargs -0 rm -f --) &&
    (cd "$dst" && sed -n 's/^d //p' "$list" | LC_ALL=C sort -r | tr '\n' '\0' | xargs -0 rmdir 2> /dev/null; true) || {
    sil_copy_unlock "$dst"; return 1; }
  : > "$list"
  rm -f "$dst/.siliconium-in-use" "$dst/.siliconium-full-copy"
  xattr -d com.apple.metadata:com_apple_backup_excludeItem "$dst" 2> /dev/null
  sil_copy_unlock "$dst"
  return 0
}

sil_copy_tidy() {    # [client]: every copy (of that client)
  local client c base
  for client in ${1:-cod4x iw7mod}; do
    for c in "$sil_copy_home/$client"/*; do
      [ -d "$c" ] || continue
      case "${c##*/}" in
        kept|*.lock) continue ;;
        *.part|*.old)   # left by a start stopped half way, with no copy beside it
          base=${c%.*}
          if [ ! -d "$base" ] && sil_copy_lock "$base"; then sil_copy_recover "$base"; sil_copy_unlock "$base"; fi
          continue ;;
      esac
      sil_copy_release "$client" "$c" || true
    done
  done
}

# Run (not sourced)
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  set -uo pipefail
  case "${1:-}" in
    tidy) sil_copy_tidy ;;
    release-all) sil_copy_tidy "${2:?client}" ;;
    release)
      [ -n "${5:-}" ] && sleep "$5"
      sil_copy_release "${2:?client}" "${3:?copy}" "${4:-}" ;;
    *) echo "usage: steam-copy.sh tidy | release <client> <copy> <generation> [seconds] | release-all <client>" >&2; exit 2 ;;
  esac
  exit 0
fi
