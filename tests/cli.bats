load helpers

CLI="$REPO_ROOT/bin/omarchy-switchyard"

setup() {
  isolate_home
}

# Captured once, before isolate_home has run for any test, so this is the
# real machine's mimeapps.list -- the one file this whole suite must never
# touch: tests never change the real machine's config, data, state or
# default browser.
setup_file() {
  local real_mimeapps="${XDG_CONFIG_HOME:-$HOME/.config}/mimeapps.list"
  echo "$real_mimeapps" >"$BATS_FILE_TMPDIR/real-mimeapps-path"
  if [[ -f "$real_mimeapps" ]]; then
    cp "$real_mimeapps" "$BATS_FILE_TMPDIR/real-mimeapps-before"
  fi
}

teardown_file() {
  local real_mimeapps
  real_mimeapps="$(cat "$BATS_FILE_TMPDIR/real-mimeapps-path")"
  if [[ -f "$BATS_FILE_TMPDIR/real-mimeapps-before" ]]; then
    diff "$BATS_FILE_TMPDIR/real-mimeapps-before" "$real_mimeapps"
  else
    [ ! -f "$real_mimeapps" ]
  fi
}

@test "activate registers the handler as the default browser" {
  seed_default_browser zen.desktop

  run "$CLI" activate
  [ "$status" -eq 0 ]

  run env -u BROWSER xdg-settings get default-web-browser
  [ "$output" = "omarchy-switchyard.desktop" ]
}

@test "activate writes a desktop entry whose Exec is the handler's bare path" {
  seed_default_browser zen.desktop
  "$CLI" activate

  run grep '^Exec=' "$XDG_DATA_HOME/applications/omarchy-switchyard.desktop"
  [ "$output" = "Exec=$REPO_ROOT/bin/omarchy-switchyard-open %u" ]
}

@test "activate writes a correct Exec= even when the handler's path contains # and &" {
  seed_default_browser zen.desktop
  local weird_dir="$HOME/han#dler&dir"
  mkdir -p "$weird_dir/bin" "$weird_dir/lib" "$weird_dir/share"
  cp "$REPO_ROOT/bin/omarchy-switchyard" "$REPO_ROOT/bin/omarchy-switchyard-open" "$weird_dir/bin/"
  cp "$REPO_ROOT/lib/desktop.sh" "$REPO_ROOT/lib/router.sh" "$REPO_ROOT/lib/launch.sh" "$weird_dir/lib/"
  cp "$REPO_ROOT/share/omarchy-switchyard.desktop" "$weird_dir/share/"
  chmod +x "$weird_dir/bin/omarchy-switchyard" "$weird_dir/bin/omarchy-switchyard-open"

  run "$weird_dir/bin/omarchy-switchyard" activate
  [ "$status" -eq 0 ]

  run grep '^Exec=' "$XDG_DATA_HOME/applications/omarchy-switchyard.desktop"
  [ "$output" = "Exec=$weird_dir/bin/omarchy-switchyard-open %u" ]
}

@test "activate records the previous default as the fallback" {
  seed_default_browser zen.desktop
  "$CLI" activate

  [ "$(cat "$XDG_CONFIG_HOME/omarchy-switchyard/fallback")" = "zen.desktop" ]
}

@test "activate prints the fallback it recorded" {
  seed_default_browser zen.desktop

  run "$CLI" activate
  [ "$status" -eq 0 ]
  [[ "$output" == *"unmatched links open in zen.desktop"* ]]
}

@test "a second activate leaves the default and fallback unchanged" {
  seed_default_browser zen.desktop
  "$CLI" activate

  run "$CLI" activate
  [ "$status" -eq 0 ]
  [[ "$output" == *"unmatched links open in zen.desktop"* ]]

  run env -u BROWSER xdg-settings get default-web-browser
  [ "$output" = "omarchy-switchyard.desktop" ]
  [ "$(cat "$XDG_CONFIG_HOME/omarchy-switchyard/fallback")" = "zen.desktop" ]
}

@test "activate with a Chromium-family fallback warns about Omarchy web apps" {
  seed_default_browser brave-browser.desktop

  run "$CLI" activate
  [ "$status" -eq 0 ]
  [[ "$output" == *"open in Chromium (not brave-browser.desktop)"* ]]
}

@test "a fallback set with fallback <id> while inactive survives activate" {
  seed_default_browser zen.desktop
  mkdir -p "$XDG_DATA_HOME/applications"
  cat >"$XDG_DATA_HOME/applications/chromium.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Chromium
Exec=/bin/true %u
EOF
  "$CLI" fallback chromium.desktop

  run "$CLI" activate
  [ "$status" -eq 0 ]
  [[ "$output" == *"unmatched links open in chromium.desktop"* ]]
  [ "$(cat "$XDG_CONFIG_HOME/omarchy-switchyard/fallback")" = "chromium.desktop" ]
}

