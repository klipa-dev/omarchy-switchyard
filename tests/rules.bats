load helpers

CLI="$REPO_ROOT/bin/omarchy-switchyard"
RULES_FILE_PATH="omarchy-switchyard/rules.json"

setup() {
  isolate_home
}

rules_file() {
  echo "$XDG_CONFIG_HOME/$RULES_FILE_PATH"
}

# fake_installed_browser <desktop-id> — like fake_browser (tests/helpers.bash),
# plus a MimeType=x-scheme-handler/https line, so the entry also counts as
# an installed browser for `omarchy-switchyard browsers`.
fake_installed_browser() {
  fake_browser "$1"
  echo "MimeType=x-scheme-handler/https;" >>"$XDG_DATA_HOME/applications/$1"
}

@test "rules add creates the file with version 1" {
  fake_browser zen.desktop

  run "$CLI" rules add github.com zen.desktop
  [ "$status" -eq 0 ]

  run jq -e '.version == 1' "$(rules_file)"
  [ "$status" -eq 0 ]
  run jq -e -c '.rules' "$(rules_file)"
  [ "$status" -eq 0 ]
  [ "$output" = '[{"host":"github.com","target":"zen.desktop"}]' ]
}

@test "add twice with the same host replaces" {
  fake_browser zen.desktop
  fake_browser chromium.desktop
  "$CLI" rules add github.com zen.desktop

  run "$CLI" rules add github.com chromium.desktop
  [ "$status" -eq 0 ]

  run jq -c '.rules' "$(rules_file)"
  [ "$output" = '[{"host":"github.com","target":"chromium.desktop"}]' ]
}

@test "add appends in order" {
  fake_browser zen.desktop
  fake_browser chromium.desktop
  "$CLI" rules add github.com zen.desktop
  "$CLI" rules add basecamp.com webapp
  "$CLI" rules add example.com chromium.desktop

  run jq -c '[.rules[].host]' "$(rules_file)"
  [ "$output" = '["github.com","basecamp.com","example.com"]' ]
}

@test "add lowercases the host" {
  fake_browser zen.desktop

  "$CLI" rules add GitHub.COM zen.desktop

  run jq -r '.rules[0].host' "$(rules_file)"
  [ "$output" = "github.com" ]
}

@test "add rejects a bad host and changes nothing" {
  run "$CLI" rules add "bad host" webapp
  [ "$status" -eq 1 ]
  [ ! -f "$(rules_file)" ]
}

@test "add rejects a host with an empty label and changes nothing" {
  run "$CLI" rules add "a..com" webapp
  [ "$status" -eq 1 ]
  [ ! -f "$(rules_file)" ]
}

@test "add rejects an unknown target and changes nothing" {
  run "$CLI" rules add github.com nope.desktop
  [ "$status" -eq 1 ]
  [ ! -f "$(rules_file)" ]
}

@test "add rejects a non-.desktop target and changes nothing" {
  run "$CLI" rules add github.com notadesktop
  [ "$status" -eq 1 ]
  [[ "$output" == *"target must be webapp or a .desktop id"* ]]
  [ ! -f "$(rules_file)" ]
}

@test "add on an invalid file fails and leaves the bytes unchanged" {
  mkdir -p "$XDG_CONFIG_HOME/omarchy-switchyard"
  echo "not json" >"$(rules_file)"
  local before
  before=$(cat "$(rules_file)")
  fake_browser zen.desktop

  run "$CLI" rules add github.com zen.desktop
  [ "$status" -eq 1 ]
  [ "$(cat "$(rules_file)")" = "$before" ]
}

@test "add on a file whose rules is not an array fails and changes nothing" {
  mkdir -p "$XDG_CONFIG_HOME/omarchy-switchyard"
  echo '{"version": 1, "rules": "nope"}' >"$(rules_file)"
  local before
  before=$(cat "$(rules_file)")
  fake_browser zen.desktop

  run "$CLI" rules add github.com zen.desktop
  [ "$status" -eq 1 ]
  [ "$(cat "$(rules_file)")" = "$before" ]
}

