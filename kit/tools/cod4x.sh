# Siliconium: Call of Duty 4 multiplayer through CoD4X (cod4x.ovh, the
# community client and servers), sourced by launch.sh. CoD4X plays with
# Siliconium's setup for Steam's Call of Duty 4 multiplayer (steam-games.sh,
# cod4-mp: the engine's DXVK, x87 accelerator, 1x display mode, settings
# writer, controller mapper), in Steam's prefix, without starting Steam.
#
# What CoD4X needs, as its own installer (CoD4x.21.5.Setup.exe, Inno Setup)
# writes it, checked in a throwaway prefix on 2026-11-20:
#  - in the game's folder: iw3mp.exe = the original 1.7 executable with the
#    large-address-aware flag (CoD4X hooks fixed addresses of that build and
#    replaces any other iw3mp.exe, Steam's 2018 build included); mss32.dll =
#    CoD4X's loader; miles32.dll = the game's own mss32.dll (Miles audio);
#  - in AppData\Local\CallofDuty4MW: bin\launcher.dll, bin\cod4x_021\
#    cod4x_021.dll, main\jcod4x_00.iwd, zone\cod4x_*.ff.
# Siliconium installs the same files from CoD4X's GitHub releases (the ones
# its launcher updates from), each checked against the SHA-256 below, so the
# installer's dialogs (game path, Visual C++ 2010: Wine has msvcr100) never
# show. From then on CoD4X's launcher keeps itself and the client up to date.
#
# Steam's own Call of Duty 4 is never changed: for a Steam download CoD4X
# plays from a copy of it in Siliconium's folder, made with APFS clones (no
# extra disk space: only the files CoD4X changes take room), and files Steam
# updates later are copied again before each start. A folder the player
# chose that is not a Steam download gets CoD4X installed in it, as its
# installer does (the original iw3mp.exe is kept as iw3mp.exe.sil-original,
# the original mss32.dll as miles32.dll).
#
# sil_cod4x_prepare <game folder>: sets c4_dir (the folder CoD4X plays from)
# and c4_home (its AppData folder); c4_error says why it failed.

c4_store="$home/mods/cod4x"
# name  SHA-256  URL (CoD4X's GitHub releases)
c4_files=(
  "core c7ecd2c49d7feb4afc6f2c69f4abf1a87c2a289d53199aa46eff54fecdf28c74 https://github.com/callofduty4x/CoD4x_Client_pub/releases/download/21.8/core"
  "mss 066ca450a6c9e3e64d1851a19eaa476376412668229202e52692a864917f3097 https://github.com/callofduty4x/CoD4x_Client_pub/releases/download/21.8/mss"
  "cod4x_021.dll f92e9480abc882d39fff35367ca5a2baffca2d70a69ebb2f64e4f1e3bb041908 https://github.com/callofduty4x/CoD4x_Client_pub/releases/download/21.8/cod4x_021.dll"
  "jcod4x_00.iwd 8188b0bedb08aebbd51aad023ed6bb8a0e9fb996d682ae5c787407bfb66e3733 https://github.com/callofduty4x/CoD4x_Client_pub/releases/download/21.8/jcod4x_00.iwd"
  "cod4x_ambfix.ff a94db0826dbfeca936209bf3b43c2eab6ff6f3480a86ecb9a4e76c766b70eacd https://github.com/callofduty4x/CoD4x_Client_pub/releases/download/21.8/cod4x_ambfix.ff"
  "cod4x_patch.ff e55cd5dfe89833b80ca4b37c0ca6f18c0056fcac9d97eb08003307c55645e71d https://github.com/callofduty4x/CoD4x_Client_pub/releases/download/21.8/cod4x_patch.ff"
  "cod4x_patchv2.ff 02a834ca1c1278ec9bd2113f402850454f5c39aa787603dc5132cbb114fda01a https://github.com/callofduty4x/CoD4x_Client_pub/releases/download/21.8/cod4x_patchv2.ff"
  "launcher.dll 61b43581397d7be1b6002cc37fae5d4ed12e88e037550c7053db312a5a342c08 https://github.com/callofduty4x/CoD4x-launcher/releases/download/1.1.3/launcher.dll"
  "mss32.dll 58c1fd0ccfd27b88675375232d3ae3a45a55f3d18b2c210d0d3c20f7854c08c5 https://github.com/callofduty4x/CoD4x-mss/releases/download/1.0.2/mss32.dll"
)
# iw3mp.exe 1.7 in CoD4X's core archive, and as its installer writes it
# (the same file with the large-address-aware flag: byte 286, 0x03 -> 0x23)
c4_exe_sha1=3323b3882f9465a4c66cf298833435150effb153
c4_exe_laa_sha1=c160ae5e89222d6930925e3389064d1a1136e157
c4_error=

