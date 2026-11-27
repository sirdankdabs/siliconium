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
#           | iw7 (Infinite Warfare) | s2 (WWII)
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
    # Black Ops: 2 as Plutonium's (launch.sh, BO1_ASYNC_LEVEL; 2026-11-23: new
    # maps loaded 3x faster without the 0.4-1 s render-thread compiles)
    bo1:sp)   s_exe=BlackOps.exe      s_app=42700  s_api=d3d9     s_own=0 s_async=2 s_pad=native s_name="Black Ops" ;;
    bo1:mp)   s_exe=BlackOpsMP.exe    s_app=42710  s_api=d3d9     s_own=0 s_async=2 s_pad=native s_name="Black Ops Multiplayer" ;;
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
    # WWII: the campaign (s2_sp64_ship.exe) and the multiplayer executable
    # (s2_mp64_ship.exe, its own Steam app 476620, Nazi Zombies inside it);
    # its own setup (s2): nothing taken from Advanced Warfare until tested on it
    wwii:sp)  s_exe=s2_sp64_ship.exe  s_app=476600 s_api=d3d11x64 s_own=0 s_kind=s2 s_pad=native s_name="WWII" ;;
    wwii:mp)  s_exe=s2_mp64_ship.exe  s_app=476620 s_api=d3d11x64 s_own=0 s_kind=s2 s_pad=native s_name="WWII Multiplayer" ;;
    # Nazi Zombies: the multiplayer executable with +zombiesMode 1 (as Steam's
    # own Zombies launch option and the campaign's Nazi Zombies button ask)
    wwii:zm)  s_exe=s2_mp64_ship.exe  s_app=476620 s_api=d3d11x64 s_own=0 s_kind=s2 s_pad=native s_name="WWII Nazi Zombies" ;;
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
      s_argv+=(+set com_recommendedSet 1 +set r_fullscreen 1)
      if [ "$s_id" = bo1 ]; then
        if [ "${BO1_SKIP_INTRO:-0}" = 1 ]; then s_argv+=(+set com_introPlayed 1 +set com_startupIntroPlayed 1)
        else s_argv+=(+set com_introPlayed 0 +set com_startupIntroPlayed 0); fi
      elif [ "${SKIP_INTRO:-1}" != 0 ]; then
        s_argv+=(+set com_introPlayed 1 +set com_startupIntroPlayed 1)
      else
        s_argv+=(+set com_introPlayed 0 +set com_startupIntroPlayed 0)
      fi
      [ -n "$w" ] && [ -n "$h" ] && s_argv+=(+set r_mode "${w}x$h")
      # the frame-rate cap at the refresh rate (under mtld3d, let present.maxFps
      # pace at sub-ms precision instead of the engine's integer-ms com_maxfps)
      if [ -n "$hz" ]; then
        if [ "${mtld3d_active:-0}" = 1 ] && [ "${maxfps:-0}" != 0 ]; then
          s_argv+=(+set r_displayRefresh "$hz Hz" +set com_maxfps 0)
        else
          s_argv+=(+set r_displayRefresh "$hz Hz" +set com_maxfps "$(steam_maxfps "$hz")")
        fi
      fi
      case "$s_exe" in iw4sp.exe|iw4mp.exe|iw5sp.exe|iw5mp.exe)
        if [ "${SKIP_INTRO:-1}" != 0 ]; then s_argv+=(+set intro 0); else s_argv+=(+set intro 1); fi ;; esac ;;
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
      if on IW6_TUNE; then
        local off=0 g_picmip=0
        [ "$s_id" = ghosts ] && off=0_Off
        [ "${SIL_RAM_GB:-16}" -le 8 ] && g_picmip=1
        s_argv+=(+set cl_loadHBAODLL 0 +set cl_loadTXAADLL 0 +set r_apex_turbulence 0 +set r_ssao "$off"
                 +set r_subdiv 0 +set r_adaptiveSubdiv 0 +set r_subdivLimit 0)
        [ "$first" = 1 ] && s_argv+=(+set r_tessellation "$off" +set r_mbEnable 0 +set r_picmip_manual 1
                                     +set r_picmip "$g_picmip" +set r_picmip_bump "$g_picmip" +set r_picmip_spec "$g_picmip")
      fi ;;
    s2)
      # WWII: its multiplayer executable took the resolution from its
      # encrypted system_config_mp.cfg, not from the profile (it went back to
      # 1280x720, 2026-11-22); on the command line it holds. Every start: the
      # desktop's size. (Its frame-rate cap is not taken from the command line:
      # steam_config writes it into the profile)
      [ "$s_part" = zm ] && s_argv+=(+zombiesMode 1)
      [ -n "$w" ] && [ -n "$h" ] && s_argv+=(+set r_mode "${w}x$h") ;;
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
      # World at War reads its profiles from AppData (Activision\CoDWaW, made
      # by its first start), not from the game's folder: writing them there
      # changed nothing and left a players folder in the game's folder. Before
      # its first start (no AppData profile yet) its command line does it all.
      if [ "$s_id" = waw ]; then
        dir=$(ls -d "$WINEPREFIX"/drive_c/users/*/AppData/Local/Activision/CoDWaW 2>/dev/null | head -1)
        [ -n "$dir" ] && [ -f "$dir/players/profiles/active.txt" ] || return 0
      fi
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
        local m="$marks/.config-cod2-$p-$(basename "$f")" cur cod2_pairs=()
        if [ ! -f "$m" ]; then
          cod2_pairs+=(r_fullscreen=1 r_textureMode=trilinear r_aaSamples=4)
          [ -n "$w" ] && [ -n "$h" ] && cod2_pairs+=("r_mode=${w}x$h")
          : > "$m"
        fi
        # fullscreen every start, as the other Steam games (its profile loads
        # after the command line); STEAM_SCREEN=0 keeps a window
        [ "${STEAM_SCREEN:-1}" != 0 ] && cod2_pairs+=(r_fullscreen=1)
        if [ -n "$w" ] && [ -n "$h" ]; then
          cur=$(sed -n -E 's/^seta r_mode "([0-9]+)x([0-9]+)".*/\1 \2/p' "$f" | tail -1)
          if [ "${STEAM_SCREEN:-1}" != 0 ] && [ -n "$cur" ] && [ "$cur" != "$w $h" ]; then cod2_pairs+=("r_mode=${w}x$h"); fi
        fi
        [ -n "$hz" ] && cod2_pairs+=("r_displayRefresh=$hz Hz" "com_maxfps=$hz")
        cod2_pairs+=(r_swapInterval=0 m_filter=0 cl_mouseAccel=0)
        # Straight to the menu, as with Plutonium (SKIP_INTRO): the logo and
        # intro movies (cinematic IW_logo / cod_intro) froze the game at
        # random right after the menu loaded (console.log: nextmap cinematic)
        if [ "${SKIP_INTRO:-1}" != 0 ]; then cod2_pairs+=(com_introPlayed=1); else cod2_pairs+=(com_introPlayed=0); fi
        steam_cfg_batch "$f" "${cod2_pairs[@]}"
      done
      return 0 ;;
    ghosts)
      # Ghosts: what Siliconium's own Ghosts writes (launch.sh, t=iw6) in the
      # profile it reads before opening its swap chain: borderless at the
      # desktop's size and rate unless the player chose a window, and
      # (IW6_TUNE) no NVIDIA libraries, SSAO or tessellation (both page-faulted
      # the GPU under DXMT) or subdivision every start; motion blur, fur, vsync
      # and automatic texture sizing off the first time only. The multiplayer
      # (iw6mp64_ship.exe: same renderer and setting names) keeps its own in
      # players2/config_mp.cfg (its strings: players2, config_mp.cfg)
      case "$s_part" in sp) f="$dir/players2/config.cfg" ;; mp) f="$dir/players2/config_mp.cfg" ;; *) return 0 ;; esac
      mkdir -p "$dir/players2" "$marks" && { [ -f "$f" ] || : > "$f"; } || return 0
      local ghosts_pairs=()
      if ! grep -Eiq '^[[:space:]]*seta[[:space:]]+r_displayMode[[:space:]]+"windowed( \(no border\))?"' "$f"; then
        ghosts_pairs+=(com_recommendedSet=1 "r_displayMode=windowed (no border)" r_monitor=0)
        [ -n "$w" ] && [ -n "$h" ] && ghosts_pairs+=("r_mode=${w}x$h")
        [ -n "$hz" ] && ghosts_pairs+=("r_displayRefresh=$hz Hz")
      fi
      if on IW6_TUNE; then
        # SSAO and tessellation every start: both page-faulted the GPU on Steam's
        # Ghosts (2026-11-20: SSAO High after ~3.5 min, tessellation Near after
        # ~45 s; with both, Apple's shader compiler crashed), even when the
        # player turned them on in the game's options
        ghosts_pairs+=(cl_loadHBAODLL=0 cl_loadTXAADLL=0 r_apex_turbulence=0 r_ssao=0_Off r_tessellation=0_Off r_subdivLimit=0)
        if [ ! -f "$marks/.defaults-ghosts-$s_part" ]; then
          local g_picmip=0
          [ "${SIL_RAM_GB:-16}" -le 8 ] && g_picmip=1
          ghosts_pairs+=(r_vsync=0 r_mbEnable=0 r_mbEnableA=0 r_fur_shader=0 r_picmip_manual=1
                         "r_picmip=$g_picmip" "r_picmip_bump=$g_picmip" "r_picmip_spec=$g_picmip" r_picmip_water=0)
          : > "$marks/.defaults-ghosts-$s_part"
        fi
      fi
      steam_cfg_batch "$f" "${ghosts_pairs[@]}"
      return 0 ;;
    aw)
      # Advanced Warfare (Sledgehammer s1 engine): left alone it chose exclusive
      # fullscreen at 3840x2160/60 Hz over the held 1x mode. Every start: the
      # desktop's size and held rate; once: fullscreen, 16x anisotropy, VSync off,
      # Apple-tuned AO/SSS/motion-blur defaults (same Sledgehammer family verified
      # on WWII), and safe video-memory budget to avoid swap thrashing on 8-16 GB Macs.
      case "$s_part" in sp) f="$dir/players2/config.cfg" ;; mp) f="$dir/players2/config_mp.cfg" ;; *) return 0 ;; esac
      mkdir -p "$dir/players2" "$marks" && { [ -f "$f" ] || : > "$f"; } || return 0
      local aw_pairs=()
      [ -n "$w" ] && [ -n "$h" ] && aw_pairs+=("r_mode=${w}x$h")
      [ -n "$hz" ] && aw_pairs+=("r_refreshRate=$hz.00 Hz")
      if [ "${STEAM_SCREEN:-1}" != 0 ]; then   # fullscreen every start (as the other games)
        aw_pairs+=(r_fullscreen=1 r_fullscreenWindow=0)
      fi
      if [ ! -f "$marks/.defaults-aw-$s_part" ]; then
        local aw_vmem=0.85
        [ "${SIL_RAM_GB:-16}" -le 8 ] && aw_vmem=0.75
        aw_pairs+=(r_fullscreen=1 r_fullscreenWindow=0 r_texFilterAnisoMax=16
                   r_vsync=0 r_ssaoLimit=1 r_mdaoLimit=0 r_sssLimit=0 r_mbLimit=0
                   "r_videoMemoryScale=$aw_vmem")
        : > "$marks/.defaults-aw-$s_part"
      fi
      # WWII's two engine fixes (Sledgehammer's next engine, s2):
      # - campaign shader preload off by default (AW_PRELOAD=1 leaves it on)
      # - multiplayer frame cap in profile (AW_MP_MAXFPS=0 leaves it alone)
      if [ "$s_part" = sp ]; then
        if [ "${AW_PRELOAD:-0}" = 1 ]; then aw_pairs+=(r_preloadShaders=1); else aw_pairs+=(r_preloadShaders=0); fi
      elif [ "${AW_MP_MAXFPS:-1}" != 0 ] && [ -n "$hz" ]; then
        aw_pairs+=("com_maxfps=$hz")
      fi
      steam_cfg_batch "$f" "${aw_pairs[@]}"
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
      local bo3_w="${SIL_BO3_WIN_W:-$w}" bo3_h="${SIL_BO3_WIN_H:-$h}"
      if on BOIII_GRAPHICS && [ ! -f "$marks/.defaults-bo3" ] && [ -n "$w" ] && [ -n "$h" ]; then
        local bo3_vmem=0.95 bo3_tex=0 bo3_res=100
        [ "${SIL_RAM_GB:-16}" -le 8 ] && { bo3_vmem=0.75; bo3_tex=1; }
        if [ "${w:-0}" -ge 3200 ]; then bo3_res=70
        elif [ "${w:-0}" -ge 2000 ]; then bo3_res=80
        elif [ "${SIL_GPU_CORES:-16}" -le 10 ] && [ "${w:-0}" -ge 1900 ]; then bo3_res=85
        fi
        steam_ini_batch "$f" AutoDetectHasRun=1 RestrictGraphicsOptions=0 FullScreenMode=1 "WindowSize=${bo3_w}x${bo3_h}" \
          "RefreshRate=${hz:-60}" Vsync=0 BackbufferCount=3 MaxFrameLatency=2 "VideoMemory=$bo3_vmem" \
          "ResolutionPercent=$bo3_res" MeshQuality=0 "TextureQuality=$bo3_tex" TextureFilter=2 \
          DisableDynamicLightShadows=0 DisableDynamicSunShadows=0 SpotShadowTextureSize=2048 \
          ShadowFiltering=1 VolumetricLightingEnabled=0 OITLayers=8 "SSAOTechnique=GTAO Medium Quality" \
          "AATechnique=Filmic SMAA T2x" SubsurfaceScattering=0 MotionBlur=Off
        : > "$marks/.defaults-bo3"
      fi
      if on BOIII_SCREEN && [ -n "$w" ] && [ -n "$h" ]; then
        local bo3_pairs=(FullScreenMode=1 "WindowSize=${bo3_w}x${bo3_h}" "MaxFPS=${maxfps:-${hz:-0}}")
        [ -n "$hz" ] && bo3_pairs+=("RefreshRate=$hz")
        steam_ini_batch "$f" "${bo3_pairs[@]}"
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
    wwii)
      # WWII: the campaign's profile is players2/user_config.cfg (made on its
      # first start, 2026-11-22: seta r_mode "1280x720", seta r_refreshRate
      # "60.00 Hz", r_fullscreen 1: exclusive fullscreen at that mode; LF line
      # ends; system_config.cfg next to it is not plain text). Every start:
      # the desktop's size and the rate of the 1x mode launch.sh holds.
      # Multiplayer / Zombies (s2_mp64_ship.exe): user_config_mp.cfg (made on its
      # first start, 2026-11-22: r_mode "1280x720", our r_refreshRate kept,
      # com_maxfps "85"); it takes r_mode from its encrypted system_config_mp.cfg
      # instead, so steam_args puts that on the command line.
      case "$s_part" in sp) f="$dir/players2/user_config.cfg" ;; mp|zm) f="$dir/players2/user_config_mp.cfg" ;; *) return 0 ;; esac
      mkdir -p "$dir/players2" "$marks" && { [ -f "$f" ] || : > "$f"; } || return 0
      local ww2_pairs=()
      [ -n "$w" ] && [ -n "$h" ] && ww2_pairs+=("r_mode=${w}x$h")
      [ -n "$hz" ] && ww2_pairs+=("r_refreshRate=$hz.00 Hz")
      # Fullscreen every start: the multiplayer profile had r_fullscreen "0".
      # WW2_SCREEN=0 keeps a window the player chose in the game's options.
      if [ "${WW2_SCREEN:-${STEAM_SCREEN:-1}}" != 0 ]; then
        ww2_pairs+=(r_fullscreen=1 r_fullscreenWindow=0)
      fi
      # First-start Apple Silicon defaults (live-verified +18% FPS, -62.5% p99
      # frame spikes, -280 MB RAM on WWII): VSync off so DXMT preferredMaxFrameRate
      # paces cleanly, cached sun shadows, lean AO/SSR/SSS/motion-blur passes,
      # and anti-swap video-memory scaling on 8 GB Macs.
      if [ ! -f "$marks/.defaults-wwii-$s_part" ]; then
        ww2_pairs+=(r_vsync=0 r_ssaoLimit=1 r_mdaoLimit=0 r_sssLimit=0 r_ssrEnabled=0
                    r_mbLimit=0 sm_cacheSunShadow=Enabled sm_tileResolution=Medium)
        [ "${SIL_RAM_GB:-16}" -le 8 ] && ww2_pairs+=(r_videoMemoryScale=0.75 r_picmip=1)
        : > "$marks/.defaults-wwii-$s_part"
      fi
      # Disable Logitech LED SDK polling under Wine every start.
      ww2_pairs+=(logitech_led=0)
      # Multiplayer/Zombies frame cap in profile (its own default is 85).
      if [ "$s_part" != sp ] && [ -n "$hz" ]; then ww2_pairs+=("com_maxfps=$hz"); fi
      # Campaign shader preload off by default (WW2_PRELOAD=1 leaves it on).
      if [ "$s_part" = sp ]; then
        if [ "${WW2_PRELOAD:-0}" = 1 ]; then ww2_pairs+=(r_preloadShaders=1); else ww2_pairs+=(r_preloadShaders=0); fi
      fi
      steam_cfg_batch "$f" "${ww2_pairs[@]}"
      sed -i '' $'s/\r$//' "$f"
      return 0 ;;
    *) return 0 ;;
  esac
  mkdir -p "$marks"
  for f in "${files[@]}"; do
    [ -f "$f" ] || printf '' > "$f"
    if [ "$s_kind" = q3 ]; then steam_q3_config "$f" "$w" "$h" "$hz" "$marks"; continue; fi
    local m="$marks/.config-$(basename "$f")" iw_pairs=()
    if [ ! -f "$m" ]; then
      iw_pairs+=(com_recommendedSet=1 r_fullscreen=1)
      [ -n "$w" ] && [ -n "$h" ] && iw_pairs+=("r_mode=${w}x$h")
      : > "$m"
    fi
    if [ "$s_id" = bo1 ]; then
      if [ "${BO1_SKIP_INTRO:-0}" = 1 ]; then
        iw_pairs+=(com_introPlayed=1 com_startupIntroPlayed=1)
      else
        iw_pairs+=(com_introPlayed=0 com_startupIntroPlayed=0)
      fi
    elif [ "${SKIP_INTRO:-1}" != 0 ]; then
      iw_pairs+=(com_introPlayed=1)
    else
      iw_pairs+=(com_introPlayed=0)
    fi
    # Fullscreen every start, also in the profile (Modern Warfare 2 ignored
    # "+set" on the command line; WWII's profile had turned windowed by itself).
    # STEAM_SCREEN=0 keeps a window the player chose in the game's options.
    [ "${STEAM_SCREEN:-1}" != 0 ] && iw_pairs+=(r_fullscreen=1)
    if [ -n "$w" ] && [ -n "$h" ]; then
      local cur
      cur=$(sed -n -E 's/^seta r_mode "([0-9]+)x([0-9]+)".*/\1 \2/p' "$f" | tail -1)
      # the desktop's own resolution, every start (the player's choice,
      # 2026-11-24: the games follow the Mac's resolution; another one made
      # Wine switch the display's mode)
      if [ "${STEAM_SCREEN:-1}" != 0 ] && [ -n "$cur" ] && [ "$cur" != "$w $h" ]; then iw_pairs+=("r_mode=${w}x$h"); fi
    fi
    # the frame-rate cap at the refresh rate (MW2's 64-bit update defaults to 60;
    # under mtld3d let present.maxFps pace at sub-ms precision cleanly)
    if [ -n "$hz" ]; then
      iw_pairs+=("r_displayRefresh=$hz Hz")
      if [ "${mtld3d_active:-0}" = 1 ] && [ "${maxfps:-0}" != 0 ]; then
        iw_pairs+=(com_maxfps=0)
      else
        iw_pairs+=("com_maxfps=$(steam_maxfps "$hz")")
      fi
    fi
    # Modern Warfare 2 and 3 (and CoD4/WaW under mtld3d): no vsync, let the
    # frame cap / mtld3d present.maxFps pace frames cleanly without FIFO stalls.
    case "$s_id" in
      mw2|mw3) iw_pairs+=(r_vsync=0) ;;
      cod4|waw) [ "${mtld3d_active:-0}" = 1 ] && [ "${maxfps:-0}" != 0 ] && iw_pairs+=(r_vsync=0) ;;
    esac
    if [ "$s_id" = waw ] && [ "${mtld3d_active:-0}" = 1 ]; then
      iw_pairs+=(r_multiGpu=1)
      if [ "${WAW_WARM:-1}" != 0 ]; then iw_pairs+=(r_shaderWarming=1); else iw_pairs+=(r_shaderWarming=0); fi
    fi
    # CoD4, MW2 and MW3: preload map shaders on the loading screen under mtld3d
    # (IW_PRELOAD=0 disables) so first-visit map entry avoids shader-compile hitches.
    # Also disable CPU/GPU sync stalls on CoD4/MW2 under mtld3d (eliminates the
    # periodic 8-frame sawtooth blip on MW2: 147-151 -> 160.0 FPS flat).
    # Under DXVK, MW3 keeps IW5_PRELOAD.
    if [ "${mtld3d_active:-0}" = 1 ]; then
      case "$s_id" in
        cod4)
          iw_pairs+=(r_multiGpu=1 in_gpuSync=0 r_gpuSync=off)
          if [ "${IW_PRELOAD:-1}" != 0 ]; then iw_pairs+=(r_preloadShaders=1); else iw_pairs+=(r_preloadShaders=0); fi ;;
        mw2)
          iw_pairs+=(r_multiGpu=1 in_gpuSync=0 r_gpuSync2=0)
          if [ "${IW_PRELOAD:-1}" != 0 ]; then iw_pairs+=(r_preloadShaders=1); else iw_pairs+=(r_preloadShaders=0); fi ;;
        mw3)
          if [ "${IW_PRELOAD:-1}" != 0 ]; then iw_pairs+=(r_preloadShaders=1); else iw_pairs+=(r_preloadShaders=0); fi ;;
      esac
    elif [ "$s_id" = mw3 ]; then
      if on IW5_PRELOAD; then iw_pairs+=(r_preloadShaders=1); else iw_pairs+=(r_preloadShaders=0); fi
    fi
    # Black Ops, as Siliconium sets it for Plutonium: no shadow maps (they
    # froze it, BO1_NO_SHADOWS=0 keeps them) and no texture streaming
    # (STREAM=1 keeps it)
    if [ "$s_id" = bo1 ]; then
      # Plutonium's first-start defaults (once): full textures, 16x anisotropy,
      # 4x anti-aliasing (what Apple GPUs support), no blur or distortion
      if [ ! -f "$marks/.defaults-$(basename "$f")" ]; then
        iw_pairs+=(com_first_time_pc=0 r_blur_allowed=0 r_distortion=0
          r_picmip_manual=0 r_texFilterAnisoMax=16 r_aaSamples=4 r_aspectRatio=auto
          r_dof_enable=1 r_glow_allowed=1)
        : > "$marks/.defaults-$(basename "$f")"
      fi
      iw_pairs+=(cl_mouseAccel=0 r_vsync=0)
      if [ "${RAW_INPUT:-1}" = 1 ]; then iw_pairs+=(raw_input=1 m_filter=0); fi
      [ "${BO1_NO_SHADOWS:-1}" != 0 ] && iw_pairs+=(sm_enable=0)
      [ "${STREAM:-0}" = 1 ] || iw_pairs+=(r_stream=0)
      if [ "${mtld3d_active:-0}" = 1 ]; then
        iw_pairs+=(r_shaderWarming=0)
      elif [ "${BO1_WARM:-1}" != 0 ]; then
        iw_pairs+=(r_shaderWarming=1)
      fi
    fi
    iw_pairs+=(com_recommendedSet=1)
    steam_cfg_batch "$f" "${iw_pairs[@]}"
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
  local f=$1 w=$2 h=$3 hz=$4 marks=$5 m fov cur q3_pairs=()
  m="$marks/.config-$(basename "$f")"
  if [ ! -f "$m" ]; then
    q3_pairs+=(r_fullscreen=1 com_hunkmegs=256 r_picmip=0 r_texturebits=32 r_texturemode=GL_LINEAR_MIPMAP_LINEAR)
    if [ -n "$w" ] && [ -n "$h" ]; then
      q3_pairs+=(r_mode=-1 "r_customwidth=$w" "r_customheight=$h")
      if [ "$(basename "$f")" = config.cfg ] || [ "$(basename "$f")" = uoconfig.cfg ]; then
        fov=$(awk -v w="$w" -v h="$h" 'BEGIN { pi = atan2(0, -1); t = sin(40 * pi / 180) / cos(40 * pi / 180) * (w / h) * 0.75
                                               printf "%d", 2 * atan2(t, 1) * 180 / pi + 0.5 }')
        [ "${fov:-0}" -gt 80 ] 2>/dev/null && q3_pairs+=("cg_fov=$fov")
      fi
    fi
    : > "$m"
  fi
  # a custom size larger than the display comes back to the display's
  if [ -n "$w" ] && [ -n "$h" ]; then
    cur=$(sed -n -E 's/^seta r_customwidth "([0-9]+)".*/\1/p' "$f" | tail -1)
    [ -n "$cur" ] && [ "$cur" -gt "$w" ] && q3_pairs+=("r_customwidth=$w")
    cur=$(sed -n -E 's/^seta r_customheight "([0-9]+)".*/\1/p' "$f" | tail -1)
    [ -n "$cur" ] && [ "$cur" -gt "$h" ] && q3_pairs+=("r_customheight=$h")
  fi
  [ -n "$hz" ] && q3_pairs+=("r_displayRefresh=$hz" "com_maxfps=$hz")
  # no vsync (frame cap paces cleanly) and raw mouse defaults
  q3_pairs+=(r_swapInterval=0 m_filter=0 cl_mouseAccel=0)
  steam_cfg_batch "$f" "${q3_pairs[@]}"
}

