# Siliconium: community fixes for the Steam Library's games, sourced by
# launch.sh after steam-games.sh. The player picks one per game in the app
# (settings.conf STEAM_MOD_<GAME>=<mod>; none or missing: the game exactly as
# without this file). A fix is downloaded once from its author's official
# source into Siliconium's own folder (mods/<mod>/files) and checked against
# the SHA-256s pinned in payload/steam/mods/<mod>.files; it never ships in the
# app. Its files go into the game's folder only while the part it is for
# runs and only where the game has no file of that name: the game's own files
# are never changed, and what was put there goes again when the game quits
# (or, after a crash, at the next start of that game).
#
# steam_mod_def <mod> sets:
#   md_game   the Steam Library game          md_parts  the parts it is for
#   md_base   URL its files are downloaded from (+ the path in <mod>.files)
#   md_zip    or: the release archive (URL, SHA-256, folder in it)
#   md_exe    the executable started instead of the game's (it becomes
#             s_exe: every per-executable setting follows it)
#   md_pad    native: the fix plays the controller itself (no pad-mapper)
#   md_start  a launcher started instead of the game's executable, which
#             starts the game itself (the game's process keeps its name)
#   md_extra  files the fix or the game makes in the game's folder because of
#             it: removed with the fix (only those the folder did not have)
#   md_dlls   DLLs the game loads from its folder (native first, this
#             executable only)
#   md_conf   the fix's settings files among its files: the player's copy
#             (kept in mods/<mod>/ when the game quits) is used once there is one
#   md_args   arguments added to the game's
#   md_keep   1: launch.sh sets those DLLs' load order itself every start
#             (nothing to undo when another fix or none is chosen)
#   md_load   DLLs the game loads from its folder in place of Wine's own: that
#             one file native (its full path in this executable's load order),
#             so the same DLL loaded from the system folder stays Wine's
#   md_self   files the fix updates itself (its own updater, from its author):
#             taken out when the game quits whatever they hold, with what the
#             updater leaves beside them (names starting like theirs that the
#             folder did not have); an updated copy (whole, and the fix's by
#             the internal name md_selfid in its version information) is kept
#             in mods/<mod>/self/ for the next start
#   md_state  folders and files the fix keeps its state in (settings, logs,
#             what it downloads) in the game's folder: kept in
#             mods/<mod>/state/ between games
#   md_tools  1: also used when the game's Mod Tools start it (a map test,
#             bo3-modtools.sh, which sets m_tools=1)
#   md_appid  the Steam app the game must run as for the fix (its server
#             checks the game's Steam ticket): the Mod Tools then run as that
#             app, so their map tests do too (bo3-modtools.sh)
steam_mod_all="iw3spmod iwpad t4me t6spmod t7patch bo1pad cleanops shield"
steam_mod_def() {
  md_game= md_parts= md_base= md_zip=() md_exe= md_start= md_extra= md_pad= md_dlls= md_conf= md_keep= md_args=()
  md_load= md_self= md_selfid= md_state= md_tools= md_appid=
  case "$1" in
    # T4Me (T4M Enhanced, JBShady; no licence, so downloaded from its GitHub
    # release): World at War's campaign and Zombies with higher engine limits,
    # unlocked field of view, controller menu navigation and gamepad auto-aim,
    # a HUD-scale fix. Its d3d9.dll in the game's folder hands drawing to
    # dxvk.dll there: our own DXVK (the engine's, as World at War uses it
    # without the fix), not the stock DXVK it ships. Siliconium writes its
    # settings: our DXVK on, and its XAudio change off (World at War keeps the
    # game's own XAudio2 2.0, whose music Wine's would leave silent), and
    # dontaskagain.LAA, so it never offers to patch the game's executable
    # (Wine already gives it 4 GB: WINE_LARGE_ADDRESS_AWARE).
    t4me) md_game=waw md_parts=sp md_dlls=d3d9 md_keep=1
          md_zip=(https://github.com/JBShady/T4M-Enhanced/releases/download/r49/d3d9.7z
                  c635e1de283d36a71f91c1ebc7fc1ab74b8017b1544ea6df13a9145123f0ce50 .) ;;
    # IW-Pad v0.1.3 (GalvarinoDev, GPL-3.0): controller support with console aim
    # assist, button prompts and menu navigation for the campaigns of both
    # 64-bit (iw-pad.dll) and 32-bit (iw-pad32.dll) Modern Warfare 2 and 3 (it
    # checks the executable's build and does nothing on an unknown build).
    # iw-pad.exe starts the game with its arguments and loads the matching DLL
    # into it; its flag file makes the game write steam_appid.txt, so it is not
    # restarted through Steam; iw-pad.log is the DLL's own log. Its controller
    # settings (gpad_* and BUTTON_* binds) stay in the player's config.cfg: the
    # game without it never reads them.
    iwpad) md_game="mw2 mw3" md_parts=sp md_start=iw-pad.exe md_pad=native
           md_extra="noship_create_steam_appid.txt steam_appid.txt iw-pad.log"
           md_zip=(https://github.com/GalvarinoDev/IW-Pad/releases/download/v0.1.3/iw-pad.zip
                   85c420909d11e1ab0e1863eaa49b3e3f0b98e35376e1b34929fcd1431b28877e .) ;;
    # T6SP-Mod (Rattpak; closed source, no licence, so downloaded from its
    # GitHub release): Black Ops II's campaign with a developer console,
    # unlocked settings (field of view above 90), gamepad aim assist
    # (pc_aim_assist) and its own settings (spmod.cfg, kept in Siliconium's
    # folder between games). Started with Steam's
    # SteamAppId, T6SP-Mod.exe runs the game in its own process (its window
    # is the game's): it is the executable, so every per-executable setting
    # (x87, display capture) follows it.
    t6spmod) md_game=bo2 md_parts=sp md_exe=T6SP-Mod.exe
             md_base=https://github.com/Rattpak/T6SP-Mod-Release/releases/download/v1.0.0-Beta/ ;;
    # T7Patch (Scroptss's maintained fork of shiversoftdev's; no licence, so
    # downloaded from its GitHub release): Black Ops III's network security
    # fixes (remote code execution and crashes in multiplayer, Zombies and
    # co-op lobbies), friends-only lobbies, campaign fixes. Its loader is a
    # dsound.dll in the game's folder; its settings file (t7patch.conf, its
    # name in the game) is kept in Siliconium's folder between games.
    # NOT OFFERED by the app (session 10, v3.09 under Wine): Black Ops III
    # crashed with +devmap (NULL read in BlackOps3.exe) and hung loading a
    # map from the menu; kept here so a previous choice is still cleaned up.
    t7patch) md_game=bo3 md_parts=sp md_dlls=dsound
             md_zip=(https://github.com/Scroptss/T7Patch/releases/download/v3.09/Linux.Steamdeck.and.Manual.Windows.Install.v3.09.zip
                     2ba9a3ad6e491f991561dae411522cfdb20111a639317669a5810675982409cf
                     Linux.Steamdeck.and.Manual.Windows.Install.v3.09/linux) ;;
    # Clean Ops (nxghtwolf; closed source, no licence, so downloaded from its
    # author: the d3d11.dll cleanops.dev/download/ serves, from its GitHub at
    # the commit that published that build): Black Ops III's community patch
    # for Multiplayer (exploit and crash protection, its cheater blacklist,
    # its own lobby tools and server browser, an in-game menu). Its d3d11.dll
    # in the game's folder hands drawing on to the system's Direct3D 11: that
    # file alone loads native (md_load), so the Direct3D 11 it loads from the
    # system folder stays the engine's DXMT, as without it (a plain
    # d3d11=native,builtin chained to Steam's prefix's system32 d3d11.dll,
    # Advanced Warfare's DXMT; tested 2026-11-23). It updates itself from its
    # GitHub at the game's start (an older build may be refused online): its
    # newest copy is kept for the next start (md_self). Its folder (cleanops/:
    # settings, logs, the files it downloads the first time) and its menu's
    # window positions (imgui.ini, Dear ImGui's file, written into the game's
    # folder: seen 2026-11-23) are kept in Siliconium's folder between games.
    # A map test from the Mod Tools uses it too (md_tools), as Black Ops III
    # (md_appid): its server refused the Mod Tools' Steam ticket (app 455130,
    # which a map test inherits from the launcher) and it closed the game
    # ("Exiting: Could not establish a secure connection", 2026-11-23).
    cleanops) md_game=bo3 md_parts=sp md_load=d3d11 md_self=d3d11.dll md_selfid=cleanopsT7 md_tools=1
              md_state="cleanops imgui.ini" md_appid=311210
              md_base=https://raw.githubusercontent.com/notnightwolf/cleanopsT7/a6e4a42778e95559301296347328255faccfb132/ ;;
    # IW3SP-MOD (JerryALT, GPL-3.0; gitea.com/JerryALT/iw3sp_mod): Call of
    # Duty 4's campaign with its own controller support (console aim assist),
    # no frame cap, raw mouse. Its executable (iw3sp_mod.exe + game.dll) has
    # the game's code, so it is downloaded from the author's update server.
    # Its updater stays off (the checked files stay as they are); its
    # controller support is turned on the first time (steam_mod_args). Its
    # language choice (iw3sp_data/settings.json) is kept in Siliconium's
    # folder; __iw3sp_mod is the game's "did not quit properly" marker.
    # (+devmap on the command line left it on the loading screen: the app
    # never passes one.)
    iw3spmod) md_game=cod4 md_parts=sp md_base=https://jerryalt.codeberg.page/ md_exe=iw3sp_mod.exe md_pad=native
              md_extra=__iw3sp_mod md_args=(+set iw3sp_auto_update 0) ;;
    # BO1 Gamepad Plus (Castlesea, MIT; github.com/Castlesea/BO1-Gamepad-Plus):
    # Black Ops' campaign and Zombies (BlackOps.exe; it checks the game's build
    # and leaves its tweaks off on another). Its xinput1_3.dll in the game's
    # folder passes the controller on to Wine's XInput and adds radial stick
    # deadzones, the D-pad as arrow keys in menus, and aim dvars without the
    # console turn acceleration; its settings file (bo1pad.ini) is the
    # player's, kept between games; bo1pad.log is its log. Its borderless
    # launcher (an administrator .exe) is not used: Siliconium sets the
    # display itself.
    # NOT OFFERED by the app (session 11, v1.0 under Wine): it found no
    # controller (Wine's XInput loaded from system32 as native), its thread
    # crashed with the x87 sidecar (unexpected trap at a plain instruction)
    # and without the sidecar Zombies stayed on "Connecting..."; kept here so
    # a previous choice is still cleaned up.
    bo1pad) md_game=bo1 md_parts=sp md_dlls=xinput1_3 md_conf=bo1pad.ini md_extra=bo1pad.log
            md_zip=(https://github.com/Castlesea/BO1-Gamepad-Plus/releases/download/v1.0/BO1-Gamepad-Plus-v1.0.zip
                    4d50d41953e176f40ce303f8ab1d45e960d580c298cd69498d7f0152e5be0750 .) ;;
    # Shield (project-bo4, GPL-3.0; github.com/project-bo4/shield-development;
    # its "Build R2" for the game's June 2026 build from Scroptss' fork, the
    # offsets update sent to project-bo4 as PR #76: project-bo4's own R1 closes
    # the current game): Battle.net's Black Ops 4 without
    # its online services, from its XInput9_1_0.dll proxy in the game's folder
    # (native, BlackOps4.exe only): a built-in Demonware server emulator
    # (offline play), an in-game console, GSC and Lua mods. Its instructions
    # start the game as BlackOps4.exe, not through Battle.net: so does
    # tools/battlenet-games.sh with it. It needs the publisher files that
    # Battle.net's first start of the game downloads (the folder's LPC).
    # Its own settings, log and mods/plugins folders (made in the game's folder
    # at its first start, 2026-11-23) are kept in Siliconium's folder between
    # games; the offline profile it plays with is the game's own
    # (players/bnet-<id>), left in place.
    shield) md_game=bo4 md_parts=all md_dlls=xinput9_1_0 md_state="project-bo4 project-bo4.json project-bo4.log"
            md_base=https://github.com/Scroptss/shield-development/releases/download/XInput9_1_0.dll/ ;;
    *) return 1 ;;
  esac
}

