# Siliconium: live download progress and ETA helpers for kit scripts.
# Sourced by install-engine.sh, setup-prefix.sh, launch.sh, iw4x.sh, steam-mods.sh.

# Format remaining seconds as a compact ETA string (e.g. "~2m 15s left").
sil_fmt_eta() {   # <seconds>
  local rem=${1:-0}
  [ "$rem" -lt 1 ] && rem=1
  if [ "$rem" -ge 3600 ]; then
    printf '~%dh %02dm left' $((rem / 3600)) $(((rem % 3600) / 60))
  elif [ "$rem" -ge 60 ]; then
    printf '~%dm %02ds left' $((rem / 60)) $((rem % 60))
  else
    printf '~%ds left' "$rem"
  fi
}

# Run curl while streaming "==> <label>: ..." progress, speed and ETA to stdout.
#   sil_curl_progress <label> <expected_mb_or_0> <out_file> <curl_args...>
# The caller passes curl flags and URL without "-o <out_file>" (added here).
# Returns curl's exact exit code.
sil_curl_progress() {
  local label=$1 exp_mb=${2:-0} out=$3
  shift 3
  local cpid wpid="" rc=0
  curl "$@" -o "$out" &
  cpid=$!
  (
    local t0="" b0=0 last_mb=-1 sz now dt db mb spd exp_b rem eta pct extra msg last_msg=""
    while kill -0 "$cpid" 2>/dev/null; do
      sleep 1
      kill -0 "$cpid" 2>/dev/null || break
      [ -f "$out" ] || continue
      sz=$(stat -f %z "$out" 2>/dev/null || echo 0)
      [ "${sz:-0}" -gt 0 ] || continue
      now=$(date +%s)
      if [ -z "$t0" ]; then
        t0=$now; b0=$sz
      fi
      mb=$((sz / 1048576))
      dt=$((now - t0))
      db=$((sz - b0))
      extra=""
      if [ "$dt" -ge 2 ] && [ "$db" -gt 131072 ]; then
        spd=$(awk -v d="$db" -v t="$dt" 'BEGIN { printf "%.1f MB/s", (d / 1048576.0) / t }')
        if [ "$exp_mb" -gt 0 ]; then
          exp_b=$((exp_mb * 1048576))
          if [ "$sz" -lt "$exp_b" ]; then
            rem=$(( (exp_b - sz) * dt / db ))
            eta=$(sil_fmt_eta "$rem")
            extra=" · $spd · $eta"
          else
            extra=" · $spd"
          fi
        else
          extra=" · $spd"
        fi
      fi
      if [ "$exp_mb" -gt 0 ]; then
        pct=$((sz * 100 / (exp_mb * 1048576)))
        [ "$pct" -gt 99 ] && pct=99
        msg="${label}: ${pct}% (${mb} / ~${exp_mb} MB${extra})"
      else
        [ "$mb" -lt 1 ] && mb=1
        msg="${label}: ${mb} MB${extra}"
      fi
      if [ "$msg" != "$last_msg" ] && { [ "$mb" != "$last_mb" ] || [ -n "$extra" ]; }; then
        printf '==> %s\n' "$msg"
        last_msg=$msg
        last_mb=$mb
      fi
    done
  ) &
  wpid=$!
  wait "$cpid"
  rc=$?
  kill "$wpid" 2>/dev/null || true
  wait "$wpid" 2>/dev/null || true
  return "$rc"
}
