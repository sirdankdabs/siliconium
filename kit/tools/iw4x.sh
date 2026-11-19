# Siliconium: Modern Warfare 2 through IW4X, sourced by launch.sh and iw4-update.sh.
#
# IW4X's own launcher (iw4x-launcher.exe, a Windows program) keeps the client,
# its assets, rawfiles and DLC up to date and updates itself. It lives in the
# game folder and refuses to run without the game's iw4mp.exe next to it
# ("launcher must be in Modern Warfare 2 directory, next to iw4mp.exe").
#
# sil_iw4x_prepare <game folder>:
#  - downloads iw4x-launcher.exe from IW4X's latest GitHub release when the
#    folder has none (checked against the release's SHA-256); from then on the
#    launcher updates itself;
#  - packaged IW4X copies ship iw4x.exe but no iw4mp.exe: give the launcher an
#    iw4mp.exe made from iw4x.exe (only when there is none; a real one is
#    never touched). The launcher only checks that it is there.
# Returns non-zero when the launcher could not be provided.

sil_iw4x_fetch_launcher() {   # <game folder>
  local dir=$1 json url sha tmp
  json=$(curl -fsSL --retry 2 --connect-timeout 15 https://api.github.com/repos/iw4x/launcher/releases/latest 2>/dev/null) || return 1
  read -r url sha < <(printf '%s' "$json" | /usr/bin/python3 -I -c 'import json, sys
try:
    r = json.load(sys.stdin)
    a = next(a for a in r["assets"] if a["name"].endswith("-x86_64-windows.zip"))
    print(a["browser_download_url"], a.get("digest", "").split(":")[-1])
except Exception:
    pass' 2>/dev/null)
  [ -n "${url:-}" ] && [ -n "${sha:-}" ] || return 1
  tmp=$(mktemp -d) || return 1
  if curl -fsSL --proto '=https' --retry 3 -o "$tmp/l.zip" "$url" &&
     [ "$(shasum -a 256 "$tmp/l.zip" | cut -d' ' -f1)" = "$sha" ] &&
     ditto -x -k "$tmp/l.zip" "$tmp/x" && [ -f "$tmp/x/iw4x-launcher.exe" ]; then
    mv -f "$tmp/x/iw4x-launcher.exe" "$dir/iw4x-launcher.exe"
    rm -rf "$tmp"
    return 0
  fi
  rm -rf "$tmp"
  return 1
}

sil_iw4x_prepare() {   # <game folder>
  local dir=$1
  if [ ! -f "$dir/iw4x-launcher.exe" ]; then
    printf '==> %s\n' "Downloading the IW4X launcher"
    sil_iw4x_fetch_launcher "$dir" || return 1
  fi
  if [ ! -e "$dir/iw4mp.exe" ] && [ -f "$dir/iw4x.exe" ]; then
    cp -p "$dir/iw4x.exe" "$dir/iw4mp.exe" && : > "$dir/.sil-iw4mp-from-iw4x"
  fi
  return 0
}
