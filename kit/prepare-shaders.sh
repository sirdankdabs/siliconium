#!/bin/bash
# Siliconium: compile a game's shaders for every map, once.
#
# The first time a map loads, DXVK compiles its pipelines in the background
# (so the game never freezes), and until one is ready its material is not
# drawn: the map and the weapon appear bit by bit for the first seconds. This
# loads each map in turn, offline, and waits until its compilation settles, so
# every map is complete the first time it is played. Afterwards the caches
# (DXVK's state cache, our MoltenVK cache and Metal's) keep them.
#
#   prepare-shaders.sh <game> [zm|mp|all|<map>...]
#     game: bo1 (default), waw, iw4, bo2 (DXMT: its own shader cache)
#     (not Modern Warfare 3: Plutonium's IW5 ignores +map/+devmap at start)
#
# Only the maps whose files are in the game folder are prepared. A map that
# does not load within 4 minutes is skipped and reported.
# Progress lines start with "==> "; errors with "ERROR: ".
set -uo pipefail
kit=$(cd -- "$(dirname -- "$0")" && pwd)
home=${SIL_HOME:-"$HOME/Library/Application Support/Siliconium"}
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/tools/migrate.sh"   # an install of the previous name
step() { printf '==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

case "${1:-bo1}" in
  bo1|waw|iw4|bo2) game=${1:-bo1}; shift ;;
  *) game=bo1 ;;
esac
conf() { sed -n "s/^$1=//p" "$home/settings.conf" 2>/dev/null | tail -1; }
case "$game" in
  bo1) dir=${BO1_DIR:-$(conf BO1_DIR)}
    zm="zombie_theater zombie_pentagon zombie_cosmodrome zombie_coast zombie_temple zombie_moon
zombie_cod5_prototype zombie_cod5_asylum zombie_cod5_sumpf zombie_cod5_factory"
    mp="mp_array mp_cracked mp_crisis mp_firingrange mp_duga mp_hanoi mp_cairo mp_havoc mp_cosmodrome
mp_nuked mp_radiation mp_mountain mp_villa mp_russianbase mp_berlinwall2 mp_discovery mp_kowloon
mp_stadium mp_gridlock mp_hotel mp_outskirts mp_zoo mp_drivein mp_area51 mp_golfcourse mp_silo" ;;
  waw) dir=${WAW_DIR:-$(conf WAW_DIR)}
    zm="nazi_zombie_prototype nazi_zombie_asylum nazi_zombie_sumpf nazi_zombie_factory"
    mp="mp_airfield mp_asylum mp_bgate mp_castle mp_courtyard mp_docks mp_dome mp_downfall mp_drum
mp_hangar mp_kneedeep mp_kwai mp_makin mp_makin_day mp_nachtfeuer mp_outskirts mp_roundhouse
mp_seelow mp_shrine mp_stalingrad mp_suburban mp_subway mp_vodka" ;;
  iw4) dir=${IW4_DIR:-$(conf IW4_DIR)}
    zm=""
    mp="mp_afghan mp_derail mp_estate mp_favela mp_highrise mp_invasion mp_checkpoint mp_quarry
mp_rundown mp_rust mp_boneyard mp_nightshift mp_subbase mp_terminal mp_underpass mp_brecourt
mp_complex mp_compact mp_storm mp_abandon mp_fuel2 mp_trailerpark mp_crash mp_overgrown mp_strike
mp_vacant mp_nuked mp_cross_fire mp_cargoship mp_bloc mp_killhouse mp_firingrange mp_shipment_long
mp_rust_long mp_farm mp_backlot mp_pipeline mp_countdown mp_carentan mp_crash_snow" ;;
  iw5) dir=${IW5_DIR:-$(conf IW5_DIR)}
    zm=""
    mp="mp_alpha mp_bootleg mp_bravo mp_carbon mp_dome mp_exchange mp_hardhat mp_interchange
mp_lambeth mp_mogadishu mp_paris mp_plaza2 mp_radar mp_seatown mp_underground mp_village
mp_aground_ss mp_courtyard_ss mp_hillside_ss mp_restrepo_ss mp_crosswalk_ss mp_burn_ss mp_six_ss
mp_italy mp_park mp_overwatch mp_morningwood mp_meteora mp_qadeem mp_cement mp_shipbreaker
mp_roughneck mp_moab mp_boardwalk mp_nola mp_terminal_cls mp_favela mp_highrise mp_nightshift
mp_nuked mp_rust" ;;
  bo2) dir=${BO2_DIR:-$(conf BO2_DIR)}
    # zombies: map:start location:game mode (Plutonium needs both to start a map)
    zm="zm_transit:transit:zclassic zm_nuked:nuked:zstandard zm_highrise:rooftop:zclassic
zm_prison:prison:zclassic zm_buried:processing:zclassic zm_tomb:tomb:zclassic"
    mp="mp_la mp_dockside mp_carrier mp_drone mp_express mp_hijacked mp_meltdown mp_overflow
