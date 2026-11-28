# Siliconium: Modern Warfare 2 through IW4X, sourced by launch.sh and iw4-update.sh.
#
# IW4X's own launcher (iw4x-launcher.exe, a Windows program) keeps the client,
# its assets, rawfiles and DLC up to date and updates itself. It lives in the
# game folder and refuses to run without the game's iw4mp.exe next to it
# ("launcher must be in Modern Warfare 2 directory, next to iw4mp.exe").
#
# sil_iw4x_prepare <game folder> [force]:
#  - checks IW4X's latest GitHub release on every launch (with a non-API
#    redirect fallback when GitHub's API is rate-limited) and downloads or
#    replaces iw4x-launcher.exe whenever it is missing, outdated, or does not
#    match the verified SHA-256 recorded in .sil-iw4x-launcher-version (this
#    also replaces stale/third-party launchers already sitting in a user's MW2
#    folder);
#  - clears stale cache/iw4x.db* when taking over a folder, upgrading the
#    launcher, or when "force" is passed, so iw4x-launcher.exe runs a full
#    physical hash audit and updates every outdated IW4X file on disk;
#  - sets iw4x_online=1 when GitHub was reachable (0 when offline);
#  - packaged IW4X copies ship iw4x.exe but no iw4mp.exe: give the launcher an
#    iw4mp.exe made from iw4x.exe (only when there is none; a real one is
#    never touched). The launcher only checks that it is there.
# Returns non-zero when no usable launcher could be provided.

iw4x_online=0

