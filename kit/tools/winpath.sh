# Siliconium: Windows paths for Mac folders, sourced by the kit's scripts.
#
# Windows (and .NET/Mono programs in particular, like Plutonium's installer)
# cannot use a folder whose name ends in a space or a dot, or holds one of
# < > : " | ? * \ — macOS allows all of them. "Z:\Users\me\Downloads\CoD \Games"
# is read as "...\CoD\Games", which does not exist, so Plutonium's installer
# crashed with DirectoryNotFoundException before its window opened.
#
# sil_winpath maps such a path through a drive letter of the current
# $WINEPREFIX whose root is the deepest unsafe folder: every component Windows
# sees below it is then safe ("P:\Games\World At War"). Wine matches drive
# roots by inode, so the working directory of a game started from that folder
# maps to the same drive too. Safe paths keep the usual Z: form.

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
  local path=$1 root letter rest
  root=$(sil_unsafe_root "$path")
  if [ -n "$root" ] && letter=$(sil_drive_for "$root"); then
    rest=${path#"$root"}
    rest=${rest//\//\\}
    printf '%s' "$(printf '%s' "$letter" | tr '[:lower:]' '[:upper:]'):${rest:-\\}"
    return 0
  fi
  printf '%s' "Z:${path//\//\\}"
}
