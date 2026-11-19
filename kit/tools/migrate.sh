# Siliconium: carry an install of its previous name over, once.
#
# Sourced by every kit script right after it sets $home. Earlier versions kept
# everything (engine, Wine prefixes, Plutonium, caches, settings) in another
# folder of Application Support and marked their one-time settings with other
# file names; these are the only places the old names are still written, so
# they can be found and moved.

sil_legacy_name() { printf '%s %s %s' Black Ops Mac; }

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
