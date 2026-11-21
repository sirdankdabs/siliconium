# Siliconium: Infinite Warfare through IW7-Mod (CBServers), CBServers' fork of
# AuroraMod's community client (github.com/CBServers/iw7-mod, GPL-3.0: custom
# maps in usermaps/, its own servers), sourced by launch.sh. IW7-Mod plays
# with Siliconium's setup for Steam's Infinite Warfare (steam-games.sh iw:sp,
# s_kind iw7: Advanced Warfare's two DXMT fixes, the 1x display mode, the
# resolution and refresh rate in its hashed profile), in Steam's prefix,
# without starting Steam. Its switches are its own (IW7MOD_*): the Steam
# Library's Infinite Warfare keeps IW7_*.
#
# IW7-Mod is one Windows program, iw7-mod.exe (CBServers' download link: the
# file in their updater repository, here pinned to one commit and checked
# against the SHA-256 below), that must sit in the game's folder next to
# iw7_ship.exe ("Please copy the iw7-mod.exe into your Call of Duty: Infinite
# Warfare installation folder and run it from there"). It loads the game into
# its own process, so the game runs as iw7-mod.exe. From then on its own
# updater keeps it up to date (it replaces iw7-mod.exe itself), and it keeps
# its profile, saves and logs in an iw7-mod folder next to it.
#
# Steam's own Infinite Warfare is never changed (owner, 2026-11-21: Steam's
# install untouched, the player chooses the normal game or IW7-Mod at each
# start): for a Steam download IW7-Mod plays from a copy of it in
# Siliconium's folder (tools/steam-copy.sh), made with APFS clones of Steam's
# current files at each start (no extra disk space: only files that differ
# take room); a minute after the game Steam's files leave it again, so between
# games it holds only IW7-Mod's own files. Without clones (another volume) Siliconium refuses
# instead of copying ~100 GB. A folder the player chose that is not a Steam
# download gets iw7-mod.exe added to it. An iw7-mod.exe that is not CBServers'
# (AuroraMod's, installed by an earlier Siliconium build) is replaced; one
# found in a player's own folder is kept as iw7-mod.exe.auroramod.
#
# sil_iw7mod_use <game folder>: the Steam Library's Infinite Warfare setup for
# IW7-Mod (s_* variables, IW7MOD_* switches) and sil_iw7mod_prepare.
# sil_iw7mod_prepare <game folder>: sets i7_dir (the folder IW7-Mod plays
# from); i7_error says why it failed.

i7_store="$home/mods/iw7mod"
i7_copies="$home/iw7mod"
# CBServers' build of 2026-10-23 (CBServers/updater commit b2f11f0 "Update
# artifacts"; their README's link, .../raw/main/..., served the same file on
# 2026-11-21; SHA-1 AD6087D2… = their files.json)
i7_url=https://github.com/CBServers/updater/raw/b2f11f09a68566be613c2097c1218cefe0a536b2/updater/iw7-mod/data/iw7-mod.exe
i7_sha=b62486d93af8928cfe8282082a4a92fd578e1bebc555f21eea2555dc281634ec
# (every CBServers build names its update server; AuroraMod's do not)
i7_marker=CBServers/updater
i7_error=

