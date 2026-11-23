#!/bin/bash
# Siliconium: the macOS half of the in-game switch between a game's parts
# (tools/silrelay.c). Runs beside Steam (started by steam.sh, one at a time):
# when Steam starts one of the Steam Library's executables itself (a campaign's
# Multiplayer / Zombies button: steam://run/<app>), silrelay.exe leaves its
# command line in <prefix-steam>/drive_c/users/Public/Siliconium/relay; the
# executable picks the Steam Library row (tools/steam-games.sh) and the row
# starts through launch.sh with the rest of the command line as GAME_ARGS
# (Advanced Warfare's Exo Zombies: +zombiesMode 1), with every setting and
# fix it gets from Siliconium's Play button. launch.sh closes and reopens
# Steam with its environment, as for any start. Anything else (an executable
# Siliconium does not know, or a start launch.sh itself asked Steam for:
# relay/bypass-<app>) runs as Steam would have run it.
kit=$(cd -- "$(dirname -- "$0")/.." && pwd)
home=${SIL_HOME:-"$HOME/Library/Application Support/Siliconium"}
rd="$home/prefix-steam/drive_c/users/Public/Siliconium/relay"
pidfile="$home/cache/steam-relay.pid"
log="$home/logs/steam-relay.log"
mkdir -p "$rd" "$home/cache" "$home/logs" || exit 1
old=$(cat "$pidfile" 2>/dev/null)
if [ -n "$old" ] && [ "$old" != $$ ] && ps -p "$old" -o command= 2>/dev/null | grep -q 'steam-relay\.sh'; then
  exit 0   # one is running
