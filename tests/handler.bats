bats_require_minimum_version 1.5.0

load helpers

setup() {
  isolate_home
  handler="$REPO_ROOT/bin/omarchy-switchyard-open"
}

@test "--help exits 0" {
  run "$handler" --help
  [ "$status" -eq 0 ]
  [[ $output == Usage:* ]]

  run "$handler" -h
  [ "$status" -eq 0 ]
}

@test "a matching URL prints the fake browser's exec" {
  fake_browser zen.desktop
  mkdir -p "$XDG_CONFIG_HOME/omarchy-switchyard"
  cat >"$XDG_CONFIG_HOME/omarchy-switchyard/rules.json" <<'EOF'
{ "version": 1, "rules": [ { "host": "github.com", "target": "zen.desktop" } ] }
EOF
  run "$handler" --dry-run "https://github.com"
  [ "$status" -eq 0 ]
  [ "$output" = "setsid uwsm-app -- $HOME/fake-bin/zen.desktop https://github.com" ]
}

@test "no URL prints the fallback launch without a URL" {
  fake_browser chromium.desktop
  mkdir -p "$XDG_CONFIG_HOME/omarchy-switchyard"
  echo "chromium.desktop" >"$XDG_CONFIG_HOME/omarchy-switchyard/fallback"
  run "$handler" --dry-run
  [ "$status" -eq 0 ]
  [ "$output" = "setsid uwsm-app -- $HOME/fake-bin/chromium.desktop" ]
}

@test "--incognito becomes --private-window for a --mozilla fake" {
  fake_browser zen.desktop --mozilla
  mkdir -p "$XDG_CONFIG_HOME/omarchy-switchyard"
  echo "zen.desktop" >"$XDG_CONFIG_HOME/omarchy-switchyard/fallback"
  run "$handler" --dry-run --incognito "https://example.com"
  [ "$status" -eq 0 ]
  [ "$output" = "setsid uwsm-app -- $HOME/fake-bin/zen.desktop --private-window https://example.com" ]
}

@test "--incognito stays for a plain fake" {
  fake_browser chromium.desktop
  mkdir -p "$XDG_CONFIG_HOME/omarchy-switchyard"
  echo "chromium.desktop" >"$XDG_CONFIG_HOME/omarchy-switchyard/fallback"
  run "$handler" --dry-run --incognito "https://example.com"
  [ "$status" -eq 0 ]
  [ "$output" = "setsid uwsm-app -- $HOME/fake-bin/chromium.desktop --incognito https://example.com" ]
}

@test "a webapp rule with a non-mozilla brave fallback opens brave as the app" {
  fake_browser brave-browser.desktop
  mkdir -p "$XDG_CONFIG_HOME/omarchy-switchyard"
  echo "brave-browser.desktop" >"$XDG_CONFIG_HOME/omarchy-switchyard/fallback"
  cat >"$XDG_CONFIG_HOME/omarchy-switchyard/rules.json" <<'EOF'
{ "version": 1, "rules": [ { "host": "basecamp.com", "target": "webapp" } ] }
EOF
  run "$handler" --dry-run --new-window "https://basecamp.com"
  [ "$status" -eq 0 ]
  [ "$output" = "setsid uwsm-app -- $HOME/fake-bin/brave-browser.desktop --app=https://basecamp.com" ]
}

@test "a webapp rule with a non-Chromium fallback opens chromium.desktop as the app" {
  fake_browser chromium.desktop
  mkdir -p "$XDG_CONFIG_HOME/omarchy-switchyard"
  echo "zen.desktop" >"$XDG_CONFIG_HOME/omarchy-switchyard/fallback"
  cat >"$XDG_CONFIG_HOME/omarchy-switchyard/rules.json" <<'EOF'
{ "version": 1, "rules": [ { "host": "basecamp.com", "target": "webapp" } ] }
EOF
  run "$handler" --dry-run "https://basecamp.com"
  [ "$status" -eq 0 ]
  [ "$output" = "setsid uwsm-app -- $HOME/fake-bin/chromium.desktop --app=https://basecamp.com" ]
}

@test "an unknown flag passes through" {
  fake_browser chromium.desktop
  mkdir -p "$XDG_CONFIG_HOME/omarchy-switchyard"
  echo "chromium.desktop" >"$XDG_CONFIG_HOME/omarchy-switchyard/fallback"
  run "$handler" --dry-run --some-unknown-flag "https://example.com"
  [ "$status" -eq 0 ]
  [ "$output" = "setsid uwsm-app -- $HOME/fake-bin/chromium.desktop --some-unknown-flag https://example.com" ]
}

@test "a real run launches the browser through a uwsm-app stub" {
  fake_browser chromium.desktop
  mkdir -p "$XDG_CONFIG_HOME/omarchy-switchyard"
  echo "chromium.desktop" >"$XDG_CONFIG_HOME/omarchy-switchyard/fallback"

  stub_dir="$BATS_TEST_TMPDIR/stubbin"
  mkdir -p "$stub_dir"
  cat >"$stub_dir/uwsm-app" <<'EOF'
#!/bin/bash
shift
exec "$@"
EOF
  chmod +x "$stub_dir/uwsm-app"
  PATH="$stub_dir:$PATH" run "$handler" "https://example.com"
  [ "$status" -eq 0 ]
  [ -f "$HOME/fake-bin/chromium.desktop.args" ]
  grep -q "https://example.com" "$HOME/fake-bin/chromium.desktop.args"
}

