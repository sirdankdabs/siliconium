# Siliconium: the MoltenVK (Vulkan -> Metal) build for this macOS, sourced by
# install-engine.sh and launch.sh.
#
# - macOS 26 and later: 1.4.2 (built with the macOS 26.5 SDK; its own Metal
#   shaders are MSL 4.1, which macOS 15 cannot compile).
# - macOS 15 and earlier: 1.4.1 (macOS 15.5 SDK). Not 1.4.0: under WoW64
#   (every 32-bit Direct3D 9 game: World at War, Black Ops, MW2, MW3) Wine
#   creates each Vulkan buffer with host-allocation external memory, which
#   1.4.0's vkCreateBuffer rejects ("Only external memory handle type
#   ..._MTLBUFFER_BIT_EXT ... are supported"): DXVK could not create a device
#   and Black Ops never opened. 1.4.1 accepts host memory.
#
# The installed version is recorded in lib64/libMoltenVK.real.version, so an
# engine moved to another macOS (an upgrade, or back to Sequoia) is fixed on
# the next game start.

sil_moltenvk_pick() {
  if [ "$(sw_vers -productVersion | cut -d. -f1)" -ge 26 ]; then
    moltenvk_version=1.4.2
    moltenvk_sha=f95765a6229cb7b915990a2890ce12ebe36a730b021545d3d52ae69ce4c4024e
  else
    moltenvk_version=1.4.1
    moltenvk_sha=5ea0c259df7ded9a275444820f09cced54d6e5a7c7a31d262de62a5cdb7e15cf
  fi
  moltenvk_url=https://github.com/KhronosGroup/MoltenVK/releases/download/v$moltenvk_version/MoltenVK-macos.tar
}

# sil_moltenvk_install <engine dir> <downloads dir>: returns non-zero on failure
sil_moltenvk_install() {
  local dest=$1 downloads=$2 tar tmp
  sil_moltenvk_pick
  tar="$downloads/MoltenVK-macos-$moltenvk_version.tar"
  mkdir -p "$downloads" || return 1
  if [ ! -f "$tar" ] || [ "$(shasum -a 256 "$tar" | cut -d' ' -f1)" != "$moltenvk_sha" ]; then
    curl -fsSL --proto '=https' --retry 3 -o "$tar.part" "$moltenvk_url" || { rm -f "$tar.part"; return 1; }
    mv -f "$tar.part" "$tar"
  fi
  [ "$(shasum -a 256 "$tar" | cut -d' ' -f1)" = "$moltenvk_sha" ] || { rm -f "$tar"; return 1; }
  tmp=$(mktemp -d) || return 1
  if ! tar -xf "$tar" -C "$tmp" MoltenVK/MoltenVK/dynamic/dylib/macOS/libMoltenVK.dylib; then
    rm -rf "$tmp"; return 1
  fi
  cp "$tmp/MoltenVK/MoltenVK/dynamic/dylib/macOS/libMoltenVK.dylib" "$dest/lib64/libMoltenVK.real.dylib.new" || { rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
  install_name_tool -id @rpath/libMoltenVK.real.dylib "$dest/lib64/libMoltenVK.real.dylib.new" 2>/dev/null
  codesign -fs - "$dest/lib64/libMoltenVK.real.dylib.new" 2>/dev/null
  xattr -d com.apple.quarantine "$dest/lib64/libMoltenVK.real.dylib.new" 2>/dev/null
  mv -f "$dest/lib64/libMoltenVK.real.dylib.new" "$dest/lib64/libMoltenVK.real.dylib" || return 1
  printf '%s\n' "$moltenvk_version" > "$dest/lib64/libMoltenVK.real.version"
}

# sil_moltenvk_ensure <engine dir> <downloads dir>: the right build for this macOS
sil_moltenvk_ensure() {
  local dest=$1
  [ -f "$dest/lib64/libMoltenVK.real.dylib" ] || return 0
  sil_moltenvk_pick
  [ "$(cat "$dest/lib64/libMoltenVK.real.version" 2>/dev/null)" = "$moltenvk_version" ] && return 0
  sil_moltenvk_install "$@"
}
