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
#   s_own   1: Steam starts it (-applaunch); 0: the executable is started,
#           with Steam's app ID in the environment. A game Steam starts
#           opens behind the other apps (Windows' foreground rule: Steam is
#           not the foreground app), so on a captured display the player
#           saw only black (MW2 Multiplayer): 0 wherever the game allows it.
#   s_kind  q3 (CoD, CoD 2) | iw (CoD 4 … MW3, BO1) | t6 | iw6 (Ghosts) | s1 (AW) | t7 (BO3)
#           | iw7 (Infinite Warfare)
#   s_name  the title shown in errors
steam_title() {
  # s_async: DXVK_ASYNC. 2 compiles every new pipeline in the background, even
  # for a render target bound for the first time this frame (as for IW4X):
  # no hitch when a new effect or area appears, it shows a frame later.
  # Black Ops keeps 1 (with 2 new materials drew black until compiled, T5).
  # The 64-bit DXVK (MW2, MW3) knows 1 and 2 (patches/dxvk-x64-async2.patch);
  # MW3 keeps 1: with 2 its world was not drawn and the HUD text smeared
  # across the screen (Steam, 2026-11-19), as Plutonium's MW3 drew HUD
  # numbers twice.
  # s_pad: map (no controller support on PC: kit/tools/pad-mapper.c plays the
  # controller as keyboard and mouse) | native (the game's own, as Plutonium
  # turns on for World at War and Black Ops: never both, or input doubles)
  s_own=1 s_kind=iw s_async=2 s_pad=map
  case "$1:$2" in
    cod1:sp)  s_exe=CoDSP.exe         s_app=2620   s_api=gl       s_own=0 s_kind=q3 s_name="Call of Duty" ;;
    cod1:mp)  s_exe=CoDMP.exe         s_app=2620   s_api=gl       s_own=0 s_kind=q3 s_name="Call of Duty Multiplayer" ;;
    # United Offensive (the expansion: its own Steam app, installed into Call of
    # Duty's folder, its files in uo/): the same engine, setup as Call of Duty
    uo:sp)    s_exe=CoDUOSP.exe       s_app=2640   s_api=gl       s_own=0 s_kind=q3 s_name="United Offensive" ;;
    uo:mp)    s_exe=CoDUOMP.exe       s_app=2640   s_api=gl       s_own=0 s_kind=q3 s_name="United Offensive Multiplayer" ;;
    cod2:sp)  s_exe=CoD2SP_s.exe      s_app=2630   s_api=d3d9     s_own=0 s_kind=q3 s_name="Call of Duty 2" ;;
    cod2:mp)  s_exe=CoD2MP_s.exe      s_app=2630   s_api=d3d9     s_own=0 s_kind=q3 s_name="Call of Duty 2 Multiplayer" ;;
    cod4:sp)  s_exe=iw3sp.exe         s_app=7940   s_api=d3d9     s_own=0 s_name="Call of Duty 4" ;;
    cod4:mp)  s_exe=iw3mp.exe         s_app=7940   s_api=d3d9     s_own=0 s_name="Call of Duty 4 Multiplayer" ;;
    # World at War: with 2 its weapon and some surfaces drew half invisible
    # until their pipelines were compiled (a cold Steam copy has no cache)
    waw:sp)   s_exe=CoDWaW.exe        s_app=10090  s_api=d3d9     s_own=0 s_async=1 s_pad=native s_name="World at War" ;;
    waw:mp)   s_exe=CoDWaWmp.exe      s_app=10090  s_api=d3d9     s_own=0 s_async=1 s_pad=native s_name="World at War Multiplayer" ;;
    mw2:sp)   s_exe=iw4sp.exe         s_app=10180  s_api=d3d9x64  s_own=0 s_async=2 s_name="Modern Warfare 2" ;;
    mw2:mp)   s_exe=iw4mp.exe         s_app=10190  s_api=d3d9x64  s_own=0 s_async=2 s_name="Modern Warfare 2 Multiplayer" ;;
    mw3:sp)   s_exe=iw5sp.exe         s_app=42680  s_api=d3d9x64  s_own=0 s_async=1 s_name="Modern Warfare 3" ;;
    mw3:mp)   s_exe=iw5mp.exe         s_app=42690  s_api=d3d9x64  s_own=0 s_async=1 s_name="Modern Warfare 3 Multiplayer" ;;
    bo1:sp)   s_exe=BlackOps.exe      s_app=42700  s_api=d3d9     s_own=0 s_async=1 s_pad=native s_name="Black Ops" ;;
    bo1:mp)   s_exe=BlackOpsMP.exe    s_app=42710  s_api=d3d9     s_own=0 s_async=1 s_pad=native s_name="Black Ops Multiplayer" ;;
    bo2:sp)   s_exe=t6sp.exe          s_app=202970 s_api=d3d11    s_own=0 s_kind=t6 s_pad=native s_name="Black Ops II" ;;
    bo2:mp)   s_exe=t6mp.exe          s_app=202990 s_api=d3d11    s_own=0 s_kind=t6 s_pad=native s_name="Black Ops II Multiplayer" ;;
    bo2:zm)   s_exe=t6zm.exe          s_app=212910 s_api=d3d11    s_own=0 s_kind=t6 s_pad=native s_name="Black Ops II Zombies" ;;
    ghosts:sp) s_exe=iw6sp64_ship.exe s_app=209160 s_api=d3d11x64 s_own=0 s_kind=iw6 s_pad=native s_name="Ghosts" ;;
    ghosts:mp) s_exe=iw6mp64_ship.exe s_app=209170 s_api=d3d11x64 s_own=0 s_kind=iw6 s_pad=native s_name="Ghosts Multiplayer" ;;
    aw:sp)    s_exe=s1_sp64_ship.exe  s_app=209650 s_api=d3d11x64 s_own=0 s_kind=s1 s_pad=native s_name="Advanced Warfare" ;;
    aw:mp)    s_exe=s1_mp64_ship.exe  s_app=209660 s_api=d3d11x64 s_own=0 s_kind=s1 s_pad=native s_name="Advanced Warfare Multiplayer" ;;
    # Black Ops III: one executable for the campaign, Zombies and Multiplayer
    # (chosen in its menu); its own setup (t7: BOIII's, see steam_config)
    bo3:sp)   s_exe=BlackOps3.exe     s_app=311210 s_api=d3d11x64 s_own=0 s_kind=t7 s_pad=native s_name="Black Ops III" ;;
    # Infinite Warfare: one executable for the campaign, Multiplayer and
    # Zombies in Spaceland (chosen in its menu); its own setup (iw7): nothing
    # is taken from Ghosts / Advanced Warfare until tested on it
    iw:sp)    s_exe=iw7_ship.exe      s_app=292730 s_api=d3d11x64 s_own=0 s_kind=iw7 s_pad=native s_name="Infinite Warfare" ;;
    *) return 1 ;;
  esac
}