m_mod=none m_error= m_start=
m_store="$home/mods"
steam_mod_for() { case " $md_game " in *" $1 "*) return 0 ;; esac; return 1; }
if [ "${s_client:-}" = own ]; then m_record="$home/cache/own-${s_id:-x}/mod-installed.list"
else m_record="$home/cache/steam-${s_id:-x}/mod-installed.list"; fi

# The Windows path Wine gives a Mac folder in Steam's prefix (Wine's own rule:
# the drive whose folder is the deepest one holding it, the first letter on a
# tie; the rest with backslashes), as a game started from there sees its folder
steam_mod_dospath() {   # <folder>
  local dir l t best= bl= rest
  dir=$(cd -P -- "$1" 2> /dev/null && pwd -P) || return 1
  for l in a b c d e f g h i j k l m n o p q r s t u v w x y z; do
    t=$(cd -P -- "$WINEPREFIX/dosdevices/$l:" 2> /dev/null && pwd -P) || continue
    case "$dir/" in "${t%/}/"*) [ ${#t} -gt ${#best} ] && best=$t bl=$l ;; esac
  done
  [ -n "$bl" ] || return 1
  rest=${dir#"${best%/}"}
  printf '%s:%s' "$(printf '%s' "$bl" | tr '[:lower:]' '[:upper:]')" "${rest//\//\\}"
}

# A copy of a file a fix updated itself (md_self): kept only when it is that
# fix's and whole (a Windows program as long as its sections say, whose
# version information has the fix's internal name, md_selfid), not a
# half-written one. Shell tools only (python3 may be Xcode's install prompt)
steam_mod_self_ok() {   # <copy> <the fix's internal name>
  local f=$1 o n s i end max=0
  [ -f "$f" ] && [ -n "$2" ] && [ "$(head -c 2 "$f" 2> /dev/null)" = MZ ] || return 1
  o=$(steam_mod_le "$f" 4 60)
  [ -n "$o" ] && [ "$(dd if="$f" bs=1 skip="$o" count=4 2> /dev/null | od -An -t x1 | tr -d ' \n')" = 50450000 ] || return 1
  n=$(steam_mod_le "$f" 2 $((o + 6))) s=$((o + 24 + $(steam_mod_le "$f" 2 $((o + 20)))))
  for (( i = 0; i < ${n:-0}; i++ )); do
    end=$(( $(steam_mod_le "$f" 4 $((s + 40 * i + 20))) + $(steam_mod_le "$f" 4 $((s + 40 * i + 16))) ))
    [ "$end" -gt "$max" ] && max=$end
  done
  [ "$max" -gt 0 ] && [ "$(stat -f %z "$f")" -ge "$max" ] || return 1
  [ "$(LC_ALL=C tr -d '\000' < "$f" | LC_ALL=C grep -c -a -F "InternalName$2")" -gt 0 ]
}
steam_mod_le() { od -An -t "u$2" -j "$3" -N "$2" "$1" 2> /dev/null | tr -d ' \n'; }   # <file> <bytes> <offset>

# The fix chosen for this game and part (m_mod; none when there is none),
# downloaded and put into the game's folder. Returns 1 with m_error set.
# m_tools=1 (bo3-modtools.sh): only a fix that is also for a map test from the
# game's Mod Tools (md_tools); any other is left out there
steam_mod_prepare() {   # <game folder>
  local dir=$1 key want
  steam_mod_remove "$dir"   # what a crash left behind
  if [ "${s_client:-}" = own ]; then
    key="OWN_MOD_$(printf '%s' "$s_id" | tr '[:lower:]' '[:upper:]')"
    if [ -z "${!key+x}" ] && [ "$s_id" = bo2 ] && [ "$s_part" = sp ]; then
      want=t6spmod
    else
      want=${!key:-none}
    fi
  else
    key="STEAM_MOD_$(printf '%s' "$s_id" | tr '[:lower:]' '[:upper:]')"
    want=${!key:-none}
  fi
  m_mod=none
  [ "$want" = none ] && return 0
  steam_mod_def "$want" && steam_mod_for "$s_id" || return 0   # unknown here: the plain game
  case " $md_parts " in *" $s_part "*) ;; *) return 0 ;; esac
  [ -n "${m_tools:-}" ] && [ -z "$md_tools" ] && return 0
  m_mod=$want
  steam_mod_fetch "$m_mod" || return 1
  steam_mod_install "$dir" || return 1
  [ -n "$md_exe" ] && s_exe=$md_exe
  m_start=$md_start
  [ "$md_pad" = native ] && s_pad=native
  # a fix that starts the game its own way: the x87 sidecar's list names it
  # (one that only adds files leaves the game's start as it was: Black Ops
  # III, 64-bit, is not in that list)
  [ -n "$md_exe$md_start" ] && steam_x87_programs="$steam_x87_programs:$s_exe"
  return 0
}

