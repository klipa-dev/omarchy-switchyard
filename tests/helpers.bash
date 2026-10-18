# shellcheck disable=SC2034  # used by the .bats files that load this helper
REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

# isolate_home sets up a throwaway HOME with the XDG dirs Switchyard reads
# and writes, so no test ever touches the real machine (TASKS.md rule 9).
isolate_home() {
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.config" "$HOME/.local/share/applications" "$HOME/.local/state"
  export XDG_CONFIG_HOME="$HOME/.config"
  export XDG_DATA_HOME="$HOME/.local/share"
  export XDG_STATE_HOME="$HOME/.local/state"
  export XDG_CURRENT_DESKTOP="Hyprland"
  unset BROWSER
}
