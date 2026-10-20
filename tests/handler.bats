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
  grep -q $'\texample.com\tchromium.desktop\tfallback:missing-target' "$XDG_STATE_HOME/omarchy-switchyard/log"
}

@test "a webapp rule falls back to the fallback browser as a normal window when the webapp browser isn't installed" {
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
  grep -q $'\texample.com\tchromium.desktop\tfallback' "$XDG_STATE_HOME/omarchy-switchyard/log"
}

@test "the log line holds the host only, never the full URL or its query string" {
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
  PATH="$stub_dir:$PATH" run "$handler" "https://example.com/login?token=secret-magic-link"
  [ "$status" -eq 0 ]
  grep -q $'\texample.com\tchromium.desktop\tfallback' "$XDG_STATE_HOME/omarchy-switchyard/log"
  run grep "secret-magic-link" "$XDG_STATE_HOME/omarchy-switchyard/log"
  [ "$status" -ne 0 ]
}

@test "the log line holds - for the host when the handler runs with no URL" {
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
  PATH="$stub_dir:$PATH" run "$handler"
  [ "$status" -eq 0 ]
  grep -q $'\t-\tchromium.desktop\tfallback' "$XDG_STATE_HOME/omarchy-switchyard/log"
}

@test "a rule routing to Switchyard's own desktop id falls back instead of looping, with the refusing line on stderr" {
  fake_browser zen.desktop
  mkdir -p "$XDG_CONFIG_HOME/omarchy-switchyard"
  echo "zen.desktop" >"$XDG_CONFIG_HOME/omarchy-switchyard/fallback"
  cat >"$XDG_CONFIG_HOME/omarchy-switchyard/rules.json" <<'EOF'
{ "version": 1, "rules": [ { "host": "loop.example", "target": "omarchy-switchyard.desktop" } ] }
EOF

  run --separate-stderr "$handler" --dry-run "https://loop.example/"
  [ "$status" -eq 0 ]
  [ "$output" = "setsid uwsm-app -- $HOME/fake-bin/zen.desktop https://loop.example/" ]
  [[ "$stderr" == *"switchyard: refusing to launch Switchyard itself"* ]]
}

@test "a non-dry run with a rule to Switchyard's own desktop id launches the fallback instead and logs fallback:self" {
  fake_browser chromium.desktop
  mkdir -p "$XDG_CONFIG_HOME/omarchy-switchyard"
  echo "chromium.desktop" >"$XDG_CONFIG_HOME/omarchy-switchyard/fallback"
  cat >"$XDG_CONFIG_HOME/omarchy-switchyard/rules.json" <<'EOF'
{ "version": 1, "rules": [ { "host": "loop.example", "target": "omarchy-switchyard.desktop" } ] }
EOF

  stub_dir="$BATS_TEST_TMPDIR/stubbin"
  mkdir -p "$stub_dir"
  cat >"$stub_dir/uwsm-app" <<'EOF'
#!/bin/bash
shift
exec "$@"
EOF
  chmod +x "$stub_dir/uwsm-app"
  PATH="$stub_dir:$PATH" run "$handler" "https://loop.example/path?token=secret"
  [ "$status" -eq 0 ]
  [ -f "$HOME/fake-bin/chromium.desktop.args" ]
  grep -q "https://loop.example/path?token=secret" "$HOME/fake-bin/chromium.desktop.args"
  grep -q $'\tloop.example\tchromium.desktop\tfallback:self' "$XDG_STATE_HOME/omarchy-switchyard/log"
}

@test "a fallback file naming Switchyard's own desktop id is skipped, falling back to the real default browser" {
  fake_browser zen.desktop
  mkdir -p "$XDG_CONFIG_HOME/omarchy-switchyard"
  echo "omarchy-switchyard.desktop" >"$XDG_CONFIG_HOME/omarchy-switchyard/fallback"
  cat >"$XDG_CONFIG_HOME/mimeapps.list" <<EOF
[Default Applications]
text/html=zen.desktop
x-scheme-handler/http=zen.desktop
x-scheme-handler/https=zen.desktop
EOF

  run --separate-stderr "$handler" --dry-run "https://example.com"
  [ "$status" -eq 0 ]
  [ "$output" = "setsid uwsm-app -- $HOME/fake-bin/zen.desktop https://example.com" ]
}