# A Steam library's game folder (Steam would put its own files back, and its
# Call of Duty 4 must stay as Steam installed it)
sil_cod4x_is_steam() { case "$1/" in */steamapps/common/*) return 0 ;; esac; return 1; }

sil_cod4x_fetch() {
  local entry name sum url f got
  mkdir -p "$c4_store" || { c4_error="Could not create $c4_store."; return 1; }
  for entry in "${c4_files[@]}"; do
    read -r name sum url <<< "$entry"
    f="$c4_store/$name"
    [ -f "$f" ] && [ "$(shasum -a 256 "$f" | cut -d' ' -f1)" = "$sum" ] && continue
    printf '==> %s\n' "Downloading CoD4X ($name)"
    if ! curl -fsSL --proto '=https' --retry 2 --connect-timeout 15 -o "$f.download" "$url"; then
      rm -f "$f.download"
      c4_error="Could not download CoD4X from GitHub: check your internet connection and press Play again."
      return 1
    fi
    got=$(shasum -a 256 "$f.download" | cut -d' ' -f1)
    if [ "$got" != "$sum" ]; then
      rm -f "$f.download"
      c4_error="CoD4X's download ($name) is not the one Siliconium checked: Siliconium needs an update."
      return 1
    fi
    mv -f "$f.download" "$f"
  done
  return 0
}

# Steam's Call of Duty 4 -> CoD4X's copy of it (APFS clones; a plain copy when
# the volume has no clones). Later starts copy again only what Steam changed:
# CoD4X's three files and the profiles (players) stay as CoD4X left them.
sil_cod4x_clone() {   # <Steam's folder> <copy>
  local src=$1 dst=$2 s d rel
  if [ ! -d "$dst" ]; then
    printf '==> %s\n' "Making CoD4X's own copy of Call of Duty 4 (Steam's files stay untouched)"
    mkdir -p "$(dirname "$dst")" && rm -rf "$dst.part" || return 1
    cp -cRp "$src" "$dst.part" 2> /dev/null || { rm -rf "$dst.part"; cp -Rp "$src" "$dst.part"; } || {
      rm -rf "$dst.part"; return 1; }
    mv "$dst.part" "$dst"
    return 0
  fi
  while IFS= read -r -d '' s; do
    rel=${s#"$src"/}
    case "$rel" in iw3mp.exe|mss32.dll|miles32.dll|players/*|__*|*.log) continue ;; esac
    d="$dst/$rel"
    [ -f "$d" ] && [ "$(stat -f '%z %m' "$s")" = "$(stat -f '%z %m' "$d")" ] && continue
    mkdir -p "$(dirname "$d")" && rm -f "$d" && { cp -cp "$s" "$d" 2> /dev/null || cp -p "$s" "$d"; } || return 1
  done < <(find "$src" -type f -print0)
  return 0
}

# CoD4X's files in its play folder and in Wine's AppData
sil_cod4x_install() {   # <play folder> <CoD4X's AppData folder> <the game's Miles (mss32.dll)>
  local dir=$1 c4h=$2 miles=$3 own=1 tmp got
  sil_cod4x_is_steam "$dir" && { c4_error="Siliconium never installs CoD4X into Steam's own folder."; return 1; }
  [[ $dir == "$home/cod4x/"* ]] && own=0
  # iw3mp.exe 1.7 with the 4 GB flag
  if [ "$(shasum -a 1 "$dir/iw3mp.exe" 2> /dev/null | cut -d' ' -f1)" != "$c4_exe_laa_sha1" ]; then
    tmp=$(mktemp -d "${TMPDIR:-/tmp}/siliconium-cod4x.XXXXXX") || { c4_error="Could not make a temporary folder."; return 1; }
    if ! /usr/bin/bsdtar -xf "$c4_store/core" -C "$tmp" iw3mp.exe 2> /dev/null ||
       [ "$(shasum -a 1 "$tmp/iw3mp.exe" | cut -d' ' -f1)" != "$c4_exe_sha1" ] ||
       ! printf '\043' | dd of="$tmp/iw3mp.exe" bs=1 seek=286 conv=notrunc 2> /dev/null ||
       [ "$(shasum -a 1 "$tmp/iw3mp.exe" | cut -d' ' -f1)" != "$c4_exe_laa_sha1" ]; then
      rm -rf "$tmp"; c4_error="CoD4X's iw3mp.exe is not the one Siliconium checked: Siliconium needs an update."; return 1
    fi
    if [ "$own" = 1 ] && [ -f "$dir/iw3mp.exe" ] && [ ! -e "$dir/iw3mp.exe.sil-original" ]; then
      cp -p "$dir/iw3mp.exe" "$dir/iw3mp.exe.sil-original" || { rm -rf "$tmp"; c4_error="Could not keep the original iw3mp.exe."; return 1; }
    fi
    mv -f "$tmp/iw3mp.exe" "$dir/iw3mp.exe" || { rm -rf "$tmp"; c4_error="Could not write iw3mp.exe into $dir."; return 1; }
    rm -rf "$tmp"
  fi
  # Miles: the game's mss32.dll goes to miles32.dll, CoD4X's loader takes its
  # name (a loader CoD4X's launcher updated later is left as it is)
  if [ -f "$dir/mss32.dll" ] && ! grep -aq get_mss32_version "$dir/mss32.dll"; then
    [ -f "$dir/miles32.dll" ] || cp -p "$dir/mss32.dll" "$dir/miles32.dll" || { c4_error="Could not keep the game's mss32.dll."; return 1; }
  fi
  if [ -f "$miles" ] && ! grep -aq get_mss32_version "$miles" && ! cmp -s "$miles" "$dir/miles32.dll"; then
    cp -p "$miles" "$dir/miles32.dll"   # (Steam's copy: its Miles changed)
  fi
  if [ ! -f "$dir/miles32.dll" ]; then
    /usr/bin/bsdtar -xf "$c4_store/mss" -C "$dir" miles32.dll 2> /dev/null || { c4_error="Could not install miles32.dll."; return 1; }
  fi
  if ! grep -aq get_mss32_version "$dir/mss32.dll" 2> /dev/null; then
    cp "$c4_store/mss32.dll" "$dir/mss32.dll" || { c4_error="Could not install CoD4X's mss32.dll."; return 1; }
  fi
  # AppData: what its launcher updates later is left as it is
  mkdir -p "$c4h/bin/cod4x_021" "$c4h/main" "$c4h/zone" || { c4_error="Could not create $c4h."; return 1; }
  [ -f "$c4h/bin/launcher.dll" ] || cp "$c4_store/launcher.dll" "$c4h/bin/launcher.dll" || return 1
  compgen -G "$c4h/bin/cod4x_0*/cod4x_0*.dll" > /dev/null || cp "$c4_store/cod4x_021.dll" "$c4h/bin/cod4x_021/cod4x_021.dll" || return 1
  [ -f "$c4h/main/jcod4x_00.iwd" ] || cp "$c4_store/jcod4x_00.iwd" "$c4h/main/" || return 1
  for f in cod4x_ambfix.ff cod4x_patch.ff cod4x_patchv2.ff; do
    [ -f "$c4h/zone/$f" ] || cp "$c4_store/$f" "$c4h/zone/" || return 1
  done
  return 0
}