fi
echo $$ > "$pidfile"
# shellcheck source=steam-games.sh
. "$kit/tools/steam-games.sh"
rows=$(sed -n 's/^ *\([a-z0-9]*:[a-z]*\)) *s_exe=.*/\1/p' "$kit/tools/steam-games.sh")
row_of() {   # executable name → id-part
  local r exe
  exe=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  for r in $rows; do
    steam_title "${r%%:*}" "${r#*:}"
    [ "$(printf '%s' "$s_exe" | tr '[:upper:]' '[:lower:]')" = "$exe" ] && { echo "${r%%:*}-${r#*:}"; return 0; }
  done
  return 1
}
answer() { printf '%s' "$2" > "$rd/ans-$1.tmp" && mv -f "$rd/ans-$1.tmp" "$rd/ans-$1.txt"; }
steam_up() { pgrep -f 'Program Files \(x86\)\\Steam\\[Ss]team\.exe' >/dev/null 2>&1; }
# Steam asks which launch option to start (Advanced Warfare's Multiplayer /
# Exo / Exo Zombies) in a small window that opened behind the other apps:
# bring Steam's window forward when its console log says it is waiting
clog="$home/prefix-steam/drive_c/Program Files (x86)/Steam/logs/console_log.txt"
clines=$(wc -l < "$clog" 2>/dev/null | tr -d ' '); clines=${clines:-0}
front_steam() {
  osascript -e 'tell application "System Events" to set frontmost of (every process whose name is "steamwebhelper.exe" and visible is true) to true' > /dev/null 2>&1
}
idle=0 seen=
while :; do
  now=$(wc -l < "$clog" 2>/dev/null | tr -d ' '); now=${now:-0}
  [ "$now" -lt "$clines" ] && clines=0   # a new log
  if [ "$now" -gt "$clines" ]; then
    new=$(tail -n +$((clines + 1)) "$clog" 2>/dev/null | head -n $((now - clines)))
    # WWII (s2): its campaign's Multiplayer / Nazi Zombies buttons ask Steam for
    # steam://run/476620//+zombiesMode 1; Steam then asks for a launch option and
    # to confirm the arguments, the second inside Steam's main window, which
    # stays minimized on the Mac (nothing to click, 2026-11-22). The relay starts
    # that part itself (launch.sh closes and reopens Steam, which drops Steam's
    # questions), unless launch.sh asked Steam for it (relay/bypass-<app>)
    took=
    while IFS= read -r url; do
      app=${url#steam://run/}; app=${app%%/*}; args=
      case "$url" in "steam://run/$app//"*) args=${url#"steam://run/$app//"} ;; esac
      args=$(/usr/bin/python3 -I -c 'import sys, urllib.parse; print(urllib.parse.unquote(sys.argv[1]))' "$args" 2>/dev/null)
      row=
      for r in $rows; do
        steam_title "${r%%:*}" "${r#*:}"
        [ "$s_app" = "$app" ] && [ "$s_kind" = s2 ] && { row="${r%%:*}-${r#*:}"; break; }
      done
      [ -n "$row" ] || continue
      # Nazi Zombies has its own row (the same executable with +zombiesMode 1)
      case " $args " in *" +zombiesMode 1 "*)
        if steam_title "${row%-*}" zm 2> /dev/null && [ "$s_app" = "$app" ]; then
          row="${row%-*}-zm"; args=$(printf '%s' " $args " | sed 's/ +zombiesMode 1 / /; s/^ *//; s/ *$//')
        fi ;;
      esac
      bypass="$rd/bypass-$app"
      if [ -f "$bypass" ] && [ $(( $(date +%s) - $(stat -f %m "$bypass") )) -lt 120 ]; then continue; fi
      took=1
      printf '%s relay: steam://run/%s %s → launch.sh steam %s\n' "$(date '+%F %T')" "$app" "$args" "$row" >> "$log"
      (GAME_ARGS="$args" nohup bash "$kit/launch.sh" steam "$row" >> "$log" 2>&1 &)
    done < <(printf '%s\n' "$new" | sed -n -E 's/.*ExecuteSteamURL: "(steam:\/\/run\/[0-9]+[^"]*)".*/\1/p')
    [ -z "$took" ] && printf '%s\n' "$new" | grep -q 'waiting for user response to ShowLaunchOption' &&
      { front_steam; printf '%s relay: Steam launch-option window brought forward\n' "$(date '+%F %T')" >> "$log"; }
    clines=$now
  fi
  for req in "$rd"/req-*.txt; do
    [ -f "$req" ] || continue
    n=${req##*/req-}; n=${n%.txt}
    cmd=$(cat "$req"); rm -f "$req"
    if [ "${cmd#\"}" != "$cmd" ]; then
      path=${cmd#\"}; path=${path%%\"*}; args=${cmd#\""$path"\"}
    else
      path=${cmd%% *}; args=${cmd#"$path"}
    fi
    args=$(printf '%s' "$args" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    exe=${path##*\\}
    row=$(row_of "$exe") app=
    [ -n "$row" ] && steam_title "${row%-*}" "${row##*-}" && app=$s_app
    bypass="$rd/bypass-$app"
    if [ -n "$row" ] && ! { [ -f "$bypass" ] && [ $(( $(date +%s) - $(stat -f %m "$bypass") )) -lt 120 ]; }; then
      answer "$n" launched
      printf '%s relay: %s %s → launch.sh steam %s\n' "$(date '+%F %T')" "$exe" "$args" "$row" >> "$log"
      (GAME_ARGS="$args" nohup bash "$kit/launch.sh" steam "$row" >> "$log" 2>&1 &)
    else
      rm -f "$bypass"
      answer "$n" run
      printf '%s relay: %s %s → as Steam starts it\n' "$(date '+%F %T')" "$exe" "$args" >> "$log"
    fi
  done
  if steam_up; then idle=0 seen=1; else idle=$((idle + 1)); fi
  # Steam closes and reopens around every start: leave only once it stays closed
  # (or never came up)
  [ "$idle" -ge $([ -n "$seen" ] && echo 30 || echo 180) ] && break
  sleep 1
done
[ "$(cat "$pidfile" 2>/dev/null)" = $$ ] && rm -f "$pidfile"