@test "activate --fallback overrides an existing recorded fallback" {
  seed_default_browser zen.desktop
  mkdir -p "$XDG_DATA_HOME/applications"
  cat >"$XDG_DATA_HOME/applications/chromium.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Chromium
Exec=/bin/true %u
EOF
  "$CLI" fallback chromium.desktop

  run "$CLI" activate --fallback zen.desktop
  [ "$status" -eq 0 ]
  [ "$(cat "$XDG_CONFIG_HOME/omarchy-switchyard/fallback")" = "zen.desktop" ]
}

@test "a deactivate/activate cycle restores and keeps the same fallback browser" {
  seed_default_browser zen.desktop
  "$CLI" activate
  "$CLI" deactivate

  run "$CLI" activate
  [ "$status" -eq 0 ]
  [[ "$output" == *"unmatched links open in zen.desktop"* ]]
  [ "$(cat "$XDG_CONFIG_HOME/omarchy-switchyard/fallback")" = "zen.desktop" ]

  run env -u BROWSER xdg-settings get default-web-browser
  [ "$output" = "omarchy-switchyard.desktop" ]
}

@test "activate --fallback chromium.desktop records it and prints no web-app note" {
  seed_default_browser zen.desktop
  mkdir -p "$XDG_DATA_HOME/applications"
  cat >"$XDG_DATA_HOME/applications/chromium.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Chromium
Exec=/bin/true %u
EOF

  run "$CLI" activate --fallback chromium.desktop
  [ "$status" -eq 0 ]
  [[ "$output" != *"Note:"* ]]
  [ "$(cat "$XDG_CONFIG_HOME/omarchy-switchyard/fallback")" = "chromium.desktop" ]
}

@test "activate --fallback with an unknown desktop id fails and changes nothing" {
  seed_default_browser zen.desktop

  run "$CLI" activate --fallback nope.desktop
  [ "$status" -eq 1 ]

  run env -u BROWSER xdg-settings get default-web-browser
  [ "$output" = "zen.desktop" ]
  [ ! -f "$XDG_CONFIG_HOME/omarchy-switchyard/fallback" ]
  [ ! -f "$XDG_DATA_HOME/applications/omarchy-switchyard.desktop" ]
}

@test "activate --fallback omarchy-switchyard.desktop refuses it as Switchyard itself and changes nothing" {
  seed_default_browser zen.desktop
  cat >"$XDG_DATA_HOME/applications/omarchy-switchyard.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Switchyard
Exec=$REPO_ROOT/bin/omarchy-switchyard-open %u
EOF
  local before
  before=$(cat "$XDG_DATA_HOME/applications/omarchy-switchyard.desktop")

  run "$CLI" activate --fallback omarchy-switchyard.desktop
  [ "$status" -eq 1 ]
  [[ "$output" == *"omarchy-switchyard.desktop is Switchyard itself; choose a browser"* ]]

  run env -u BROWSER xdg-settings get default-web-browser
  [ "$output" = "zen.desktop" ]
  [ ! -f "$XDG_CONFIG_HOME/omarchy-switchyard/fallback" ]
  [ "$(cat "$XDG_DATA_HOME/applications/omarchy-switchyard.desktop")" = "$before" ]
}

@test "activate with no previous default and no recorded fallback fails with the --fallback hint" {
  seed_default_browser zen.desktop
  "$CLI" activate
  rm -f "$XDG_CONFIG_HOME/omarchy-switchyard/fallback"

  run "$CLI" activate
  [ "$status" -eq 1 ]
  [[ "$output" == *"--fallback <desktop-id>"* ]]
}

@test "fallback omarchy-switchyard.desktop refuses it as Switchyard itself and changes nothing" {
  cat >"$XDG_DATA_HOME/applications/omarchy-switchyard.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Switchyard
Exec=$REPO_ROOT/bin/omarchy-switchyard-open %u
EOF

  run "$CLI" fallback omarchy-switchyard.desktop
  [ "$status" -eq 1 ]
  [[ "$output" == *"omarchy-switchyard.desktop is Switchyard itself; choose a browser"* ]]
  [ ! -f "$XDG_CONFIG_HOME/omarchy-switchyard/fallback" ]
}

@test "deactivate restores the recorded fallback" {
  seed_default_browser zen.desktop
  "$CLI" activate

  run "$CLI" deactivate
  [ "$status" -eq 0 ]
  [[ "$output" == *"restored to zen.desktop"* ]]

  run env -u BROWSER xdg-settings get default-web-browser
  [ "$output" = "zen.desktop" ]
}

