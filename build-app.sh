#!/bin/bash
# Builds "Siliconium.app" (with the kit inside) into dist/.
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")" && pwd)
# The app's own version. kit/VERSION is the version of the files the app
# installs (engine modules, BO3 client): a UI-only release does not change it,
# so the app does not reinstall those files when it is updated.
version=$(cat "$root/app/VERSION" 2>/dev/null || cat "$root/kit/VERSION")
app="$root/dist/Siliconium.app"
build="$root/.build"

echo "==> Compiling the app"
swift build -c release -Xswiftc -file-prefix-map -Xswiftc "$root=." --package-path "$root/app" --scratch-path "$build/swift" >/dev/null
bin=$(swift build -c release -Xswiftc -file-prefix-map -Xswiftc "$root=." --package-path "$root/app" --scratch-path "$build/swift" --show-bin-path)/Siliconium

echo "==> Drawing the icon"
rm -rf "$build/AppIcon.iconset"
swiftc -O -o "$build/make-icon" "$root/app/make-icon.swift"
"$build/make-icon" "$build/AppIcon.iconset"
iconutil -c icns -o "$build/AppIcon.icns" "$build/AppIcon.iconset"

echo "==> Assembling $app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/Siliconium"
strip -S "$app/Contents/MacOS/Siliconium"   # no build paths in the app
cp "$build/AppIcon.icns" "$app/Contents/Resources/AppIcon.icns"
cp "$root/CHANGELOG.md" "$app/Contents/Resources/CHANGELOG.md"   # "What's new" after an update
ditto "$root/kit" "$app/Contents/Resources/kit"
# Finder metadata must not end up in the app (or its release zip)
find "$app" -name '.DS_Store' -delete
find "$app" -name '._*' -delete
# Python byte-code caches record the absolute path of the checkout they were
# made in (the build machine's home folder): they must not end up there either
find "$app" -name '__pycache__' -type d -prune -exec rm -rf {} +
find "$app" -name '*.pyc' -delete
cat > "$app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Siliconium</string>
  <key>CFBundleDisplayName</key><string>Siliconium</string>
  <key>CFBundleIdentifier</key><string>io.github.siliconium</string>
  <key>CFBundleExecutable</key><string>Siliconium</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$version</string>
  <key>CFBundleVersion</key><string>$version</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.games</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSMicrophoneUsageDescription</key><string>Asked once for all your games: their voice chat (multiplayer, zombies) uses the microphone. Siliconium will not ask again.</string>
</dict>
</plist>
EOF
# Every Mac binary must load on macOS 15 (DXMT's winemetal.so needs 15; the
# rest is built for 14): a binary linked for a newer macOS (the build
# machine's, by default) cannot be loaded there and Wine cannot start.
echo "==> Checking the minimum macOS of the kit's binaries"
too_new=$(find "$app/Contents/MacOS" "$app/Contents/Resources/kit" -type f | while IFS= read -r f; do
  file "$f" | grep -q Mach-O || continue
  m=$(otool -l "$f" | awk '/minos/{print $2; exit}')
  [ -n "$m" ] && [ "${m%%.*}" -gt 15 ] && echo "  $m ${f#"$app/"}"
done)
[ -z "$too_new" ] || { echo "binaries for a macOS newer than 15:" >&2; echo "$too_new" >&2; exit 1; }
# Metal libraries built into the kit's files (DXMT's command library) must be
# MSL 3.2 or older: macOS 15 refuses newer ones ("language version 4.1 is not
# supported on this OS"), and Xcode 26+ makes 4.1 unless told otherwise.
echo "==> Checking the Metal language version of embedded Metal libraries"
/usr/bin/python3 -I - "$app/Contents/Resources/kit" <<'PY' || exit 1
import os, struct, sys
bad = []
for root, _, files in os.walk(sys.argv[1]):
    for n in files:
        p = os.path.join(root, n)
        try:
            b = open(p, "rb").read()
        except OSError:
            continue
        i = b.find(b"MTLB")
        while i >= 0:
            j = b.find(b"VERS", i, i + 4096)
            if j > 0:
                air_maj, air_min, msl_maj, msl_min = struct.unpack("<4H", b[j + 6:j + 14])
                if (msl_maj, msl_min) > (3, 2):
                    bad.append("  MSL %d.%d %s" % (msl_maj, msl_min, os.path.relpath(p, sys.argv[1])))
            i = b.find(b"MTLB", i + 4)
if bad:
    print("Metal libraries newer than macOS 15 supports:", *sorted(set(bad)), sep="\n", file=sys.stderr)
    sys.exit(1)
PY
# The release is public: no file in the app may carry the build machine's home
# folder (Python caches, logs, debug paths, a scratch folder named after it).
echo "==> Checking the app for build-machine paths"
leaks=$(grep -rlaF -e "$HOME/" -e "$(printf %s "$HOME" | tr / -)-" "$app" 2>/dev/null || true)
if [ -n "$leaks" ]; then
  echo "files that contain this machine's home folder:" >&2
  printf '%s\n' "$leaks" | while IFS= read -r f; do echo "  ${f#"$app/"}" >&2; done
  exit 1
fi
xattr -cr "$app"   # Finder info and other extended attributes stop codesign
# Ad-hoc by default; SIL_SIGN_IDENTITY (e.g. "Developer ID Application: …")
# signs with a real identity. macOS ties the permissions the player grants
# (TCC: the microphone, which every game asks for through Siliconium) to the
# app's designated requirement: an ad-hoc one is the build's own hash, so every
# new build (and an older copy still running Steam) asked again, game after
# game ("Failed to match existing code requirement", 2026-11-24). The ad-hoc
# app names its identifier as its designated requirement instead: the answer
# holds across builds and updates.
codesign -fs "${SIL_SIGN_IDENTITY:--}" --deep "$app" 2>/dev/null
if [ -z "${SIL_SIGN_IDENTITY:-}" ]; then
  codesign -fs - -r='designated => identifier "io.github.siliconium"' "$app" 2>/dev/null
  codesign -dr - "$app" 2>&1 | grep -q 'designated => identifier "io.github.siliconium"' ||
    { echo "the app's designated requirement was not set" >&2; exit 1; }
fi
echo "==> Built $app ($(du -sh "$app" | cut -f1))"
