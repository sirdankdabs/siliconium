# Siliconium: the games of the Steam Library section, sourced by launch.sh.
# They run from Steam's own (original) files in Steam's prefix (prefix-steam);
# Steam starts them and checks their licenses. Siliconium's work is in the
# engine and the environment Steam passes on: DXVK / DXMT, the x87
# accelerator, the 1x display mode at the display's refresh rate, shader
# caches, controllers.
#
# steam_title <id> <part> sets:
#   s_exe   the game's executable          s_app   its Steam app
#   s_api   gl | d3d9 | d3d9x64 | d3d11 | d3d11x64
#   s_own   1 when the part is its own Steam app (Steam starts it); 0 when
#           the game's apps share one (the executable is started, with
#           Steam's app ID in the environment)
#   s_kind  q3 (CoD, CoD 2) | iw (CoD 4 … MW3, BO1) | t6 | iw6 (Ghosts, AW)
#   s_name  the title shown in errors
steam_title() {
  # s_async: DXVK_ASYNC. 2 compiles every new pipeline in the background, even
  # for a render target bound for the first time this frame (as for IW4X):
  # no hitch when a new effect or area appears, it shows a frame later.
  # Black Ops keeps 1 (with 2 new materials drew black until compiled, T5).
  # The 64-bit DXVK (MW2, MW3) knows only 1 (on): any other value turns it off.
  # s_pad: map (no controller support on PC: kit/tools/pad-mapper.c plays the
  # controller as keyboard and mouse) | native (the game's own, as Plutonium
  # turns on for World at War and Black Ops: never both, or input doubles)
  s_own=1 s_kind=iw s_async=2 s_pad=map
  case "$1:$2" in
    cod1:sp)  s_exe=CoDSP.exe         s_app=2620   s_api=gl       s_own=0 s_kind=q3 s_name="Call of Duty" ;;
    cod1:mp)  s_exe=CoDMP.exe         s_app=2620   s_api=gl       s_own=0 s_kind=q3 s_name="Call of Duty Multiplayer" ;;
    cod2:sp)  s_exe=CoD2SP_s.exe      s_app=2630   s_api=d3d9     s_own=0 s_kind=q3 s_name="Call of Duty 2" ;;
    cod2:mp)  s_exe=CoD2MP_s.exe      s_app=2630   s_api=d3d9     s_own=0 s_kind=q3 s_name="Call of Duty 2 Multiplayer" ;;
    cod4:sp)  s_exe=iw3sp.exe         s_app=7940   s_api=d3d9     s_own=0 s_name="Call of Duty 4" ;;
    cod4:mp)  s_exe=iw3mp.exe         s_app=7940   s_api=d3d9     s_own=0 s_name="Call of Duty 4 Multiplayer" ;;
    # World at War: with 2 its weapon and some surfaces drew half invisible
    # until their pipelines were compiled (a cold Steam copy has no cache)
    waw:sp)   s_exe=CoDWaW.exe        s_app=10090  s_api=d3d9     s_own=0 s_async=1 s_pad=native s_name="World at War" ;;
    waw:mp)   s_exe=CoDWaWmp.exe      s_app=10090  s_api=d3d9     s_own=0 s_async=1 s_pad=native s_name="World at War Multiplayer" ;;
    mw2:sp)   s_exe=iw4sp.exe         s_app=10180  s_api=d3d9x64  s_own=0 s_async=1 s_name="Modern Warfare 2" ;;
    mw2:mp)   s_exe=iw4mp.exe         s_app=10190  s_api=d3d9x64  s_async=1 s_name="Modern Warfare 2 Multiplayer" ;;
    mw3:sp)   s_exe=iw5sp.exe         s_app=42680  s_api=d3d9x64  s_async=1 s_name="Modern Warfare 3" ;;
    mw3:mp)   s_exe=iw5mp.exe         s_app=42690  s_api=d3d9x64  s_async=1 s_name="Modern Warfare 3 Multiplayer" ;;
    bo1:sp)   s_exe=BlackOps.exe      s_app=42700  s_api=d3d9     s_async=1 s_pad=native s_name="Black Ops" ;;
    bo1:mp)   s_exe=BlackOpsMP.exe    s_app=42710  s_api=d3d9     s_async=1 s_pad=native s_name="Black Ops Multiplayer" ;;
    bo2:sp)   s_exe=t6sp.exe          s_app=202970 s_api=d3d11    s_kind=t6 s_pad=native s_name="Black Ops II" ;;
    bo2:mp)   s_exe=t6mp.exe          s_app=202990 s_api=d3d11    s_kind=t6 s_pad=native s_name="Black Ops II Multiplayer" ;;
    bo2:zm)   s_exe=t6zm.exe          s_app=212910 s_api=d3d11    s_kind=t6 s_pad=native s_name="Black Ops II Zombies" ;;
    ghosts:sp) s_exe=iw6sp64_ship.exe s_app=209160 s_api=d3d11x64 s_kind=iw6 s_pad=native s_name="Ghosts" ;;
    ghosts:mp) s_exe=iw6mp64_ship.exe s_app=209170 s_api=d3d11x64 s_kind=iw6 s_pad=native s_name="Ghosts Multiplayer" ;;
    aw:sp)    s_exe=s1_sp64_ship.exe  s_app=209650 s_api=d3d11x64 s_kind=iw6 s_pad=native s_name="Advanced Warfare" ;;
    aw:mp)    s_exe=s1_mp64_ship.exe  s_app=209660 s_api=d3d11x64 s_kind=iw6 s_pad=native s_name="Advanced Warfare Multiplayer" ;;
    *) return 1 ;;
  esac
}

