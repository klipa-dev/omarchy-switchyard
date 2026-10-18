load helpers

# End-to-end: the CLI's open command, wired through to the handler and
# launch library, exercised the way a real install would be: activate,
# click a few links, check status, deactivate, and confirm routing still
# works afterwards (routing never depends on being active).

CLI="$REPO_ROOT/bin/omarchy-switchyard"

setup() {
  isolate_home
  seed_default_browser zen.desktop
  fake_browser chromium.desktop

  mkdir -p "$XDG_CONFIG_HOME/omarchy-switchyard"
  cat >"$XDG_CONFIG_HOME/omarchy-switchyard/rules.json" <<'EOF'
{ "version": 1, "rules": [ { "host": "*.google.com", "target": "chromium.desktop" }, { "host": "*.basecamp.com", "target": "webapp" } ] }
EOF

  run "$CLI" activate
  [ "$status" -eq 0 ]
}

@test "activate took over as the default browser" {
  run env -u BROWSER xdg-settings get default-web-browser
  [ "$output" = "omarchy-switchyard.desktop" ]
}

@test "open --dry-run on a rule match prints the matching browser's launch line" {
  run "$CLI" open --dry-run "https://meet.google.com/abc"
  [ "$status" -eq 0 ]
  [ "$output" = "setsid uwsm-app -- $HOME/fake-bin/chromium.desktop https://meet.google.com/abc" ]
}

@test "open --dry-run on an unmatched link prints the seeded zen fallback's launch line" {
  run "$CLI" open --dry-run "https://example.com"
  [ "$status" -eq 0 ]
  [ "$output" = "setsid uwsm-app -- /bin/true https://example.com" ]
}

@test "open --dry-run on a webapp rule resolves through Chromium, not the non-Chromium fallback" {
  run "$CLI" open --dry-run "https://3.basecamp.com/x"
  [ "$status" -eq 0 ]
  [ "$output" = "setsid uwsm-app -- $HOME/fake-bin/chromium.desktop --app=https://3.basecamp.com/x" ]
}

@test "status shows Switchyard active with its rules loaded" {
  run "$CLI" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"active: yes"* ]]
  [[ "$output" == *"(2 rules)"* ]]
}

@test "deactivate restores the recorded fallback" {
  run "$CLI" deactivate
  [ "$status" -eq 0 ]
  [[ "$output" == *"restored to zen.desktop"* ]]

  run env -u BROWSER xdg-settings get default-web-browser
  [ "$output" = "zen.desktop" ]
}

@test "a dry run after deactivating still routes correctly" {
  run "$CLI" deactivate
  [ "$status" -eq 0 ]

  run "$CLI" open --dry-run "https://meet.google.com/abc"
  [ "$status" -eq 0 ]
  [ "$output" = "setsid uwsm-app -- $HOME/fake-bin/chromium.desktop https://meet.google.com/abc" ]
}
