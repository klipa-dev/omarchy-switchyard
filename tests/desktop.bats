bats_require_minimum_version 1.5.0

load helpers

setup() {
  isolate_home
  source "$REPO_ROOT/lib/router.sh"
}

@test "with SWITCHYARD_APPLICATIONS_DIRS unset, prints the three default directories in order" {
  unset SWITCHYARD_APPLICATIONS_DIRS
  run switchyard_applications_dirs
  [ "$status" -eq 0 ]
  [ "$output" = "$XDG_DATA_HOME/applications
$HOME/.nix-profile/share/applications
/usr/share/applications" ]
}

@test "SWITCHYARD_APPLICATIONS_DIRS overrides the default with its colon-separated entries" {
  export SWITCHYARD_APPLICATIONS_DIRS="$BATS_TEST_TMPDIR/one:$BATS_TEST_TMPDIR/two"
  run switchyard_applications_dirs
  [ "$status" -eq 0 ]
  [ "$output" = "$BATS_TEST_TMPDIR/one
$BATS_TEST_TMPDIR/two" ]
}

@test "empty entries in SWITCHYARD_APPLICATIONS_DIRS are skipped" {
  export SWITCHYARD_APPLICATIONS_DIRS="$BATS_TEST_TMPDIR/one::$BATS_TEST_TMPDIR/two:"
  run switchyard_applications_dirs
  [ "$status" -eq 0 ]
  [ "$output" = "$BATS_TEST_TMPDIR/one
$BATS_TEST_TMPDIR/two" ]
}

@test "a desktop id present in two directories resolves from the first" {
  local dir1="$BATS_TEST_TMPDIR/one" dir2="$BATS_TEST_TMPDIR/two"
  mkdir -p "$dir1" "$dir2"
  : >"$dir1/chromium.desktop"
  : >"$dir2/chromium.desktop"
  export SWITCHYARD_APPLICATIONS_DIRS="$dir1:$dir2"

  run _switchyard_desktop_entry "chromium.desktop"
  [ "$status" -eq 0 ]
  [ "$output" = "$dir1/chromium.desktop" ]
}