# Call of Duty and United Offensive (OpenGL) draw through our GLDirect
# (OpenGL on Direct3D 9, launch.sh); COD1_GLDIRECT / UO_GLDIRECT=0: Apple's
# OpenGL instead
steam_gldirect() {
  case "${s_id:-}" in
    cod1) [ "${COD1_GLDIRECT:-1}" = 1 ] ;;
    uo)   [ "${UO_GLDIRECT:-1}" = 1 ] ;;
    *)    return 1 ;;
  esac
}

# Every 32-bit executable of the section: x87 maths goes to the accelerator
steam_x87_programs=CoDSP.exe:CoDMP.exe:CoDUOSP.exe:CoDUOMP.exe:CoD2SP_s.exe:CoD2MP_s.exe:iw3sp.exe:iw3mp.exe:CoDWaW.exe:CoDWaWmp.exe:BlackOps.exe:BlackOpsMP.exe:t6mp.exe:t6zm.exe

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
      # Call of Duty 2 (Direct3D 9, DXVK): its refresh setting reads "<n> Hz"
      # and r_swapInterval is its vsync (off: the frame cap paces it)
      if [ "$s_api" = d3d9 ]; then
        [ -n "$hz" ] && s_argv+=(+set r_displayRefresh "$hz Hz" +set com_maxfps "$hz")
        s_argv+=(+set r_swapInterval 0)
      else
        [ -n "$hz" ] && s_argv+=(+set r_displayRefresh "$hz" +set com_maxfps "$hz")
      fi ;;
    iw)
      s_argv+=(+set com_recommendedSet 1 +set com_introPlayed 1 +set com_startupIntroPlayed 1 +set r_fullscreen 1)
      [ -n "$w" ] && [ -n "$h" ] && s_argv+=(+set r_mode "${w}x$h")
      # the frame-rate cap at the refresh rate (the games' own cap is 85-120)
      [ -n "$hz" ] && s_argv+=(+set r_displayRefresh "$hz Hz" +set com_maxfps "$(steam_maxfps "$hz")")
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
      # Ghosts' enum values as its own path writes them ("0_Off"); Advanced
      # Warfare keeps 0 until it is tested
      local off=0; [ "$s_id" = ghosts ] && off=0_Off
      s_argv+=(+set cl_loadHBAODLL 0 +set cl_loadTXAADLL 0 +set r_apex_turbulence 0 +set r_ssao "$off"
               +set r_subdiv 0 +set r_adaptiveSubdiv 0 +set r_subdivLimit 0)
      [ "$first" = 1 ] && s_argv+=(+set r_tessellation "$off" +set r_mbEnable 0 +set r_picmip_manual 1
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
  # World at War's campaign: its profile (in AppData) names the console's
  # layout "buttons_default", which the PC game does not have, so the
  # controller had no bindings at all. The first time (no button bound yet):
  # the PC game's own default layouts, as choosing them in its menu does;
  # afterwards the player's choice stays. The multiplayer (CoDWaWmp.exe) has
  # the same default and the same layouts (main/iw_00.iwd) and keeps its
  # bindings in the same profile's config_mp.cfg
  if [ "$s_exe" = CoDWaW.exe ] || [ "$s_exe" = CoDWaWmp.exe ]; then
    local wp p wc=config.cfg
    [ "$s_exe" = CoDWaWmp.exe ] && wc=config_mp.cfg
    wp=$(ls -d "$WINEPREFIX"/drive_c/users/*/AppData/Local/Activision/CoDWaW/players/profiles 2>/dev/null | head -1)
    p=$(tr -d '\r\n' 2>/dev/null < "$wp/active.txt")
    if ! grep -q '^bind BUTTON_' "$wp/$p/$wc" 2>/dev/null; then
      s_argv+=(+set gpad_sticksConfig thumbstick_default +exec thumbstick_default +exec buttons_default_alt)
    fi
  fi
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
    cod1)    mkdir -p "$dir/Main"; files=("$dir/Main/config.cfg" "$dir/Main/config_mp.cfg") ;;
    uo)      mkdir -p "$dir/uo";   files=("$dir/uo/uoconfig.cfg" "$dir/uo/uoconfig_mp.cfg") ;;
    cod2)
      # Call of Duty 2: the active profile's files (main/players/<profile>,
      # made by the game on its first start); its settings load after the
      # command line, so without this a new profile played at 640x480/60 Hz
      p=$(tr -d '\r\n' < "$dir/main/players/active.txt" 2>/dev/null)
      [ -n "$p" ] && [ -d "$dir/main/players/$p" ] || return 0
      files=("$dir/main/players/$p/config.cfg" "$dir/main/players/$p/config_mp.cfg")
      mkdir -p "$marks"
      for f in "${files[@]}"; do
        [ -f "$f" ] || continue
        local m="$marks/.config-cod2-$p-$(basename "$f")" cur
        if [ ! -f "$m" ]; then
          steam_cfg_set "$f" r_fullscreen 1
          [ -n "$w" ] && [ -n "$h" ] && steam_cfg_set "$f" r_mode "${w}x$h"
          # trilinear filtering: the first-start detection picks bilinear on
          # Apple GPUs, and textures then visibly switch detail as the player
          # moves closer/away (owner, 2026-11-20: better with trilinear)
          steam_cfg_set "$f" r_textureMode trilinear
          : > "$m"
        fi
        if [ -n "$w" ] && [ -n "$h" ]; then
          cur=$(sed -n -E 's/^seta r_mode "([0-9]+)x([0-9]+)".*/\1 \2/p' "$f" | tail -1)
          if [ -n "$cur" ] && { [ "${cur% *}" -gt "$w" ] || [ "${cur#* }" -gt "$h" ]; }; then steam_cfg_set "$f" r_mode "${w}x$h"; fi
        fi
        [ -n "$hz" ] && { steam_cfg_set "$f" r_displayRefresh "$hz Hz"; steam_cfg_set "$f" com_maxfps "$hz"; }
        steam_cfg_set "$f" r_swapInterval 0
        # Straight to the menu, as with Plutonium (SKIP_INTRO): the logo and
        # intro movies (cinematic IW_logo / cod_intro) froze the game at
        # random right after the menu loaded (console.log: nextmap cinematic)
        [ "${SKIP_INTRO:-1}" != 0 ] && steam_cfg_set "$f" com_introPlayed 1
      done
      return 0 ;;
    ghosts)
      # Ghosts: what Siliconium's own Ghosts writes (launch.sh, t=iw6) in the
      # profile it reads before opening its swap chain: borderless at the
      # desktop's size and rate unless the player chose a window, and
      # (IW6_TUNE) no NVIDIA libraries, SSAO or tessellation (both page-faulted
      # the GPU under DXMT) or subdivision every start; motion blur, fur and
      # automatic texture sizing off the first time only. The multiplayer
      # (iw6mp64_ship.exe: same renderer and setting names) keeps its own in
      # players2/config_mp.cfg (its strings: players2, config_mp.cfg)
      case "$s_part" in sp) f="$dir/players2/config.cfg" ;; mp) f="$dir/players2/config_mp.cfg" ;; *) return 0 ;; esac
      mkdir -p "$dir/players2" "$marks" && { [ -f "$f" ] || : > "$f"; } || return 0
      if ! grep -Eiq '^[[:space:]]*seta[[:space:]]+r_displayMode[[:space:]]+"windowed( \(no border\))?"' "$f"; then
        steam_cfg_set "$f" com_recommendedSet 1
        steam_cfg_set "$f" r_displayMode "windowed (no border)"
        steam_cfg_set "$f" r_monitor 0
        [ -n "$w" ] && [ -n "$h" ] && steam_cfg_set "$f" r_mode "${w}x$h"
        [ -n "$hz" ] && steam_cfg_set "$f" r_displayRefresh "$hz Hz"
      fi
      if on IW6_TUNE; then
        # SSAO and tessellation every start: both page-faulted the GPU on Steam's
        # Ghosts (2026-11-20: SSAO High after ~3.5 min, tessellation Near after
        # ~45 s; with both, Apple's shader compiler crashed), even when the
        # player turned them on in the game's options
        for p in cl_loadHBAODLL=0 cl_loadTXAADLL=0 r_apex_turbulence=0 r_ssao=0_Off r_tessellation=0_Off r_subdivLimit=0; do
          steam_cfg_set "$f" "${p%%=*}" "${p#*=}"
        done
        if [ ! -f "$marks/.defaults-ghosts-$s_part" ]; then
          for p in r_mbEnable=0 r_mbEnableA=0 r_fur_shader=0 r_picmip_manual=1 \
                   r_picmip=0 r_picmip_bump=0 r_picmip_spec=0 r_picmip_water=0; do
            steam_cfg_set "$f" "${p%%=*}" "${p#*=}"
          done
          : > "$marks/.defaults-ghosts-$s_part"
        fi
      fi
      return 0 ;;
    aw)
      # Advanced Warfare's campaign (its own names, read from the profile it
      # made on its first start): left alone it chose exclusive fullscreen at
      # the panel's 3840x2160 and 60 Hz (r_refreshRate "60.00 Hz"), over the
      # 1x mode launch.sh holds. Every start: the desktop's size and the held
      # mode's rate; once: fullscreen (not a window) and 16x anisotropic
      # filtering (it picked 4x on the Apple GPU)
      # Multiplayer / Exo Zombies (s1_mp64_ship.exe): the same settings in its
      # own profile, players2/config_mp.cfg as in the other IW engines (not yet
      # confirmed against the file it makes on its first start)
      case "$s_part" in sp) f="$dir/players2/config.cfg" ;; mp) f="$dir/players2/config_mp.cfg" ;; *) return 0 ;; esac
      mkdir -p "$dir/players2" "$marks" && { [ -f "$f" ] || : > "$f"; } || return 0
      [ -n "$w" ] && [ -n "$h" ] && steam_cfg_set "$f" r_mode "${w}x$h"
      [ -n "$hz" ] && steam_cfg_set "$f" r_refreshRate "$hz.00 Hz"
      if [ ! -f "$marks/.defaults-aw-$s_part" ]; then
        steam_cfg_set "$f" r_fullscreen 1
        steam_cfg_set "$f" r_fullscreenWindow 0
        steam_cfg_set "$f" r_texFilterAnisoMax 16
        : > "$marks/.defaults-aw-$s_part"
      fi
      return 0 ;;
    bo3)
      # Black Ops III: what Siliconium writes for BOIII (Ezz's client, launch.sh
      # t=t7) in the same settings file (BOIII uses boiii_players/config.ini,
      # Steam's game players/config.ini). Once (BOIII_GRAPHICS): its
      # auto-detect does not know Apple GPUs (half resolution, no shadows), so
      # fullscreen at the display's size and rate, full resolution and detail;
      # volumetric lighting and subsurface scattering off (the costliest passes
      # on Apple GPUs). Every start (BOIII_SCREEN): fullscreen at the display's
      # size and rate, and the frame cap at that rate (its own default is 60).
      f="$dir/players/config.ini"
      mkdir -p "$dir/players" "$marks" && { [ -f "$f" ] || : > "$f"; } || return 0
      if on BOIII_GRAPHICS && [ ! -f "$marks/.defaults-bo3" ] && [ -n "$w" ] && [ -n "$h" ]; then
        for p in AutoDetectHasRun=1 RestrictGraphicsOptions=0 FullScreenMode=1 "WindowSize=${w}x$h" \
                 "RefreshRate=${hz:-60}" Vsync=1 ResolutionPercent=100 MeshQuality=0 TextureQuality=0 \
                 TextureFilter=2 DisableDynamicLightShadows=0 DisableDynamicSunShadows=0 ShadowFiltering=1 \
                 VolumetricLightingEnabled=0 "SSAOTechnique=GTAO Medium Quality" \
                 "AATechnique=Filmic SMAA T2x" SubsurfaceScattering=0 MotionBlur=Off; do
          steam_ini_set "$f" "${p%%=*}" "${p#*=}"
        done
        : > "$marks/.defaults-bo3"
      fi
      if on BOIII_SCREEN && [ -n "$w" ] && [ -n "$h" ]; then
        steam_ini_set "$f" FullScreenMode 1
        steam_ini_set "$f" WindowSize "${w}x$h"
        [ -n "$hz" ] && steam_ini_set "$f" RefreshRate "$hz"
        steam_ini_set "$f" MaxFPS "${maxfps:-${hz:-0}}"
      fi
      return 0 ;;
    iw)
      # Infinite Warfare: one profile for every mode, players2/config_mp.cfg
      # (Steam Cloud's list names it too). Its settings are saved by hash, not
      # by name (`setcl <hash> "value"`), so only two values are written, each
      # identified on this Mac (session 20): 1984923617 = the resolution
      # ("1920x1080" on its first start; the game replaces a size the display
      # has no mode for) and -1226230005 = the refresh rate ("60.00 Hz", the
      # only Hz value, AW's r_refreshRate format). Left alone it starts in
      # exclusive fullscreen at what it saved. Every start (IW7_SCREEN): the
      # desktop's size and the rate of the mode launch.sh holds.
      f="$dir/players2/config_mp.cfg"
      on IW7_SCREEN || return 0
      mkdir -p "$dir/players2" && { [ -f "$f" ] || : > "$f"; } || return 0
      if [ "${s_client:-}" = iw7mod ]; then
        # IW7-Mod knows these two dvars' names and saves them by name (its
        # profile after its first start, 2026-11-21: seta r_mode "2560x1440",
        # seta r_refreshRate "160.00 Hz"); the hashed lines (from the game's
        # own profile, copied the first time) go
        [ -n "$w" ] && [ -n "$h" ] && steam_iw7_seta "$f" r_mode "${w}x$h" 1984923617
        [ -n "$hz" ] && steam_iw7_seta "$f" r_refreshRate "$hz.00 Hz" -1226230005
        return 0
      fi
      [ -n "$w" ] && [ -n "$h" ] && steam_setcl "$f" 1984923617 "${w}x$h"
      [ -n "$hz" ] && steam_setcl "$f" -1226230005 "$hz.00 Hz"
      return 0 ;;
    *) return 0 ;;
  esac
  mkdir -p "$marks"
  for f in "${files[@]}"; do
    [ -f "$f" ] || printf '' > "$f"
    if [ "$s_kind" = q3 ]; then steam_q3_config "$f" "$w" "$h" "$hz" "$marks"; continue; fi
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
    [ -n "$hz" ] && { steam_cfg_set "$f" r_displayRefresh "$hz Hz"; steam_cfg_set "$f" com_maxfps "$(steam_maxfps "$hz")"; }
    # Modern Warfare 2 and 3: no vsync, as MW2's campaign runs at 160 FPS (with
    # vsync the multiplayer presented FIFO and sat at about 44 FPS); the
    # frame cap above keeps it at the refresh rate
    case "$s_id" in mw2|mw3) steam_cfg_set "$f" r_vsync 0 ;; esac
    # Black Ops, as Siliconium sets it for Plutonium: no shadow maps (they
    # froze it, BO1_NO_SHADOWS=0 keeps them) and no texture streaming
    # (STREAM=1 keeps it)
    if [ "$s_id" = bo1 ]; then
      # Plutonium's first-start defaults (once): full textures, 16x anisotropy,
      # 4x anti-aliasing (what Apple GPUs support), no blur or distortion
      if [ ! -f "$marks/.defaults-$(basename "$f")" ]; then
        steam_cfg_set "$f" com_first_time_pc 0; steam_cfg_set "$f" r_blur_allowed 0
        steam_cfg_set "$f" r_distortion 0; steam_cfg_set "$f" r_picmip_manual 0
        steam_cfg_set "$f" r_texFilterAnisoMax 16; steam_cfg_set "$f" r_aaSamples 4
        steam_cfg_set "$f" r_aspectRatio auto; steam_cfg_set "$f" r_dof_enable 1
        steam_cfg_set "$f" r_glow_allowed 1
        : > "$marks/.defaults-$(basename "$f")"
      fi
      # the mouse as with Plutonium: raw input, no filtering, no acceleration
      if [ "${RAW_INPUT:-1}" = 1 ]; then steam_cfg_set "$f" raw_input 1; steam_cfg_set "$f" m_filter 0; fi
      steam_cfg_set "$f" cl_mouseAccel 0
      # no vsync: with it the game was held at 120 FPS on a 160 Hz display
      # (FIFO); DXVK caps it at the refresh rate (d3d9.maxFrameRate)
      steam_cfg_set "$f" r_vsync 0
      [ "${BO1_NO_SHADOWS:-1}" != 0 ] && steam_cfg_set "$f" sm_enable 0
      [ "${STREAM:-0}" = 1 ] || steam_cfg_set "$f" r_stream 0
      # the shader warming pass (see BO1_WARM in launch.sh), campaign/zombies
      # (multiplayer too: Plutonium's multiplayer renderer queues it, DXVK_T5MP_WARM)
      [ "${BO1_WARM:-1}" != 0 ] && steam_cfg_set "$f" r_shaderWarming 1
    fi
    steam_cfg_set "$f" com_recommendedSet 1
  done
}
# Call of Duty (id Tech 3, OpenGL): its own settings names. The first time:
# fullscreen at the display's size (r_mode -1 = r_customwidth x
# r_customheight; its list stops at 4:3 sizes), full-size textures with
# trilinear filtering (the engine's defaults halve them), and in the campaign
# the 4:3 view widened to the display's shape (the game keeps the horizontal
# field of view and cuts the vertical one: 80 at 4:3 = 96 at 16:9; the
# multiplayer locks cg_fov). Every time: the display's refresh rate, the frame
# cap at it and no vsync (the cap paces the frames).
steam_q3_config() {   # <cfg> <width> <height> <hz> <marker dir>
  local f=$1 w=$2 h=$3 hz=$4 marks=$5 m fov cur
  m="$marks/.config-$(basename "$f")"
  if [ ! -f "$m" ]; then
    steam_cfg_set "$f" r_fullscreen 1
    if [ -n "$w" ] && [ -n "$h" ]; then
      steam_cfg_set "$f" r_mode -1; steam_cfg_set "$f" r_customwidth "$w"; steam_cfg_set "$f" r_customheight "$h"
      if [ "$(basename "$f")" = config.cfg ] || [ "$(basename "$f")" = uoconfig.cfg ]; then
        fov=$(awk -v w="$w" -v h="$h" 'BEGIN { pi = atan2(0, -1); t = sin(40 * pi / 180) / cos(40 * pi / 180) * (w / h) * 0.75
                                               printf "%d", 2 * atan2(t, 1) * 180 / pi + 0.5 }')
        [ "${fov:-0}" -gt 80 ] 2>/dev/null && steam_cfg_set "$f" cg_fov "$fov"
      fi
    fi
    steam_cfg_set "$f" r_picmip 0; steam_cfg_set "$f" r_texturebits 32
    steam_cfg_set "$f" r_texturemode GL_LINEAR_MIPMAP_LINEAR
    : > "$m"
  fi
  # a custom size larger than the display comes back to the display's
  if [ -n "$w" ] && [ -n "$h" ]; then
    cur=$(sed -n -E 's/^seta r_customwidth "([0-9]+)".*/\1/p' "$f" | tail -1)
    [ -n "$cur" ] && [ "$cur" -gt "$w" ] && steam_cfg_set "$f" r_customwidth "$w"
    cur=$(sed -n -E 's/^seta r_customheight "([0-9]+)".*/\1/p' "$f" | tail -1)
    [ -n "$cur" ] && [ "$cur" -gt "$h" ] && steam_cfg_set "$f" r_customheight "$h"
  fi
  if [ -n "$hz" ]; then steam_cfg_set "$f" r_displayRefresh "$hz"; steam_cfg_set "$f" com_maxfps "$hz"; fi
  steam_cfg_set "$f" r_swapInterval 0
  # the mouse as the game's defaults: no filtering, no acceleration
  steam_cfg_set "$f" m_filter 0; steam_cfg_set "$f" cl_mouseAccel 0
}