# The game's frame cap: the refresh rate, or none for Black Ops and World at
# War, as with Plutonium (their cap stopped at 120; DXVK caps them instead)
steam_maxfps() {   # <hz>
  case "$s_exe" in BlackOps*|CoDWaW*) echo 0 ;; *) echo "$1" ;; esac
}
steam_cfg_batch() {   # <cfg> key=value ...: single-pass awk replacement
  local f=$1 tmp
  shift
  [ $# -gt 0 ] || return 0
  tmp=$(mktemp "$f.XXXXXX") || return 0
  if awk -v n="$#" '
    BEGIN {
      for (i = 1; i <= n; i++) {
        kv = ARGV[i]; ARGV[i] = ""
        p = index(kv, "=")
        k = substr(kv, 1, p - 1); v = substr(kv, p + 1)
        lk = tolower(k); order[i] = lk; orig[lk] = k; want[lk] = v
      }
    }
    tolower($1) == "seta" && (tolower($2) in want) {
      lk = tolower($2)
      if (!(lk in seen)) { printf "seta %s \"%s\"\r\n", orig[lk], want[lk]; seen[lk] = 1 }
      next
    }
    { print }
    END {
      for (i = 1; i <= n; i++) {
        lk = order[i]
        if (!(lk in seen)) { printf "seta %s \"%s\"\r\n", orig[lk], want[lk]; seen[lk] = 1 }
      }
    }
  ' "$@" "$f" > "$tmp"; then
    cmp -s "$tmp" "$f" && rm -f "$tmp" || mv -f "$tmp" "$f"
  else
    rm -f "$tmp"
  fi
}

steam_cfg_set() {   # <cfg> <name> <value>: the name in any case, kept once
  steam_cfg_batch "$1" "$2=$3"
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
steam_ini_batch() {   # <ini> key=value ...: single-pass awk replacement
  local f=$1 tmp
  shift
  [ $# -gt 0 ] || return 0
  tmp=$(mktemp "$f.XXXXXX") || return 0
  if awk -v n="$#" '
    BEGIN {
      for (i = 1; i <= n; i++) {
        kv = ARGV[i]; ARGV[i] = ""
        p = index(kv, "=")
        k = substr(kv, 1, p - 1); v = substr(kv, p + 1)
        order[i] = k; want[k] = v
      }
    }
    {
      eq = index($0, " = \"")
      if (eq > 1) {
        k = substr($0, 1, eq - 1)
        if (k in want) {
          if (!(k in seen)) {
            rest = substr($0, eq + 4); q = index(rest, "\"")
            tail = q ? substr(rest, q + 1) : ""
            print k " = \"" want[k] "\"" tail
            seen[k] = 1
          }
          next
        }
      }
      print
    }
    END {
      for (i = 1; i <= n; i++) {
        k = order[i]
        if (!(k in seen)) { printf "%s = \"%s\"\r\n", k, want[k]; seen[k] = 1 }
      }
    }
  ' "$@" "$f" > "$tmp"; then
    cmp -s "$tmp" "$f" && rm -f "$tmp" || mv -f "$tmp" "$f"
  else
    rm -f "$tmp"
  fi
}

steam_ini_set() {   # <ini> <key> <value>
  steam_ini_batch "$1" "$2=$3"
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
