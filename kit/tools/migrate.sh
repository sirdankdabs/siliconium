# Siliconium: carry an install of its previous name over, once.
#
# Sourced by every kit script right after it sets $home. Earlier versions kept
# everything (engine, Wine prefixes, Plutonium, caches, settings) in another
# folder of Application Support and marked their one-time settings with other
# file names; these are the only places the old names are still written, so
# they can be found and moved.

sil_legacy_name() { printf '%s %s %s' Black Ops Mac; }

# Wine strips trailing dots and spaces from every Windows path component
# (RtlDosPathNameToNtPathName_U), so if $HOME itself has a component ending in
# "." or " " (e.g. /Users/name.), Wine fails with "could not load kernel32.dll,
# status c0000135" on every prefix/engine call (and symlinks still fail because
# Wine calls realpath()). Use a private 0700 folder outside $HOME automatically.
if [ -z "${SIL_HOME:-}" ]; then
  case "/$HOME/" in
    *./*|*" "/*)
      sil_orig_home="$home"
      sil_uid=$(id -u 2>/dev/null || echo 501)
      sil_safe="/Users/Shared/Siliconium-$sil_uid"
      if [ -d "$sil_safe" ] || mkdir -m 700 -p "$sil_safe" 2>/dev/null; then
        home="$sil_safe"
      else
        sil_cache=$(getconf DARWIN_USER_CACHE_DIR 2>/dev/null || true)
        if [ -n "$sil_cache" ]; then
          home="${sil_cache%/}/Siliconium"
          mkdir -m 700 -p "$home" 2>/dev/null || true
        fi
      fi
      if [ "$home" != "$sil_orig_home" ] && [ -d "$sil_orig_home/engine" ] && [ ! -e "$home/engine" ]; then
        mv "$sil_orig_home/engine" "$home/engine" 2>/dev/null || true
        [ -f "$sil_orig_home/settings.conf" ] && [ ! -e "$home/settings.conf" ] &&
          mv "$sil_orig_home/settings.conf" "$home/settings.conf" 2>/dev/null || true
      fi
      export SIL_HOME="$home"
      unset sil_orig_home sil_uid sil_safe sil_cache
      ;;
  esac
fi

# the data folder: moved as a whole, never merged
if [ -z "${SIL_HOME:-}" ] && [ ! -e "$home" ]; then
  sil_old_home="$HOME/Library/Application Support/$(sil_legacy_name)"
  [ -d "$sil_old_home" ] && mv "$sil_old_home" "$home" 2>/dev/null
  unset sil_old_home
fi
# the engine's version file
sil_old_version="$home/engine/$(sil_legacy_name | tr 'A-Z ' 'a-z-').version"
if [ -f "$sil_old_version" ] && [ ! -f "$home/engine/siliconium.version" ]; then
  mv "$sil_old_version" "$home/engine/siliconium.version" 2>/dev/null
fi
unset sil_old_version

# sil_migrate_markers <depth> <folder>...: one-time-settings markers, backups and the
# engine's spare modules use the new names (so a game's first-run settings
# are not applied again over the player's own)
sil_migrate_markers() {
  local old new d depth=$1
  shift
  for d in "$@"; do
    [ -d "$d" ] || continue
    find "$d" -maxdepth "$depth" \( -name '.bom-*' -o -name '*.bom-*' -o -name '*.bom.dll' -o -name '*.bom.sys' -o -name 'bom-*.sh' \) 2>/dev/null |
    while IFS= read -r old; do
      case "${old##*/}" in
        .bom-*) new="${old%/*}/.sil-${old##*/.bom-}" ;;
        bom-*) new="${old%/*}/sil-${old##*/bom-}" ;;
        *.bom.dll|*.bom.sys) new="${old%.bom.*}.sil.${old##*.bom.}" ;;
        *) new="${old%.bom-*}.sil-${old##*.bom-}" ;;
      esac
      [ -e "$new" ] || mv "$old" "$new" 2>/dev/null
    done
  done
}
