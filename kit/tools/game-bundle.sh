# game_bundle <wine loader>: prints the path of a copy of the loader as the
# executable of an app bundle beside it ("Siliconium Game.app", made on the
# first use, refreshed when the engine's loader changes).
#
# macOS only treats a process as a game (LSApplicationCategoryType: Game Mode
# while it plays fullscreen: CPU and GPU priority over background work, twice
# the Bluetooth polling rate for controllers, mice and keyboards) when it is the
# executable of an app bundle. For Wine's loader on its own, LaunchServices
# answers "This process is not the executable of a bundle" (a symbolic link to
# it neither: a hard link or a copy is), so the Info.plist that
# install-engine.sh embeds in the loader never turned Game Mode on (gamepolicyd
# never saw a Wine game come to the front; Metal's HUD said "Game Mode Off").
#
# A copy (32 KB), not a hard link: Wine starts child processes from hard links
# of its loader ($TMPDIR/winetemp-<inode>-…/steamwebhelper.exe, …), and with a
# file of many names macOS reports whichever name was looked up last; when a
# Steam helper started while the game did, the game was "anon<wine>", not this
# bundle, and Game Mode stayed off (1 start in 4, 2026-11-23). Steam itself runs
# on the engine's loader (launch.sh), so the copy's only name is this bundle's.
#
# Wine keeps every process of the game on this loader when WINELOADER names it
# (the loader re-executes itself, and starts child processes, through
# WINELOADER); the loader finds ntdll.so beside itself (a relative link here)
# and the rest of the engine from ntdll.so's real place.
# Fails (status 1, nothing printed) when the bundle cannot be made.
game_bundle() {
  local w=$1 c
  [ -x "$w" ] || return 1
  c="$(dirname "$w")/Siliconium Game.app/Contents"
  if [ "$c/MacOS/wine" -ef "$w" ] || ! cmp -s "$c/MacOS/wine" "$w" || [ ! -e "$c/MacOS/ntdll.so" ] ||
     ! grep -q NSLocalNetworkUsageDescription "$c/Info.plist" 2>/dev/null; then
    # (a new file each time, moved over the old one: a running game keeps its own)
    mkdir -p "$c/MacOS" && cp -p "$w" "$c/MacOS/wine.new" && mv -f "$c/MacOS/wine.new" "$c/MacOS/wine" &&
      ln -sfn ../../../ntdll.so "$c/MacOS/ntdll.so" || { rm -f "$c/MacOS/wine.new"; return 1; }
    cat > "$c/Info.plist" <<'EOF' || return 1
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key><string>wine</string>
	<key>CFBundleIdentifier</key><string>io.github.siliconium.game</string>
	<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
	<key>CFBundleName</key><string>Siliconium Game</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>1.0</string>
	<key>CFBundleVersion</key><string>1</string>
	<key>LSApplicationCategoryType</key><string>public.app-category.games</string>
	<key>LSUIElement</key><string>1</string>
	<key>NSPrincipalClass</key><string>WineApplication</string>
	<key>NSMicrophoneUsageDescription</key><string>In-game voice chat.</string>
	<key>NSLocalNetworkUsageDescription</key><string>Local play and LAN matches find and join games on your network.</string>
</dict>
</plist>
EOF
  fi
  printf '%s\n' "$c/MacOS/wine"
}

# use_wine <loader>: $wine = that engine's loader in its bundle, and WINELOADER
# naming it (so the game's own re-executions and Plutonium, Battle.net and what
# they start stay on it; Steam is started without it); GAME_MODE=0 in
# settings.conf, or a bundle that cannot be made: the
# loader as is, WINELOADER unset. Call it whenever $wine changes engine (a
# cloned engine must never inherit another engine's WINELOADER).
use_wine() {
  local gb
  wine=$1
  if [ "${GAME_MODE:-1}" != 0 ] && gb=$(game_bundle "$1"); then wine=$gb; export WINELOADER=$gb
  else unset WINELOADER; fi
}