# Every 32-bit executable of the section: x87 maths goes to the accelerator
steam_x87_programs=CoDSP.exe:CoDMP.exe:CoD2SP_s.exe:CoD2MP_s.exe:iw3sp.exe:iw3mp.exe:CoDWaW.exe:CoDWaWmp.exe:BlackOps.exe:BlackOpsMP.exe:t6mp.exe:t6zm.exe

# Modern Warfare 2 and 3 on Steam are 64-bit Direct3D 9 games. The engine's
# DXVK is 32-bit, and Wine's own Direct3D 9 (OpenGL) is slow. Our 64-bit
# d3d9.dll (payload/dxvk64): Gcenx's DXVK-macOS 1.10.3-async with the D3D9
# part of patches/dxvk-d3d9.patch (patches/dxvk-d3d9-x64.patch): geometry
# shaders and cull distance optional (Metal has neither: stock DXVK fails to
# create its device, "DirectX encountered an unrecoverable error") and the
# depth-compare samplers on their own bindings. Native in Steam's prefix for
# those two games only (launch.sh); the game folders are not touched.
steam_dxvk64() {   # <prefix> <kit>
  local sys32="$1/drive_c/windows/system32" dll="$2/payload/dxvk64/d3d9.dll"
  [ -f "$dll" ] || return 1
  cmp -s "$dll" "$sys32/d3d9.dll" || cp "$dll" "$sys32/d3d9.dll"
}

# The command line (array s_argv): fullscreen at the display's size and
# refresh rate, no intro movies, and never the "Set Optimal Settings?" /
# safe-mode questions (com_recommendedSet 1: the detection already ran).
steam_args() {   # <width> <height> <hz> <first run: 1|0>
  local w=$1 h=$2 hz=$3 first=$4
  s_argv=()
  case "$s_kind" in
    q3)
      s_argv+=(+set r_fullscreen 1)
      if [ -n "$w" ] && [ -n "$h" ]; then
        if [ "$s_api" = gl ]; then s_argv+=(+set r_mode -1 +set r_customwidth "$w" +set r_customheight "$h")
        else s_argv+=(+set r_mode "${w}x$h"); fi
      fi
      [ -n "$hz" ] && s_argv+=(+set r_displayRefresh "$hz" +set com_maxfps "$hz") ;;
    iw)
      s_argv+=(+set com_recommendedSet 1 +set com_introPlayed 1 +set com_startupIntroPlayed 1 +set r_fullscreen 1)
      [ -n "$w" ] && [ -n "$h" ] && s_argv+=(+set r_mode "${w}x$h")
      # the frame-rate cap at the refresh rate (the games' own cap is 85-120)
      [ -n "$hz" ] && s_argv+=(+set r_displayRefresh "$hz Hz" +set com_maxfps "$hz")
      case "$s_exe" in iw4sp.exe|iw4mp.exe|iw5sp.exe|iw5mp.exe) s_argv+=(+set intro 0) ;; esac ;;
    t6) s_argv+=(+set com_recommendedSet 1 +set com_introPlayed 1) ;;
    iw6)
      # As for Ghosts' campaign (launch.sh, IW6_TUNE): borderless at the
      # display's size, no NVIDIA-only libraries, no subdivision or SSAO
      # (they faulted the GPU under DXMT); tessellation, motion blur and
      # automatic texture sizing off the first time only.
      s_argv+=(+set com_recommendedSet 1 +set r_displayMode "windowed (no border)" +set r_monitor 0)
      [ -n "$w" ] && [ -n "$h" ] && s_argv+=(+set r_mode "${w}x$h")
      [ -n "$hz" ] && s_argv+=(+set r_displayRefresh "$hz Hz")
      s_argv+=(+set cl_loadHBAODLL 0 +set cl_loadTXAADLL 0 +set r_apex_turbulence 0 +set r_ssao 0
               +set r_subdiv 0 +set r_adaptiveSubdiv 0 +set r_subdivLimit 0)
      [ "$first" = 1 ] && s_argv+=(+set r_tessellation 0 +set r_mbEnable 0 +set r_picmip_manual 1
                                   +set r_picmip 0 +set r_picmip_bump 0 +set r_picmip_spec 0) ;;
  esac
  # The games' own controller support (World at War, Black Ops): on, with
  # console aim as Siliconium sets it for Plutonium (CONSOLE_AIM=0: off)
  case "$s_exe" in
    CoDWaW.exe|CoDWaWmp.exe|BlackOps.exe|BlackOpsMP.exe)
      s_argv+=(+set gpad_enabled 1 +set gpad_stick_deadzone_min "${STICK_DEADZONE:-0.08}")
      if [ "${CONSOLE_AIM:-1}" != 0 ]; then
        s_argv+=(+set aim_accel_turnrate_enabled 1 +set aim_accel_turnrate_lerp 1200 +set aim_input_graph_enabled 1
                 +set aim_input_graph_index 3 +set aim_scale_view_axis 1 +set aim_turnrate_yaw 260 +set aim_turnrate_pitch 90
                 +set aim_turnrate_yaw_ads 90 +set aim_turnrate_pitch_ads 55 +set aim_autoaim_enabled 1
                 +set aim_lockon_enabled 1 +set aim_slowdown_enabled 1)
      fi ;;
  esac
  return 0
}