# A Steam library's game folder (Steam's Infinite Warfare stays as Steam installed it)
sil_iw7mod_is_steam() { case "$1/" in */steamapps/common/*) return 0 ;; esac; return 1; }

sil_iw7mod_fetch() {
  local f="$i7_store/iw7-mod.exe" got
  mkdir -p "$i7_store" || { i7_error="Could not create $i7_store."; return 1; }
  [ -f "$f" ] && [ "$(shasum -a 256 "$f" | cut -d' ' -f1)" = "$i7_sha" ] && return 0
  printf '==> %s\n' "Downloading IW7-Mod"
  if ! curl -fsSL --proto '=https' --retry 2 --connect-timeout 15 -o "$f.download" "$i7_url"; then
    rm -f "$f.download"
    i7_error="Could not download IW7-Mod from GitHub: check your internet connection and press Play again."
    return 1
  fi
  got=$(shasum -a 256 "$f.download" | cut -d' ' -f1)
  if [ "$got" != "$i7_sha" ]; then
    rm -f "$f.download"
    i7_error="IW7-Mod's download is not the one Siliconium checked: Siliconium needs an update."
    return 1
  fi
  mv -f "$f.download" "$f"
}

# Steam's Infinite Warfare -> IW7-Mod's copy of it (tools/steam-copy.sh: APFS
# clones of Steam's current files at each start, clones only); IW7-Mod's own
# files (iw7-mod.exe, iw7-mod/, minidumps, logs, what it added) and the game's
# profile folder stay as they are.
. "$kit/tools/steam-copy.sh"
sil_iw7mod_clone() {   # <Steam's folder> <copy>
  [ -d "$2" ] || printf '==> %s\n' "Making IW7-Mod's own copy of Infinite Warfare (Steam's files stay untouched)"
  sil_copy_make iw7mod "$1" "$2" && return 0
  case "$sil_copy_error" in
    clones) i7_error="Could not make IW7-Mod's copy of Infinite Warfare: it needs Siliconium's folder and Steam's library on the same APFS volume (a full copy would take about 100 GB)." ;;
    ?*) i7_error=$sil_copy_error ;;
    *) i7_error="Could not update IW7-Mod's copy of Infinite Warfare." ;;
  esac
  return 1
}

sil_iw7mod_prepare() {   # <game folder>
  local src=$1 dir
  i7_dir= i7_error=
  if [ -z "$src" ] || [ ! -f "$src/iw7_ship.exe" ] || [ ! -f "$src/common.ff" ] || [ ! -d "$src/main" ]; then
    i7_error="Choose the Infinite Warfare game folder (the one with iw7_ship.exe, common.ff and main/)."
    return 1
  fi
  if sil_iw7mod_is_steam "$src"; then
    dir="$i7_copies/$(basename "$src")"
    sil_iw7mod_clone "$src" "$dir" || { i7_error=${i7_error:-"Could not make IW7-Mod's copy of Infinite Warfare in $i7_copies."}; return 1; }
  else
    dir=$src
  fi
  # CBServers' iw7-mod.exe already there (put by Siliconium, by the player, or
  # updated by IW7-Mod itself) is left as it is; another one goes
  if [ -f "$dir/iw7-mod.exe" ] && ! grep -aqF "$i7_marker" "$dir/iw7-mod.exe"; then
    sil_iw7mod_fetch || return 1
    if [ "$dir" = "$src" ] && [ ! -e "$dir/iw7-mod.exe.auroramod" ]; then
      mv -f "$dir/iw7-mod.exe" "$dir/iw7-mod.exe.auroramod" || { i7_error="Could not replace $dir/iw7-mod.exe."; return 1; }
    else
      rm -f "$dir/iw7-mod.exe"
    fi
  fi
  if [ ! -f "$dir/iw7-mod.exe" ]; then
    sil_iw7mod_fetch || return 1
    cp "$i7_store/iw7-mod.exe" "$dir/iw7-mod.exe.part" && mv -f "$dir/iw7-mod.exe.part" "$dir/iw7-mod.exe" || {
      rm -f "$dir/iw7-mod.exe.part"; i7_error="Could not install IW7-Mod into $dir."; return 1; }
  fi
  # IW7-Mod keeps the game's profile in iw7-mod/players2 (its filesystem.cpp
  # moves players2 there): one kept by "Remove setup" comes back; else, the
  # first time, it starts from the game's own settings (Steam's: the video
  # options chosen there; only read)
  if [ ! -e "$dir/iw7-mod" ] && [ -d "$i7_copies/kept/$(basename "$dir")/iw7-mod" ]; then
    mv "$i7_copies/kept/$(basename "$dir")/iw7-mod" "$dir/iw7-mod"
  fi
  if [ ! -e "$dir/iw7-mod/players2/config_mp.cfg" ] && [ -f "$src/players2/config_mp.cfg" ]; then
    mkdir -p "$dir/iw7-mod/players2" && cp -p "$src/players2/config_mp.cfg" "$dir/iw7-mod/players2/config_mp.cfg"
  fi
  # the game's shader preload record (players2/upshd.dat; CBServers' build
  # moves it to iw7-mod/players2 too, its filesystem.cpp): the game's own, so
  # "Preloading Shaders" is not run again when the game has done it (the
  # shaders themselves are in DXMT's caches, shared with Steam's game)
  if [ ! -e "$dir/iw7-mod/players2/upshd.dat" ] && [ -f "$src/players2/upshd.dat" ]; then
    mkdir -p "$dir/iw7-mod/players2" && cp -p "$src/players2/upshd.dat" "$dir/iw7-mod/players2/upshd.dat"
  fi
  i7_dir=$dir
  return 0
}

sil_iw7mod_use() {   # <game folder>
  steam_title iw sp || { i7_error="unknown Steam Library game: iw-sp"; return 1; }
  s_id=iw s_part=sp s_own=0 s_client=iw7mod s_name=IW7-Mod s_exe=iw7-mod.exe
  # the IW7-Mod tab's switches stand in for the Steam Library's
  IW7_DXMT_FIX=${IW7MOD_DXMT_FIX:-1} IW7_SCREEN=${IW7MOD_SCREEN:-1} DISPLAY_MODE=${IW7MOD_DISPLAY_MODE:-1}
  IW7_ASYNC=${IW7MOD_ASYNC:-1} IW7_FRAME_PACING=${IW7MOD_FRAME_PACING:-1}
  sil_iw7mod_prepare "$1"
}
