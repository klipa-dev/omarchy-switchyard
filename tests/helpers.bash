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

# fake_browser <desktop-id> [--mozilla] — writes an executable script to
# $HOME/fake-bin/<id> (printing MOZ_LOG on --help with --mozilla, a plain
# usage line otherwise) and a desktop entry
# $XDG_DATA_HOME/applications/<id> whose Exec points at it. A non-"--help"
# invocation appends its arguments to $HOME/fake-bin/<id>.args, so a test
# can check what it was launched with.
fake_browser() {
  local id=$1 mozilla=0
  [[ ${2:-} == "--mozilla" ]] && mozilla=1
  local bin_dir="$HOME/fake-bin"
  mkdir -p "$bin_dir" "$XDG_DATA_HOME/applications"
  local bin_path="$bin_dir/$id"

  local help_line='echo "usage"'
  ((mozilla)) && help_line='echo "MOZ_LOG=all:5"'
  # shellcheck disable=SC2016  # the single-quoted lines are the fake
  # browser's own source, meant to expand when IT runs, not now.
  {
    echo '#!/bin/bash'
    echo 'if [[ "${1:-}" == "--help" ]]; then'
    echo "  $help_line"
    echo '  exit 0'
    echo 'fi'
    printf 'echo "$@" >> %q\n' "$bin_path.args"
    echo 'exit 0'
  } >"$bin_path"
  chmod +x "$bin_path"

  cat >"$XDG_DATA_HOME/applications/$id" <<EOF
[Desktop Entry]
Type=Application
Name=$id
Exec=$bin_path %u
EOF
}