sil_cod4x_prepare() {   # <game folder>
  local src=$1 users
  c4_dir= c4_home= c4_error=
  if [ -z "$src" ] || [ ! -d "$src/main" ] || [ ! -d "$src/zone" ] || [ ! -f "$src/iw3mp.exe" ]; then
    c4_error="Choose the Call of Duty 4 game folder (the one with iw3mp.exe, main/ and zone/)."
    return 1
  fi
  users=$(ls -d "$WINEPREFIX"/drive_c/users/*/AppData/Local 2> /dev/null | grep -v '/users/Public/' | head -1)
  [ -n "$users" ] || users="$WINEPREFIX/drive_c/users/crossover/AppData/Local"
  c4_home="$users/CallofDuty4MW"
  sil_cod4x_fetch || return 1
  if sil_cod4x_is_steam "$src"; then
    c4_dir="$home/cod4x/$(basename "$src")"
    sil_cod4x_clone "$src" "$c4_dir" || { c4_error="Could not make CoD4X's copy of Call of Duty 4 in $home/cod4x."; return 1; }
  else
    c4_dir=$src
  fi
  sil_cod4x_install "$c4_dir" "$c4_home" "$src/mss32.dll" || { c4_error=${c4_error:-"Could not install CoD4X into $c4_dir."}; return 1; }
  return 0
}
