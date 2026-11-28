# Siliconium: Windows paths for Mac folders, sourced by the kit's scripts.
#
# Windows (and .NET/Mono programs in particular, like Plutonium's installer)
# cannot use a folder whose name ends in a space or a dot, or holds one of
# < > : " | ? * \ — macOS allows all of them. "Z:\Users\me\Downloads\CoD \Games"
# is read as "...\CoD\Games", which does not exist, so Plutonium's installer
# crashed with DirectoryNotFoundException before its window opened.
#
# Black Ops II (T6) also truncates long .ipak paths (~167 chars when installed
# in prefix-steam's steamapps/common and passed to Plutonium's prefix via Z:\),
# leaving blank menus and crashing with "ipak file not found: base" (issue #3).
#
# sil_winpath maps unsafe or long directory paths (> 80 Windows chars) through
# a drive letter of the current $WINEPREFIX:
#   - unsafe ancestor: deepest unsafe folder ("P:\Games\World At War")
#   - inside $WINEPREFIX/drive_c: native "C:\..." (no extra drive letter)
#   - long directory outside drive_c: parent folder when "<X>:\<basename>" fits
#     within 80 chars (so all Steam Library games in steamapps/common share one
#     drive letter, e.g. "P:\Call of Duty Black Ops II"), else the folder itself
#     ("P:\"). Wine matches drive roots by inode, so working directories follow.

# true when one path component cannot be represented on Windows
sil_component_unsafe() {
  case "$1" in
    *' '|*'.') [ "$1" != . ] && [ "$1" != .. ] ;;
    *[\<\>\:\"\|\?\*\\]*) return 0 ;;
    *) return 1 ;;
  esac
}

# the deepest unsafe ancestor (or the path itself) of an absolute path; empty if none
sil_unsafe_root() {
  local path=${1%/} prefix= rest comp root=
  rest=${path#/}
  while [ -n "$rest" ]; do
    comp=${rest%%/*}
    prefix="$prefix/$comp"
    sil_component_unsafe "$comp" && root=$prefix
    [ "$rest" = "$comp" ] && break
    rest=${rest#*/}
  done
  printf '%s' "$root"
}

# drive letter (lowercase, no colon) of $WINEPREFIX mapped to <dir>; makes one if needed
sil_drive_for() {
  local dir=$1 dd="$WINEPREFIX/dosdevices" l target
  [ -d "$dd" ] || return 1
  for l in p q r s t u v w x y o n m l k j i g; do
    target=$(readlink "$dd/$l:" 2>/dev/null) || continue
    [ "$target" = "$dir" ] && { printf '%s' "$l"; return 0; }
  done
  for l in p q r s t u v w x y o n m l k j i g; do
    [ -e "$dd/$l:" ] || [ -L "$dd/$l:" ] && continue
    ln -s "$dir" "$dd/$l:" 2>/dev/null || continue
    printf '%s' "$l"; return 0
  done
  return 1
}

# Windows path of a Mac path, for the current $WINEPREFIX
sil_winpath() {
  local path=${1:-} root letter rest win c_root parent base
  [ "$path" != "/" ] && path=${path%/}
  root=$(sil_unsafe_root "$path")
  if [ -n "$root" ] && letter=$(sil_drive_for "$root"); then
    rest=${path#"$root"}
    rest=${rest//\//\\}
    win="$(printf '%s' "$letter" | tr '[:lower:]' '[:upper:]'):${rest:-\\}"
  elif [ -n "${WINEPREFIX:-}" ]; then
    c_root="${WINEPREFIX%/}/drive_c"
    case "$path/" in
      "$c_root/"*)
        rest=${path#"$c_root"}
        rest=${rest//\//\\}
        printf '%s' "C:${rest:-\\}"
        return 0 ;;
    esac
    win="Z:${path//\//\\}"
  else
    win="Z:${path//\//\\}"
  fi
  # Shorten long directory paths (e.g. Steam Library games accessed from
  # Plutonium's prefix via Z:\Users\<user>\Library\Application Support\...)
  # so engines with fixed path buffers (such as BO2's .ipak loader) always
  # receive a short Windows path.
  if [ "${#win}" -gt 80 ] && [ -d "$path" ]; then
    parent=$(dirname -- "$path")
    base=$(basename -- "$path")
    if [ -n "$parent" ] && [ "$parent" != "/" ] && [ "$parent" != "$path" ] && [ -d "$parent" ] &&
       ! sil_component_unsafe "$base" && [ $(( ${#base} + 3 )) -le 80 ] &&
       letter=$(sil_drive_for "$parent"); then
      printf '%s' "$(printf '%s' "$letter" | tr '[:lower:]' '[:upper:]'):\\$base"
      return 0
    fi
    if letter=$(sil_drive_for "$path"); then
      printf '%s' "$(printf '%s' "$letter" | tr '[:lower:]' '[:upper:]'):\\"
      return 0
    fi
  fi
  printf '%s' "$win"
}