# The game's frame cap: the refresh rate, or none for Black Ops and World at
# War, as with Plutonium (their cap stopped at 120; DXVK caps them instead)
steam_maxfps() {   # <hz>
  case "$s_exe" in BlackOps*|CoDWaW*) echo 0 ;; *) echo "$1" ;; esac
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

# Infinite Warfare's profile: `setcl <hash> "value"` lines (LF), the value
# replaced or the line added
steam_setcl() {   # <cfg> <hash> <value>
  local tmp
  tmp=$(mktemp "$1.XXXXXX") || return 0
  awk -v k="$2" -v v="$3" '
    $1 == "setcl" && $2 == k { if (!done) { printf "setcl %s \"%s\"\n", k, v; done = 1 } next }
    { print }
    END { if (!done) printf "setcl %s \"%s\"\n", k, v }
  ' "$1" > "$tmp" && mv -f "$tmp" "$1" || rm -f "$tmp"
}

# IW7-Mod's profile (LF): `seta <name> "value"` replaced or added, the game's
# hashed line for the same dvar removed
steam_iw7_seta() {   # <cfg> <name> <value> <hash>
  local tmp
  tmp=$(mktemp "$1.XXXXXX") || return 0
  awk -v n="$2" -v v="$3" -v k="$4" '
    BEGIN { ln = tolower(n) }
    $1 == "setcl" && $2 == k { next }
    tolower($1) == "seta" && tolower($2) == ln { if (!done) { printf "seta %s \"%s\"\n", n, v; done = 1 } next }
    { print }
    END { if (!done) printf "seta %s \"%s\"\n", n, v }
  ' "$1" > "$tmp" && mv -f "$tmp" "$1" || rm -f "$tmp"
}