mp_nightclub mp_raid mp_slums mp_village mp_turbine mp_socotra mp_nuketown_2020 mp_downhill
mp_mirage mp_hydro mp_skate mp_concert mp_magma mp_vertigo mp_studio mp_uplink mp_bridge
mp_castaway mp_paintball mp_dig mp_frostbite mp_pod mp_takeoff" ;;
esac
[ -n "$dir" ] && [ -d "$dir/zone" ] || die "choose the game folder first"
# DXMT (Black Ops II) keeps its compiled shaders here, per program
dxmt_cache="$(getconf DARWIN_USER_CACHE_DIR 2>/dev/null)/dxmt/plutonium-bootstrapper-win32.exe"
cache_size() { if [ -d "$1" ]; then du -sk "$1" 2>/dev/null | cut -f1; else stat -f %z "$1" 2>/dev/null || echo 0; fi; }

sel=${1:-all}
case "$sel" in
  zm) maps=$zm ;; mp) maps=$mp ;; all) maps="$zm $mp" ;; *) maps="$*" ;;
esac
# keep the maps this copy of the game has
have=
plut="$home/prefix/drive_c/users/crossover/AppData/Local/Plutonium/storage/$game"
for m in $maps; do
  if find "$dir/zone" -maxdepth 2 -name "${m%%:*}.ff" -print -quit 2>/dev/null | grep . > /dev/null ||
     find "$plut/zone" -maxdepth 2 -name "${m%%:*}.ff" -print -quit 2>/dev/null | grep . > /dev/null; then
    have="$have $m"
  fi
done
maps=$have
[ -n "$maps" ] || die "no maps of this game were found in its zone folder"

trap '"$kit/launch.sh" stop >/dev/null 2>&1; exit 130' INT TERM
"$kit/launch.sh" stop >/dev/null 2>&1
n=0 total=$(echo $maps | wc -w | tr -d ' ') failed=0
for entry in $maps; do
  n=$((n + 1))
  map=${entry%%:*} extra=
  case "$entry" in
    *:*:*) loc=${entry#*:}; extra="+set ui_zm_mapstartlocation ${loc%%:*} +set ui_zm_gamemodegroup ${loc#*:} +set g_gametype ${loc#*:}" ;;
  esac
  case "$game:$map" in
    iw5:*)    mode=mp;      scache="$home/cache/iw5/plutonium-bootstrapper-win32.dxvk-cache" ;;
    bo2:mp_*) mode=mp;      scache=$dxmt_cache ;;
    bo2:*)    mode=zombies; scache=$dxmt_cache ;;
    iw4:*)  mode=play;    scache="$home/cache/iw4x.dxvk-cache" ;;
    *:mp_*) mode=mp
            scache="$home/cache/plutonium-bootstrapper-win32.dxvk-cache"
            [ "$game" = bo1 ] && scache="$home/cache/bo1-mp/plutonium-bootstrapper-win32.dxvk-cache" ;;
    *)      mode=zombies; scache="$home/cache/plutonium-bootstrapper-win32.dxvk-cache" ;;
  esac
  log="$home/logs/$game-$mode.log"
  # MW3 does not print its console there: Plutonium's console.log names the map
  # as it loads ("maps/mp/<map>_fx.gsc")
  [ "$game" = iw5 ] && log="$home/prefix/drive_c/users/crossover/AppData/Local/Plutonium/console.log"
  step "[$n/$total] $map"
  rm -f "$log"
  # offline (-lan for Plutonium): no sign-in, and the map loads directly
  if [ "$game" = iw4 ]; then
    GAME_ARGS="+devmap $map" "$kit/launch.sh" iw4 play Player < /dev/null > /dev/null 2>&1 &
  else
    GAME_ARGS="$extra +devmap $map" "$kit/launch.sh" "$game" "$mode" Player --lan < /dev/null > /dev/null 2>&1 &
  fi
  start=$(date +%s) seen=0 ok=0
  while [ $(( $(date +%s) - start )) -lt 240 ]; do
    sleep 3
    # grep reads all of it (-q would close the pipe early, and with pipefail
    # sed's SIGPIPE made the test fail on a long log)
    sed 's/\x1b\[[0-9;]*[A-Za-z]//g' "$log" 2>/dev/null |
      grep -E "Loading fastfile '?$map'?([^a-z0-9_]|\$)|maps/mp/${map}(_fx)?\.gsc" > /dev/null && seen=1
    [ "$seen" = 1 ] || continue
    # the map is compiled when DXVK's state cache stops growing
    a=$(cache_size "$scache")
    sleep 12
    b=$(cache_size "$scache")
    # DXMT's folder (sizes in KB) keeps creeping up as the camera moves: a
    # trickle under 256 KB in 12 s means the map's shaders are done
    if [ -d "$scache" ]; then [ $((b - a)) -le 256 ] && { ok=1; break; }
    else [ "$a" = "$b" ] && { ok=1; break; }; fi
  done
  # four minutes on the loaded map compiled what it shows first
  [ $ok = 0 ] && [ $seen = 1 ] && ok=1
  "$kit/launch.sh" stop >/dev/null 2>&1
  sleep 3
  if [ $ok = 1 ]; then step "[$n/$total] $map ready"
  else printf 'ERROR: %s did not finish loading\n' "$map" >&2; failed=$((failed + 1)); fi
done
[ $failed = 0 ] && step "All $total maps are ready" || die "$failed of $total maps did not finish"