@test "deactivate with no recorded fallback leaves the default unchanged and exits 0" {
  seed_default_browser zen.desktop
  "$CLI" activate
  rm -f "$XDG_CONFIG_HOME/omarchy-switchyard/fallback"

  run "$CLI" deactivate
  [ "$status" -eq 0 ]
  [[ "$output" == *"no fallback browser is recorded"* ]]

  run env -u BROWSER xdg-settings get default-web-browser
  [ "$output" = "omarchy-switchyard.desktop" ]
}

@test "a second deactivate reports Switchyard is not active" {
  seed_default_browser zen.desktop
  "$CLI" activate
  "$CLI" deactivate

  run "$CLI" deactivate
  [ "$status" -eq 0 ]
  [[ "$output" == *"not active (default browser is zen.desktop)"* ]]
}

@test "status reports inactive before activate and active after" {
  seed_default_browser zen.desktop

  run "$CLI" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"active: no"* ]]

  "$CLI" activate

  run "$CLI" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"active: yes"* ]]
  [[ "$output" == *"fallback: zen.desktop"* ]]
}

@test "status counts the rules in a valid rules.json" {
  seed_default_browser zen.desktop
  mkdir -p "$XDG_CONFIG_HOME/omarchy-switchyard"
  cat >"$XDG_CONFIG_HOME/omarchy-switchyard/rules.json" <<'EOF'
{"version": 1, "rules": [{"host": "*.google.com", "target": "chromium.desktop"}, {"host": "basecamp.com", "target": "webapp"}]}
EOF

  run "$CLI" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"rules.json (2 rules)"* ]]
}

@test "status reports a missing rules.json" {
  seed_default_browser zen.desktop

  run "$CLI" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"rules.json (missing)"* ]]
}

@test "status reports an invalid rules.json" {
  seed_default_browser zen.desktop
  mkdir -p "$XDG_CONFIG_HOME/omarchy-switchyard"
  echo "not json" >"$XDG_CONFIG_HOME/omarchy-switchyard/rules.json"

  run "$CLI" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"rules.json (invalid JSON)"* ]]
}

@test "status --json parses and flips .active with activate/deactivate" {
  seed_default_browser zen.desktop

  run "$CLI" status --json
  [ "$status" -eq 0 ]
  run jq -e '.active == false and .default_browser == "zen.desktop"' <<<"$output"
  [ "$status" -eq 0 ]

  "$CLI" activate

  run "$CLI" status --json
  [ "$status" -eq 0 ]
  run jq -e '.active == true and .fallback == "zen.desktop"' <<<"$output"
  [ "$status" -eq 0 ]

  "$CLI" deactivate

  run "$CLI" status --json
  [ "$status" -eq 0 ]
  run jq -e '.active == false' <<<"$output"
  [ "$status" -eq 0 ]
}

@test "status --json reports rules_count and rules_state for two rules" {
  seed_default_browser zen.desktop
  mkdir -p "$XDG_CONFIG_HOME/omarchy-switchyard"
  cat >"$XDG_CONFIG_HOME/omarchy-switchyard/rules.json" <<'EOF'
{"version": 1, "rules": [{"host": "*.google.com", "target": "chromium.desktop"}, {"host": "basecamp.com", "target": "webapp"}]}
EOF

  run "$CLI" status --json
  [ "$status" -eq 0 ]
  run jq -e '.rules_state == "ok" and .rules_count == 2' <<<"$output"
  [ "$status" -eq 0 ]
}

@test "status --json reports rules_state missing when rules.json is absent" {
  seed_default_browser zen.desktop

  run "$CLI" status --json
  [ "$status" -eq 0 ]
  run jq -e '.rules_state == "missing" and .rules_count == null' <<<"$output"
  [ "$status" -eq 0 ]
}

@test "status --json reports rules_state invalid for a broken rules.json" {
  seed_default_browser zen.desktop
  mkdir -p "$XDG_CONFIG_HOME/omarchy-switchyard"
  echo "not json" >"$XDG_CONFIG_HOME/omarchy-switchyard/rules.json"

  run "$CLI" status --json
  [ "$status" -eq 0 ]
  run jq -e '.rules_state == "invalid" and .rules_count == null' <<<"$output"
  [ "$status" -eq 0 ]
}

@test "status --json reports fallback null before activate" {
  seed_default_browser zen.desktop

  run "$CLI" status --json
  [ "$status" -eq 0 ]
  run jq -e '.fallback == null' <<<"$output"
  [ "$status" -eq 0 ]
}

@test "--help prints usage and exits 0" {
  run "$CLI" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: omarchy-switchyard"* ]]
  [[ "$output" == *"rules list"* ]]
  [[ "$output" == *"rules add"* ]]
  [[ "$output" == *"rules remove"* ]]
  [[ "$output" == *"fallback"* ]]
  [[ "$output" == *"browsers"* ]]
}

@test "an unknown command exits 1" {
  run "$CLI" bogus
  [ "$status" -eq 1 ]
}

@test "no command exits 1" {
  run "$CLI"
  [ "$status" -eq 1 ]
}