# Black Ops III's config.ini (Key = "value" // range, CRLF): the value
# replaced with the rest of the line kept, or the line added (as launch.sh's
# ini_put does for BOIII)
steam_ini_set() {   # <ini> <key> <value>
  local tmp
  tmp=$(mktemp "$1.XXXXXX") || return 0
  K="$2" V="$3" awk '
    BEGIN { k = ENVIRON["K"]; v = ENVIRON["V"] }
    !done && index($0, k " = \"") == 1 {
      rest = substr($0, length(k) + 5); q = index(rest, "\"")
      if (q) { print k " = \"" v "\"" substr(rest, q + 1); done = 1; next }
    }
    { print }
    END { if (!done) printf "%s = \"%s\"\r\n", k, v }
  ' "$1" > "$tmp" && mv -f "$tmp" "$1" || rm -f "$tmp"
}

# The controller's own keys (pad-mapper.exe keys): each pad button holds a
# numpad key that only the controller uses, bound here to the exact command,
# so it works whatever the player's keyboard bindings are. Written in every
# settings file of the game before each start (a first start too: the games
# load their default bindings and then this file).
# Call of Duty (q3, pad-mapper keys q3) has other commands: LT +speed (aims
# while held; the right mouse button toggles), X reloads (+reload) and uses
# (F11, +activate), no frag/smoke buttons (grenades are a weapon slot: RB picks
# them, RT throws), lean on the d-pad's sides, its weapon slots on the rest.
steam_pad_binds() {   # <cfg>
  local f=$1 tmp table
  [ -f "$f" ] || return 0
  table="KP_INS|+speed_throw;KP_5|+gostand;KP_END|togglecrouch;KP_DOWNARROW|toggleprone;KP_PGDN|+usereload;KP_LEFTARROW|weapnext;KP_RIGHTARROW|+smoke;KP_HOME|+frag;KP_UPARROW|+breath_sprint;KP_PGUP|+melee;KP_DEL|+actionslot 1;KP_MINUS|+actionslot 2;KP_PLUS|+actionslot 3;KP_STAR|+actionslot 4"
  # Call of Duty 2: LT +speed (aim while held), LB smoke, RB frag, L3 hold
  # breath, R3 melee, d-pad up binoculars / down scores / sides lean
  [ "$s_id" = cod2 ] && table="KP_INS|+speed;KP_5|+gostand;KP_END|togglecrouch;KP_DOWNARROW|toggleprone;KP_PGDN|+reload;F11|+activate;KP_LEFTARROW|weapnext;KP_RIGHTARROW|+smoke;KP_HOME|+frag;KP_UPARROW|+holdbreath;KP_PGUP|+melee;KP_DEL|+binoculars;KP_MINUS|+scores;KP_PLUS|+leanleft;KP_STAR|+leanright"
  [ "$s_id" = cod1 ] && table="KP_INS|+speed;KP_5|+gostand;KP_END|togglecrouch;KP_DOWNARROW|toggleprone;KP_PGDN|+reload;F11|+activate;KP_LEFTARROW|weapnext;KP_RIGHTARROW|weaponslot pistol;KP_HOME|weaponslot grenade;KP_UPARROW|weapalt;KP_PGUP|+melee;KP_DEL|weaponslot primary;KP_MINUS|weaponslot primaryb;KP_PLUS|+leanleft;KP_STAR|+leanright"
  # United Offensive (its options menus, uo/localized_english_pakuo00.pk3):
  # Call of Duty's commands plus sprint (+sprint, L3 as in the later games);
  # its multiplayer also has binoculars (artillery) and smoke grenades: d-pad
  # up / down there (the campaign keeps its two primary weapons on them)
  if [ "$s_id" = uo ]; then
    table="KP_INS|+speed;KP_5|+gostand;KP_END|togglecrouch;KP_DOWNARROW|toggleprone;KP_PGDN|+reload;F11|+activate;KP_LEFTARROW|weapnext;KP_RIGHTARROW|weaponslot pistol;KP_HOME|weaponslot grenade;KP_UPARROW|+sprint;KP_PGUP|+melee;KP_PLUS|+leanleft;KP_STAR|+leanright"
    case "$f" in
      *_mp.cfg) table="$table;KP_DEL|weaponslot binocular;KP_MINUS|weaponslot smokegrenade" ;;
      *)        table="$table;KP_DEL|weaponslot primary;KP_MINUS|weaponslot primaryb" ;;
    esac
  fi
  tmp=$(mktemp "$f.XXXXXX") || return 0
  awk -v table="$table" '
    BEGIN {
      n = split(table, pairs, ";")
      for (i = 1; i <= n; i++) { split(pairs[i], kv, "|"); k[i] = kv[1]; c[i] = kv[2]; ours[toupper(kv[1])] = 1 }
    }
    tolower($1) == "bind" && (toupper($2) in ours) { next }
    { print }
    END { for (i = 1; i <= n; i++) printf "bind %s \"%s\"\r\n", k[i], c[i] }
  ' "$f" > "$tmp" && mv -f "$tmp" "$f" || rm -f "$tmp"
}