# The game's own settings file, written before every start: Steam does not
# pass Play's command line to every game (MW2 started at its 1024x768/60 Hz
# defaults). The first time: fullscreen at the display's size, no "Set
# Optimal Settings?", no intro; every time: the display's refresh rate and a
# resolution no larger than the display. What the player sets in the game
# otherwise stays. Prints nothing; the files are created when missing.
steam_config() {   # <game folder> <width> <height> <hz> <marker dir>
  local dir=$1 w=$2 h=$3 hz=$4 marks=$5 files=() f p
  case "$s_id" in
    cod4|waw)
      # profiles: the active one, else a "Player" profile made for it
      p=$(tr -d '\r\n' < "$dir/players/profiles/active.txt" 2>/dev/null)
      if [ -z "$p" ]; then p=Player; mkdir -p "$dir/players/profiles/$p"; printf '%s' "$p" > "$dir/players/profiles/active.txt"; fi
      mkdir -p "$dir/players/profiles/$p"
      files=("$dir/players/profiles/$p/config.cfg" "$dir/players/profiles/$p/config_mp.cfg") ;;
    mw2|bo1) mkdir -p "$dir/players";  files=("$dir/players/config.cfg" "$dir/players/config_mp.cfg") ;;
    mw3)     mkdir -p "$dir/players2"; files=("$dir/players2/config.cfg" "$dir/players2/config_mp.cfg") ;;
    *) return 0 ;;
  esac
  mkdir -p "$marks"
  for f in "${files[@]}"; do
    [ -f "$f" ] || printf '' > "$f"
    local m="$marks/.config-$(basename "$f")"
    if [ ! -f "$m" ]; then
      steam_cfg_set "$f" com_recommendedSet 1
      steam_cfg_set "$f" r_fullscreen 1
      [ -n "$w" ] && [ -n "$h" ] && steam_cfg_set "$f" r_mode "${w}x$h"
      steam_cfg_set "$f" com_introPlayed 1
      : > "$m"
    fi
    if [ -n "$w" ] && [ -n "$h" ]; then
      local cur
      cur=$(sed -n -E 's/^seta r_mode "([0-9]+)x([0-9]+)".*/\1 \2/p' "$f" | tail -1)
      # a mode larger than the display (the game's detection) comes back to the display's
      if [ -n "$cur" ] && { [ "${cur% *}" -gt "$w" ] || [ "${cur#* }" -gt "$h" ]; }; then steam_cfg_set "$f" r_mode "${w}x$h"; fi
    fi
    # the frame-rate cap at the refresh rate (MW2's 64-bit update defaults to 60)
    [ -n "$hz" ] && { steam_cfg_set "$f" r_displayRefresh "$hz Hz"; steam_cfg_set "$f" com_maxfps "$hz"; }
    steam_cfg_set "$f" com_recommendedSet 1
  done
}
steam_cfg_set() {   # <cfg> <name> <value>: the name in any case, kept once
  local tmp
  tmp=$(mktemp "$1.XXXXXX") || return 0
  awk -v n="$2" -v v="$3" '
    BEGIN { ln = tolower(n) }
    tolower($1) == "seta" && tolower($2) == ln { if (!done) { printf "seta %s \"%s\"\r\n", n, v; done = 1 } next }
    { print }
    END { if (!done) printf "seta %s \"%s\"\r\n", n, v }
  ' "$1" > "$tmp" && mv -f "$tmp" "$1" || rm -f "$tmp"
}