sil_iw4x_latest_release() {   # prints "<tag> <url> <sha_or_->"
  local json tag ver url sha eff
  json=$(curl -fsSL --retry 2 --connect-timeout 6 --max-time 12 https://api.github.com/repos/iw4x/launcher/releases/latest 2>/dev/null || true)
  if [ -n "$json" ]; then
    read -r tag url sha < <(printf '%s' "$json" | /usr/bin/python3 -I -c 'import json, sys
try:
    r = json.load(sys.stdin)
    tag = r.get("tag_name", "").strip()
    a = next(a for a in r["assets"] if a["name"].endswith("-x86_64-windows.zip"))
    sha = a.get("digest", "").split(":")[-1].strip() or "-"
    if tag and a.get("browser_download_url"):
        print(tag, a["browser_download_url"], sha)
except Exception:
    pass' 2>/dev/null || true)
    if [ -n "${tag:-}" ] && [ -n "${url:-}" ]; then
      printf '%s %s %s\n' "$tag" "$url" "${sha:--}"
      return 0
    fi
  fi
  # Fallback when GitHub API is rate-limited (HTTP 403): resolve latest tag via web redirect.
  eff=$(curl -fsSLI --connect-timeout 6 --max-time 12 -o /dev/null -w '%{url_effective}' https://github.com/iw4x/launcher/releases/latest 2>/dev/null || true)
  case "$eff" in
    https://github.com/iw4x/launcher/releases/tag/*)
      tag=${eff##*/}
      ver=${tag#v}
      [ -n "$tag" ] && [ -n "$ver" ] || return 1
      url="https://github.com/iw4x/launcher/releases/download/${tag}/launcher-${ver}-x86_64-windows.zip"
      printf '%s %s -\n' "$tag" "$url"
      return 0 ;;
  esac
  return 1
}

sil_iw4x_clear_db() {   # <game folder>
  rm -rf "$1/cache/iw4x.db" "$1/cache/iw4x.db-shm" "$1/cache/iw4x.db-wal" "$1/cache/staging" 2>/dev/null || true
}

sil_iw4x_install_launcher() {   # <game folder> <tag> <url> <sha_or_->
  local dir=$1 tag=$2 url=$3 sha=$4 tmp size exe_sha
  tmp=$(mktemp -d) || return 1
  if curl -fsSL --proto '=https' --tlsv1.2 --retry 3 --connect-timeout 15 -o "$tmp/l.zip" "$url" &&
     { [ "$sha" = "-" ] || [ "$(shasum -a 256 "$tmp/l.zip" | cut -d' ' -f1)" = "$sha" ]; } &&
     ditto -x -k "$tmp/l.zip" "$tmp/x" && [ -f "$tmp/x/iw4x-launcher.exe" ]; then
    size=$(stat -f %z "$tmp/x/iw4x-launcher.exe" 2>/dev/null || echo 0)
    if [ "$size" -ge 1000000 ] && [ "$(head -c 2 "$tmp/x/iw4x-launcher.exe" 2>/dev/null)" = MZ ]; then
      chmod u+w "$dir/iw4x-launcher.exe" 2>/dev/null || true
      if mv -f "$tmp/x/iw4x-launcher.exe" "$dir/iw4x-launcher.exe"; then
        exe_sha=$(shasum -a 256 "$dir/iw4x-launcher.exe" 2>/dev/null | cut -d' ' -f1)
        printf '%s %s\n' "$tag" "$exe_sha" > "$dir/.sil-iw4x-launcher-version" 2>/dev/null || true
        rm -rf "$tmp"
        return 0
      fi
    fi
  fi
  rm -rf "$tmp"
  return 1
}

sil_iw4x_prepare() {   # <game folder> [force]
  local dir=$1 force=${2:-} tag= url= sha= saved_tag= saved_sha= cur_sha= need_dl=0
  iw4x_online=0
  if read -r tag url sha < <(sil_iw4x_latest_release); then
    iw4x_online=1
    if [ ! -f "$dir/iw4x-launcher.exe" ]; then
      need_dl=1
    else
      if [ -f "$dir/.sil-iw4x-launcher-version" ]; then
        read -r saved_tag saved_sha < "$dir/.sil-iw4x-launcher-version" 2>/dev/null || true
      fi
      cur_sha=$(shasum -a 256 "$dir/iw4x-launcher.exe" 2>/dev/null | cut -d' ' -f1)
      if [ "$saved_tag" != "$tag" ] || [ -z "$saved_sha" ] || [ "$saved_sha" != "$cur_sha" ]; then
        need_dl=1
      fi
    fi
    if [ "$need_dl" = 1 ]; then
      if [ -f "$dir/iw4x-launcher.exe" ]; then
        printf '==> %s\n' "Updating the IW4X launcher ($tag)…"
      else
        printf '==> %s\n' "Downloading the IW4X launcher ($tag)…"
      fi
      if sil_iw4x_install_launcher "$dir" "$tag" "$url" "$sha"; then
        # Force full file hash verification after installing/replacing the launcher
        # (fixes pre-existing folders carrying an older IW4X build or stale cache db).
        sil_iw4x_clear_db "$dir"
      elif [ ! -f "$dir/iw4x-launcher.exe" ]; then
        return 1
      fi
    fi
  elif [ ! -f "$dir/iw4x-launcher.exe" ]; then
    return 1
  fi
  if [ "$force" = force ]; then
    sil_iw4x_clear_db "$dir"
  fi
  if [ ! -e "$dir/iw4mp.exe" ] && [ -f "$dir/iw4x.exe" ]; then
    cp -p "$dir/iw4x.exe" "$dir/iw4mp.exe" && : > "$dir/.sil-iw4mp-from-iw4x"
  fi
  return 0
}

# Stream iw4x-launcher.exe's live download/extract progress (%, files, speed,
# and ETA) from its log to Siliconium's status pill ("==> ...").
#   sil_iw4x_watch_log <log_file> [stop_when_game_runs:0|1] [first_start:0|1]
iw4x_watch_pid=
sil_iw4x_stop_watch() {
  if [ -n "${iw4x_watch_pid:-}" ]; then
    kill "$iw4x_watch_pid" 2>/dev/null || true
    wait "$iw4x_watch_pid" 2>/dev/null || true
    iw4x_watch_pid=
  fi
}

sil_iw4x_parse_log() {   # <log_file> -> emits "kind|pct|frac|spd|comp"
  local log=$1
  [ -f "$log" ] || return 0
  tail -c 16384 "$log" 2>/dev/null | LC_ALL=C tr -d '\000' | LC_ALL=C tr '\r' '\n' | LC_ALL=C awk '
    {
      gsub(/\033\[[0-9;?]*[A-Za-z]/, "")
    }
    /synchronizing[[:space:]]+.*component/ {
      comp = $0
      sub(/^.*synchronizing[[:space:]]+/, "", comp)
      sub(/[[:space:]]+component.*$/, "", comp)
      kind = "sync"
    }
    /extracting downloaded archive|Converting|Patching|Extracting/ {
      kind = "prep"
    }
    /\[[[:space:]]*[0-9]+[[:space:]]*\/[[:space:]]*[0-9]+[[:space:]]*\][[:space:]]+Total[[:space:]]+[0-9]+%/ {
      frac = ""; pct = ""; spd = ""
      if (match($0, /\[[[:space:]]*[0-9]+[[:space:]]*\/[[:space:]]*[0-9]+[[:space:]]*\]/)) {
        frac = substr($0, RSTART + 1, RLENGTH - 2)
        gsub(/[[:space:]]+/, "", frac)
      }
      if (match($0, /[0-9]+%/)) pct = substr($0, RSTART, RLENGTH - 1)
      if (match($0, /[0-9]+(\.[0-9]+)?[[:space:]]*[KMG]?i?B\/s/)) {
        spd = substr($0, RSTART, RLENGTH)
        gsub(/[[:space:]]+/, " ", spd)
      }
      if (frac == "0/0" && pct == "0") {
        if (kind == "") kind = "sync"
      } else {
        kind = "dl"
      }
    }
    /Launching IW4x|Starting IW4x|launching game|starting game/ {
      kind = "run"
    }
    END {
      if (kind == "dl") printf "dl|%s|%s|%s|%s\n", pct, frac, spd, comp
      else if (kind == "prep") printf "prep||||%s\n", comp
      else if (kind == "sync") printf "sync||||%s\n", comp
      else if (kind == "run") print "run||||"
    }
  '
}

sil_iw4x_watch_log() {   # <log_file> [watch_game:0|1] [first_start:0|1]
  local log=$1 watch_game=${2:-0} first_start=${3:-0}
  sil_iw4x_stop_watch
  (
    last_msg="" dl_t0="" dl_p0="" dl_tot="" dl_last_pct=-1
    while sleep 1.5; do
      if [ "$watch_game" = 1 ] && ps -axo args= | awk 'BEGIN{rc=1} {l=tolower($0)} l ~ /(^|[\/\\[:space:]])iw4x\.exe([[:space:]]|$)/ && l !~ /iw6-focus|iw6-restore\.exe|launch\.sh|awk/ {rc=0; exit} END{exit rc}'; then
        break
      fi
      parsed=$(sil_iw4x_parse_log "$log")
      [ -n "$parsed" ] || continue
      IFS='|' read -r p_kind p_pct p_frac p_spd p_comp <<< "$parsed"
      msg=""
      case "$p_kind" in
        dl)
          now=$(date +%s)
          p_tot=${p_frac#*/}
          if [ "$p_tot" != "$dl_tot" ] || { [[ $p_pct =~ ^[0-9]+$ ]] && [ "$p_pct" -lt "$dl_last_pct" ]; }; then
            dl_tot=$p_tot
            dl_t0=$now
            dl_p0=$p_pct
          fi
          [ -z "$dl_t0" ] && { dl_t0=$now; dl_p0=$p_pct; }
          [[ $p_pct =~ ^[0-9]+$ ]] && dl_last_pct=$p_pct
          [ "$p_spd" = "0 B/s" ] && p_spd=""
          eta=""
          if [[ $p_pct =~ ^[0-9]+$ ]] && [ "$p_pct" -gt "${dl_p0:-0}" ] && [ "$p_pct" -lt 100 ]; then
            dt=$((now - dl_t0))
            dp=$((p_pct - dl_p0))
            if [ "$dt" -ge 2 ]; then
              rem=$(( (100 - p_pct) * dt / dp ))
              if declare -F sil_fmt_eta >/dev/null 2>&1; then
                eta=" · $(sil_fmt_eta "$rem")"
              else
                [ "$rem" -lt 1 ] && rem=1
                if [ "$rem" -ge 3600 ]; then eta=$(printf ' · ~%dh %02dm left' $((rem / 3600)) $(((rem % 3600) / 60)))
                elif [ "$rem" -ge 60 ]; then eta=$(printf ' · ~%dm %02ds left' $((rem / 60)) $((rem % 60)))
                else eta=$(printf ' · ~%ds left' "$rem"); fi
              fi
            fi
          fi
          info="${p_frac}${p_spd:+ · $p_spd}${eta}"
          msg="Downloading IW4X: ${p_pct}%${info:+ ($info)}" ;;
        prep)
          msg="Extracting IW4X files (please wait)…" ;;
        sync)
          if [ "$first_start" = 1 ]; then
            msg="Checking IW4X files${p_comp:+ ($p_comp)} — first start downloads ~3 GB…"
          else
            msg="Checking IW4X updates${p_comp:+ ($p_comp)}…"
          fi ;;
        run)
          msg="Starting IW4X…" ;;
      esac
      if [ -n "$msg" ] && [ "$msg" != "$last_msg" ]; then
        printf '==> %s\n' "$msg"
        last_msg=$msg
      fi
    done
  ) &
  iw4x_watch_pid=$!
}