# The fix's arguments and settings, after steam_args / steam_config
steam_mod_args() {   # <game folder>
  local m d dos=
  # the DLL overrides of this game's fixes: only the chosen one's stay (a
  # file's own load order by its full path in this folder, md_load)
  for m in $steam_mod_all; do
    [ "$m" = "$m_mod" ] && continue
    steam_mod_def "$m" && steam_mod_for "$s_id" && [ -z "$md_keep" ] || continue
    for d in $md_dlls; do reg delete "HKCU\\Software\\Wine\\AppDefaults\\$s_exe\\DllOverrides" /v "$d" /f; done
    for d in $md_load; do
      [ -n "$dos" ] || dos=$(steam_mod_dospath "$1") || continue
      reg delete "HKCU\\Software\\Wine\\AppDefaults\\$s_exe\\DllOverrides" /v "$dos\\$d" /f
    done
  done
  [ "$m_mod" = none ] && return 0
  steam_mod_def "$m_mod"
  for d in $md_dlls; do reg add "HKCU\\Software\\Wine\\AppDefaults\\$s_exe\\DllOverrides" /v "$d" /d native,builtin /f; done
  for d in $md_load; do
    [ -n "$dos" ] || dos=$(steam_mod_dospath "$1") || continue
    reg add "HKCU\\Software\\Wine\\AppDefaults\\$s_exe\\DllOverrides" /v "$dos\\$d" /d native,builtin /f
  done
  s_argv+=(${md_args[@]+"${md_args[@]}"})
  case "$m_mod" in
    t7patch)
      # its settings: the player's own (kept in Siliconium's folder), the first
      # time with the Steam account's name (T7Patch shows "Unknown Soldier"
      # otherwise), lobbies friends-only and no automatic mod downloads (its
      # defaults)
      local conf="$m_store/t7patch/t7patch.conf" name
      if [ ! -f "$conf" ]; then
        # the account marked most recent, else the last one (one account: no mark)
        name=$(awk -F'"' '/"PersonaName"/ { n = $4 } /"MostRecent"/ && $4 == "1" { print n; done = 1; exit }
                          END { if (!done) print n }' \
               "$WINEPREFIX/drive_c/Program Files (x86)/Steam/config/loginusers.vdf" 2>/dev/null | cut -c1-15)
        printf 'playername=%s\nisfriendsonly=1\nautoinstallmods=0\nnetworkpassword=\n' "${name:-Player}" > "$conf"
      fi
      if [ ! -e "$1/t7patch.conf" ]; then
        cp "$conf" "$1/t7patch.conf" && printf 'c %s\n' t7patch.conf >> "$m_record"
      fi ;;
    t6spmod)
      # its settings (console colours, field of view...): the player's own
      if [ ! -e "$1/spmod.cfg" ]; then
        [ -f "$m_store/t6spmod/spmod.cfg" ] && cp "$m_store/t6spmod/spmod.cfg" "$1/spmod.cfg"
        printf 'c %s\n' spmod.cfg >> "$m_record"
      fi ;;
    iw3spmod)
      # It reads its own settings file (players/profiles/<p>/iw3sp_mod_config.cfg,
      # a copy of config.cfg the first time): the display's rate and Apple-tuned
      # settings every start, as steam_config writes in config.cfg
      local p f iw3_pairs=()
      p=$(tr -d '\r\n' 2>/dev/null < "$1/players/profiles/active.txt")
      f="$1/players/profiles/$p/iw3sp_mod_config.cfg"
      if [ -n "$p" ] && [ -f "$f" ]; then
        [ "${STEAM_SCREEN:-1}" != 0 ] && iw3_pairs+=(r_fullscreen=1)
        [ "${STEAM_SCREEN:-1}" != 0 ] && [ -n "${dw:-}" ] && [ -n "${dh:-}" ] && iw3_pairs+=("r_mode=${dw}x${dh}")
        if [ -n "${hz:-}" ]; then
          iw3_pairs+=("r_displayRefresh=$hz Hz")
          if [ "${mtld3d_active:-0}" = 1 ] && [ "${maxfps:-0}" != 0 ]; then
            iw3_pairs+=(com_maxfps=0 r_vsync=0)
          else
            iw3_pairs+=("com_maxfps=$(steam_maxfps "$hz")")
          fi
        fi
        if [ "${mtld3d_active:-0}" = 1 ]; then
          iw3_pairs+=(r_multiGpu=1 in_gpuSync=0 r_gpuSync=off)
          [ "${IW_PRELOAD:-1}" != 0 ] && iw3_pairs+=(r_preloadShaders=1)
        fi
        [ ${#iw3_pairs[@]} -gt 0 ] && steam_cfg_batch "$f" "${iw3_pairs[@]}"
      fi
      # The controller, the first time (no button layout chosen yet): what its
      # menu does when the player turns the controller on (gamepadFirstExecIfEnabled:
      # the default stick and button layouts, then their bindings). Turned on
      # only by the dvar, the controller had no bindings and did not move the
      # player. Afterwards the player's own choice in its menu stays.
      if ! grep -Eq '^seta gpad_buttonConfig "[^"]+"' "$f" 2>/dev/null; then
        s_argv+=(+set gpad_enabled 1 +set gpad_sticksConfig thumbstick_default +set gpad_buttonConfig buttons_default
                 +exec thumbstick_default +exec buttons_default)
      fi
      # its language choice, kept between games
      local lang="$m_store/iw3spmod/settings.json"
      if [ ! -e "$1/iw3sp_data/settings.json" ]; then
        [ -f "$lang" ] && cp "$lang" "$1/iw3sp_data/settings.json"
        printf 'c %s\n' iw3sp_data/settings.json >> "$m_record"
      fi
      # DXVK's pipeline list is per executable: start from the game's own
      local c="$home/cache/${steam_cache_tag:-steam-$s_id}"
      [ -f "$c/iw3sp_mod.dxvk-cache" ] || { [ -f "$c/iw3sp.dxvk-cache" ] && cp "$c/iw3sp.dxvk-cache" "$c/iw3sp_mod.dxvk-cache"; }
      ;;
  esac
  return 0
}

# The fix's files in Siliconium's folder, each checked; missing or wrong ones
# downloaded from its official source
steam_mod_fetch() {   # <mod>
  local mod=$1 list="$kit/payload/steam/mods/$1.files" sum size path f tmp got idx=0 total
  [ -f "$list" ] || { m_error="Siliconium has no file list for $mod: reinstall Siliconium."; return 1; }
  if [ ${#md_zip[@]} -gt 0 ]; then steam_mod_fetch_zip "$mod" "$list"; return; fi
  total=$(grep -cvE '^[[:space:]]*(#|$)' "$list" 2>/dev/null || echo 0)
  while read -r sum size path; do
    case "$sum" in ''|\#*) continue ;; esac
    idx=$((idx + 1))
    f="$m_store/$mod/files/$path"
    [ -f "$f" ] && [ "$(shasum -a 256 "$f" | cut -d' ' -f1)" = "$sum" ] && continue
    printf '==> %s\n' "Downloading $mod ($idx/$total: ${path##*/})…"
    mkdir -p "$(dirname "$f")" || { m_error="Could not create $m_store/$mod."; return 1; }
    tmp="$f.download"
    if ! curl -fsSL --retry 2 -o "$tmp" "$md_base$path"; then
      rm -f "$tmp"; m_error="Could not download $path of $mod from $md_base: check your internet connection and press Play again."; return 1
    fi
    got=$(shasum -a 256 "$tmp" | cut -d' ' -f1)
    if [ "$got" != "$sum" ]; then
      rm -f "$tmp"
      m_error="$mod's author has changed $path since Siliconium checked it: choose None for now (Siliconium needs an update to use the new version)."
      return 1
    fi
    mv -f "$tmp" "$f"
  done < "$list"
  return 0
}

# A fix published as one archive: the archive (its SHA-256 checked) is
# downloaded only when a file is missing or wrong; the listed files are taken
# from it and each checked
steam_mod_fetch_zip() {   # <mod> <file list>
  local mod=$1 list=$2 sum size path f ok=1 tmp got
  while read -r sum size path; do
    case "$sum" in ''|\#*) continue ;; esac
    f="$m_store/$mod/files/$path"
    [ -f "$f" ] && [ "$(shasum -a 256 "$f" | cut -d' ' -f1)" = "$sum" ] || { ok=; break; }
  done < "$list"
  [ -n "$ok" ] && return 0
  printf '==> %s\n' "Downloading $mod…"
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/siliconium-mod.XXXXXX") || { m_error="Could not make a temporary folder."; return 1; }
  if [ -f "$kit/tools/dl-progress.sh" ]; then
    . "$kit/tools/dl-progress.sh"
    if ! sil_curl_progress "Downloading $mod" 0 "$tmp/a.zip" -fsSL --retry 2 "${md_zip[0]}"; then
      rm -rf "$tmp"; m_error="Could not download $mod from ${md_zip[0]%/*}: check your internet connection and press Play again."; return 1
    fi
  elif ! curl -fsSL --retry 2 -o "$tmp/a.zip" "${md_zip[0]}"; then
    rm -rf "$tmp"; m_error="Could not download $mod from ${md_zip[0]%/*}: check your internet connection and press Play again."; return 1
  fi
  got=$(shasum -a 256 "$tmp/a.zip" | cut -d' ' -f1)
  # bsdtar reads zip and 7z archives alike
  if [ "$got" != "${md_zip[1]}" ] || ! mkdir "$tmp/x" || ! /usr/bin/bsdtar -xf "$tmp/a.zip" -C "$tmp/x"; then
    rm -rf "$tmp"; m_error="$mod's download is not the one Siliconium checked: choose None for now (Siliconium needs an update)."; return 1
  fi
  while read -r sum size path; do
    case "$sum" in ''|\#*) continue ;; esac
    f="$m_store/$mod/files/$path"
    if [ "$(shasum -a 256 "$tmp/x/${md_zip[2]}/$path" 2>/dev/null | cut -d' ' -f1)" != "$sum" ]; then
      rm -rf "$tmp"; m_error="$mod's archive does not hold the checked $path: choose None for now."; return 1
    fi
    mkdir -p "$(dirname "$f")" && cp "$tmp/x/${md_zip[2]}/$path" "$f" || { rm -rf "$tmp"; m_error="Could not store $mod."; return 1; }
  done < "$list"
  rm -rf "$tmp"
  return 0
}

# Into the game's folder: only names the game does not have (or ours, the same
# bytes); each file and each folder made is written down for steam_mod_remove
steam_mod_install() {   # <game folder>
  local dir=$1 sum size path src dst sub d kind n
  mkdir -p "$(dirname "$m_record")"
  printf 'mod %s\n' "$m_mod" > "$m_record"
  # the names starting like a file the fix updates itself that the folder
  # has already: steam_mod_remove leaves them
  for path in $md_self; do
    [ -n "${path%.*}" ] || continue
    for n in "$dir/${path%.*}"*; do [ -e "$n" ] && printf 'k %s\n' "${n#"$dir/"}" >> "$m_record"; done
  done
  while read -r sum size path; do
    case "$sum" in ''|\#*) continue ;; esac
    src="$m_store/$m_mod/files/$path" dst="$dir/$path" kind=f
    # a settings file: the player's own copy once there is one
    case " $md_conf " in
      *" $path "*) kind=c; [ -f "$m_store/$m_mod/${path##*/}" ] && src="$m_store/$m_mod/${path##*/}" ;;
    esac
    # a file the fix updates itself: its newest copy once there is one
    case " $md_self " in
      *" $path "*) kind=u; steam_mod_self_ok "$m_store/$m_mod/self/$path" "$md_selfid" && src="$m_store/$m_mod/self/$path" ;;
    esac
    if [ -e "$dst" ] && ! cmp -s "$src" "$dst"; then
      steam_mod_remove "$dir"
      m_error="The game's folder already has a $path that is not this fix's: Siliconium leaves the game's files alone (choose None)."
      return 1
    fi
    # the folders it needs, outermost first
    sub=${path%/*} d=
    [ "$sub" = "$path" ] && sub=
    while [ -n "$sub" ]; do
      d="${d:+$d/}${sub%%/*}"
      [ -d "$dir/$d" ] || { mkdir "$dir/$d" && printf 'd %s\n' "$d" >> "$m_record"; } || return 1
      [ "$sub" = "${sub#*/}" ] && break
      sub=${sub#*/}
    done
    [ -e "$dst" ] || cp "$src" "$dst" || { steam_mod_remove "$dir"; m_error="Could not copy $path into the game's folder."; return 1; }
    printf '%s %s\n' "$kind" "$path" >> "$m_record"
  done < "$kit/payload/steam/mods/$m_mod.files"
  for path in $md_extra; do [ -e "$dir/$path" ] || printf 'x %s\n' "$path" >> "$m_record"; done
  # its state (folders, files): the player's, from Siliconium's folder (one
  # the game's folder has already is the player's own: used, and left there)
  for path in $md_state; do
    [ -n "$path" ] && [ "${path#*/}" = "$path" ] && [ ! -e "$dir/$path" ] || continue
    printf 's %s\n' "$path" >> "$m_record"
    [ -e "$m_store/$m_mod/state/$path" ] && mv "$m_store/$m_mod/state/$path" "$dir/$path"
  done
  case "$m_mod" in
    t4me)
      # its settings, our DXVK as its dxvk.dll (the engine's carries Wine's
      # builtin mark: a copy with the standard DOS-stub text, as for Black Ops
      # Multiplayer's renderer), and its "don't ask" flag; only names the
      # folder does not have
      local dxvk="$engine/lib/wine/i386-windows/d3d9.dll" n
      for n in d3d9.ini dxvk.dll dontaskagain.LAA; do
        if [ -e "$dir/$n" ]; then
          steam_mod_remove "$dir"
          m_error="The game's folder already has a $n that is not Siliconium's: Siliconium leaves the game's files alone (choose None)."
          return 1
        fi
      done
      [ -f "$dxvk" ] || { steam_mod_remove "$dir"; m_error="Siliconium's DXVK is missing: reinstall Siliconium."; return 1; }
      printf '[Fixes]\r\nUseFixedXAudio=0\r\n[Graphics]\r\nDXVK=1\r\n' > "$dir/d3d9.ini" && printf 'x d3d9.ini\n' >> "$m_record"
      cp "$dxvk" "$dir/dxvk.dll" && printf 'This program can' | dd of="$dir/dxvk.dll" bs=1 seek=64 conv=notrunc 2> /dev/null &&
        printf 'x dxvk.dll\n' >> "$m_record" || { steam_mod_remove "$dir"; m_error="Could not copy DXVK into the game's folder."; return 1; }
      : > "$dir/dontaskagain.LAA" && printf 'x dontaskagain.LAA\n' >> "$m_record" ;;
  esac
  return 0
}

# What steam_mod_install put into the game's folder goes: files still the
# fix's (same bytes as Siliconium's copy), then the folders it made, if empty
steam_mod_remove() {   # <game folder>
  local dir=$1 kind path mod= dirs=() keep=() selfs=() i n k x id
  [ -f "$m_record" ] || return 0
  while read -r kind path; do
    case "$kind" in
      mod) mod=$path ;;
      f) [ -n "$mod" ] && [ -f "$dir/$path" ] && cmp -s "$m_store/$mod/files/$path" "$dir/$path" && rm -f "$dir/$path" ;;
      # a settings file the fix may have changed: kept in Siliconium's folder
      c) [ -n "$mod" ] && [ -f "$dir/$path" ] && cp "$dir/$path" "$m_store/$mod/${path##*/}" && rm -f "$dir/$path" ;;
      d) dirs+=("$path") ;;
      x) rm -f "$dir/$path" ;;   # made because of the fix (the folder had none)
      # a file the fix updates itself: out, whatever it holds (the folder had
      # none); a copy its updater changed is kept for the next start
      u) if [ -n "$mod" ] && [ -f "$dir/$path" ]; then
           id=$(steam_mod_def "$mod" && printf '%s' "$md_selfid")
           if ! cmp -s "$m_store/$mod/files/$path" "$dir/$path" && steam_mod_self_ok "$dir/$path" "$id"; then
             mkdir -p "$(dirname "$m_store/$mod/self/$path")" && mv -f "$dir/$path" "$m_store/$mod/self/$path"
           fi
           rm -f "$dir/$path"
         fi
         [ -n "${path%.*}" ] && selfs+=("$path") ;;
      k) keep+=("$path") ;;
      # the fix's state (a folder or a file): kept in Siliconium's folder until
      # the next game (a name in the game's folder, never the folder itself)
      s) if [ -n "$mod" ] && [ -n "$path" ] && [ "${path#*/}" = "$path" ] && [ "$path" != . ] && [ "$path" != .. ] &&
            [ -e "$dir/$path" ]; then
           mkdir -p "$m_store/$mod/state" && rm -rf "$m_store/$mod/state/$path" &&
             mv "$dir/$path" "$m_store/$mod/state/$path"
         fi ;;
    esac
  done < "$m_record"
  # what an updater left beside those files (an old copy, a disabled one):
  # names the folder did not have
  for path in ${selfs[@]+"${selfs[@]}"}; do
    for n in "$dir/${path%.*}"*; do
      [ -f "$n" ] || continue
      k=
      for x in ${keep[@]+"${keep[@]}"}; do [ "$x" = "${n#"$dir/"}" ] && k=1; done
      [ -n "$k" ] || rm -f "$n"
    done
  done
  for (( i=${#dirs[@]}-1; i>=0; i-- )); do rmdir "$dir/${dirs[$i]}" 2>/dev/null; done
  rm -f "$m_record"
  return 0
}
