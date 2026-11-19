# Wine normally prefers raw HID for the DS4 and DualSense. Select their existing
# SDL mappings so Wine exposes their buttons and axes through XInput on USB/BT.
# Call only when the prefix can be restarted and before starting its game.
configure_ds4_xinput() {
  local marker="$WINEPREFIX/.sil-ds4-xinput" version=2 status staged
  # The original empty marker covered only DS4. Upgrade existing prefixes once.
  [ -f "$marker" ] && [ "$(cat "$marker" 2>/dev/null)" = "$version" ] && return 0

  if (
    local key pid result i
    # DS4 v1/v2/adapter, DualSense, DualSense Edge; the IDs cover both transports.
    local pids=(05c4 09cc 0ba0 0ce6 0df2) expected=()
    for pid in "${pids[@]}"; do
      key="HKLM\\System\\CurrentControlSet\\Services\\WineBus\\Devices\\054c/$pid"
      # Keep explicit overrides in imported or hand-configured prefixes.
      if result=$("$wine" reg query "$key" /v Hidraw 2>/dev/null); then
        # Some broken Wine invocations succeed with no output and no effect.
        # Do not treat that as a saved value or mark the migration complete.
        grep -Eiq '^[[:space:]]*Hidraw[[:space:]]+REG_[[:alnum:]_]+' <<< "$result" || exit 1
      else
        "$wine" reg add "$key" /v Hidraw /t REG_DWORD /d 0 /f >/dev/null 2>&1 || exit 1
        result=$("$wine" reg query "$key" /v Hidraw 2>/dev/null) || exit 1
        grep -Eiq '^[[:space:]]*Hidraw[[:space:]]+REG_DWORD[[:space:]]+0x0+[[:space:]]*$' <<< "$result" || exit 1
      fi
      expected+=("$result")
    done

    # Flush, restart, and read back: a successful reg.exe exit alone does not
    # prove that the settings survived into the next WineBus session.
    "$WINESERVER" -k 2>/dev/null || exit 1
    "$WINESERVER" -w 2>/dev/null || exit 1
    for i in "${!pids[@]}"; do
      key="HKLM\\System\\CurrentControlSet\\Services\\WineBus\\Devices\\054c/${pids[$i]}"
      result=$("$wine" reg query "$key" /v Hidraw 2>/dev/null) || exit 1
      [ "$result" = "${expected[$i]}" ] || exit 1
    done
  ); then status=0; else status=1; fi

  # Stop the verification session on success or failure. WineBus must start
  # fresh for the game, and an incomplete migration must be retried next time.
  "$WINESERVER" -k 2>/dev/null || return 1
  "$WINESERVER" -w 2>/dev/null || return 1
  [ "$status" = 0 ] || return 1
  staged=$(mktemp "$marker.XXXXXX") || return 1
  if ! printf '%s\n' "$version" > "$staged" || ! mv -f "$staged" "$marker"; then
    rm -f "$staged"
    return 1
  fi
}