@test "a rule to an uninstalled browser opens the fallback, with a notice, and logs fallback:missing-target" {
  fake_browser chromium.desktop
  mkdir -p "$XDG_CONFIG_HOME/omarchy-switchyard"
  echo "chromium.desktop" >"$XDG_CONFIG_HOME/omarchy-switchyard/fallback"
  cat >"$XDG_CONFIG_HOME/omarchy-switchyard/rules.json" <<'EOF'
{ "version": 1, "rules": [ { "host": "example.com", "target": "nope.desktop" } ] }
EOF

  run --separate-stderr "$handler" --dry-run "https://example.com"
  [ "$status" -eq 0 ]
  [ "$output" = "setsid uwsm-app -- $HOME/fake-bin/chromium.desktop https://example.com" ]
  [[ "$stderr" == *"switchyard: no desktop entry for nope.desktop"* ]]
  [[ "$stderr" == *"Switchyard: nope.desktop is not installed, opening in chromium.desktop"* ]]

  stub_dir="$BATS_TEST_TMPDIR/stubbin"
  mkdir -p "$stub_dir"
  cat >"$stub_dir/uwsm-app" <<'EOF'
#!/bin/bash
shift
exec "$@"
EOF
  chmod +x "$stub_dir/uwsm-app"
  PATH="$stub_dir:$PATH" run "$handler" "https://example.com"
  [ "$status" -eq 0 ]
  grep -q $'\thttps://example.com\tchromium.desktop\tfallback:missing-target' "$XDG_STATE_HOME/omarchy-switchyard/log"
}

@test "a webapp rule falls back to the fallback browser as a normal window when the webapp browser isn't installed" {
  if [[ -e /usr/share/applications/chromium.desktop ]]; then
    skip "chromium.desktop is installed on this machine, so the hardcoded webapp browser always resolves"
  fi
  fake_browser zen.desktop
  mkdir -p "$XDG_CONFIG_HOME/omarchy-switchyard"
  echo "zen.desktop" >"$XDG_CONFIG_HOME/omarchy-switchyard/fallback"
  cat >"$XDG_CONFIG_HOME/omarchy-switchyard/rules.json" <<'EOF'
{ "version": 1, "rules": [ { "host": "basecamp.com", "target": "webapp" } ] }
EOF

  run --separate-stderr "$handler" --dry-run "https://basecamp.com"
  [ "$status" -eq 0 ]
  [ "$output" = "setsid uwsm-app -- $HOME/fake-bin/zen.desktop https://basecamp.com" ]
  [[ "$stderr" == *"not installed, opening in zen.desktop"* ]]
}

@test "--incognito survives the fallback retry" {
  fake_browser zen.desktop --mozilla
  mkdir -p "$XDG_CONFIG_HOME/omarchy-switchyard"
  echo "zen.desktop" >"$XDG_CONFIG_HOME/omarchy-switchyard/fallback"
  cat >"$XDG_CONFIG_HOME/omarchy-switchyard/rules.json" <<'EOF'
{ "version": 1, "rules": [ { "host": "example.com", "target": "nope.desktop" } ] }
EOF

  run --separate-stderr "$handler" --dry-run --incognito "https://example.com"
  [ "$status" -eq 0 ]
  [ "$output" = "setsid uwsm-app -- $HOME/fake-bin/zen.desktop --private-window https://example.com" ]
}

@test "a target that is already the fallback, with no browser at all, still fails" {
  mkdir -p "$XDG_CONFIG_HOME/omarchy-switchyard"
  echo "ghost.desktop" >"$XDG_CONFIG_HOME/omarchy-switchyard/fallback"

  run "$handler" --dry-run "https://example.com"
  [ "$status" -ne 0 ]
}

@test "a rule whose target and fallback are both uninstalled fails without logging a fallback line" {
  mkdir -p "$XDG_CONFIG_HOME/omarchy-switchyard"
  echo "ghost.desktop" >"$XDG_CONFIG_HOME/omarchy-switchyard/fallback"
  cat >"$XDG_CONFIG_HOME/omarchy-switchyard/rules.json" <<'EOF'
{ "version": 1, "rules": [ { "host": "example.com", "target": "nope.desktop" } ] }
EOF

  run "$handler" "https://example.com"
  [ "$status" -ne 0 ]
  [ ! -f "$XDG_STATE_HOME/omarchy-switchyard/log" ]
}

@test "the log line is written on a non-dry run and absent on a dry run" {
  fake_browser chromium.desktop
  mkdir -p "$XDG_CONFIG_HOME/omarchy-switchyard"
  echo "chromium.desktop" >"$XDG_CONFIG_HOME/omarchy-switchyard/fallback"

  run "$handler" --dry-run "https://example.com"
  [ "$status" -eq 0 ]
  [ ! -f "$XDG_STATE_HOME/omarchy-switchyard/log" ]

  stub_dir="$BATS_TEST_TMPDIR/stubbin"
  mkdir -p "$stub_dir"
  cat >"$stub_dir/uwsm-app" <<'EOF'
#!/bin/bash
shift
exec "$@"
EOF
  chmod +x "$stub_dir/uwsm-app"
  PATH="$stub_dir:$PATH" run "$handler" "https://example.com"
  [ "$status" -eq 0 ]
  [ -f "$XDG_STATE_HOME/omarchy-switchyard/log" ]
  grep -q $'\thttps://example.com\tchromium.desktop\tfallback' "$XDG_STATE_HOME/omarchy-switchyard/log"
}