@test "remove works" {
  fake_browser zen.desktop
  "$CLI" rules add github.com zen.desktop

  run "$CLI" rules remove github.com
  [ "$status" -eq 0 ]

  run jq -c '.rules' "$(rules_file)"
  [ "$output" = '[]' ]
}

@test "remove fails on a missing host" {
  fake_browser zen.desktop
  "$CLI" rules add github.com zen.desktop

  run "$CLI" rules remove nope.com
  [ "$status" -eq 1 ]

  run jq -c '.rules' "$(rules_file)"
  [ "$output" = '[{"host":"github.com","target":"zen.desktop"}]' ]
}

@test "remove fails when there is no rules file" {
  run "$CLI" rules remove github.com
  [ "$status" -eq 1 ]
}

@test "list text prints one <host> <target> line per rule in file order" {
  fake_browser zen.desktop
  "$CLI" rules add github.com zen.desktop
  "$CLI" rules add basecamp.com webapp

  run "$CLI" rules list
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$(printf 'github.com\tzen.desktop')" ]
  [ "${lines[1]}" = "$(printf 'basecamp.com\twebapp')" ]
}

@test "list text prints nothing when there are no rules" {
  run "$CLI" rules list
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "list --json prints the file's rules" {
  fake_browser zen.desktop
  "$CLI" rules add github.com zen.desktop

  run "$CLI" rules list --json
  [ "$status" -eq 0 ]
  run jq -e '. == [{"host":"github.com","target":"zen.desktop"}]' <<<"$output"
  [ "$status" -eq 0 ]
}

@test "list --json prints [] when the file is missing" {
  run "$CLI" rules list --json
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]
}

@test "fallback with no argument prints (none) when unset" {
  run "$CLI" fallback
  [ "$status" -eq 0 ]
  [ "$output" = "(none)" ]
}

@test "fallback sets and reports the fallback browser" {
  fake_browser zen.desktop

  run "$CLI" fallback zen.desktop
  [ "$status" -eq 0 ]

  run "$CLI" fallback
  [ "$status" -eq 0 ]
  [ "$output" = "zen.desktop" ]
}

@test "fallback rejects an unknown desktop id and changes nothing" {
  run "$CLI" fallback nope.desktop
  [ "$status" -eq 1 ]
  [ ! -f "$XDG_CONFIG_HOME/omarchy-switchyard/fallback" ]
}

@test "fallback rejects webapp as a target" {
  run "$CLI" fallback webapp
  [ "$status" -eq 1 ]
  [ ! -f "$XDG_CONFIG_HOME/omarchy-switchyard/fallback" ]
}

@test "browsers lists two fakes with their names and excludes ours and a NoDisplay one" {
  fake_installed_browser zen.desktop
  fake_installed_browser chromium.desktop

  cat >"$XDG_DATA_HOME/applications/hidden.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Hidden Browser
Exec=/bin/true %u
MimeType=x-scheme-handler/https;
NoDisplay=true
EOF

  cat >"$XDG_DATA_HOME/applications/omarchy-switchyard.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Switchyard
Exec=/bin/true %u
MimeType=x-scheme-handler/https;
EOF

  run "$CLI" browsers
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$(printf 'chromium.desktop\tchromium.desktop')" ]
  [ "${lines[1]}" = "$(printf 'zen.desktop\tzen.desktop')" ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "browsers --json parses and matches the text listing" {
  fake_installed_browser zen.desktop
  fake_installed_browser chromium.desktop

  run "$CLI" browsers --json
  [ "$status" -eq 0 ]
  run jq -e '. == [{"id":"chromium.desktop","name":"chromium.desktop"},{"id":"zen.desktop","name":"zen.desktop"}]' <<<"$output"
  [ "$status" -eq 0 ]
}

@test "a rule written by rules add routes a URL the same way the handler would" {
  fake_browser zen.desktop
  "$CLI" rules add github.com zen.desktop

  run "$REPO_ROOT/bin/omarchy-switchyard-open" --dry-run "https://github.com"
  [ "$status" -eq 0 ]
  [ "$output" = "setsid uwsm-app -- $HOME/fake-bin/zen.desktop https://github.com" ]
}
