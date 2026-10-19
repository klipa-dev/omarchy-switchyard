bats_require_minimum_version 1.5.0

load helpers

setup() {
  isolate_home
  source "$REPO_ROOT/lib/router.sh"
  fixtures="$BATS_TEST_DIRNAME/fixtures"
  nonexistent_fallback="$BATS_TEST_TMPDIR/no-fallback"
}

@test "a bare host matches itself and its subdomains" {
  run --separate-stderr switchyard_route "https://basecamp.com" "$fixtures/rules-basic.json" "$nonexistent_fallback"
  [ "$status" -eq 0 ]
  [ "$output" = $'chromium.desktop\trule:basecamp.com' ]

  echo "chromium.desktop" >"$BATS_TEST_TMPDIR/fallback"
  run --separate-stderr switchyard_route "https://www.basecamp.com" "$fixtures/rules-basic.json" "$BATS_TEST_TMPDIR/fallback"
  [ "$status" -eq 0 ]
  [ "$output" = $'chromium.desktop\trule:basecamp.com' ]
}

@test "a bare host does not match a host that merely shares a suffix" {
  run _switchyard_host_matches "notexample.com" "example.com"
  [ "$status" -eq 1 ]

  run _switchyard_host_matches "example.com.evil.net" "example.com"
  [ "$status" -eq 1 ]
}

@test "wildcard matches apex and subdomain" {
  echo "firefox.desktop" >"$BATS_TEST_TMPDIR/fallback"
  run --separate-stderr switchyard_route "https://google.com" "$fixtures/rules-basic.json" "$BATS_TEST_TMPDIR/fallback"
  [ "$status" -eq 0 ]
  [ "$output" = $'chromium.desktop\trule:*.google.com' ]

  run --separate-stderr switchyard_route "https://mail.google.com" "$fixtures/rules-basic.json" "$BATS_TEST_TMPDIR/fallback"
  [ "$status" -eq 0 ]
  [ "$output" = $'chromium.desktop\trule:*.google.com' ]
}

@test "first match wins" {
  echo "firefox.desktop" >"$BATS_TEST_TMPDIR/fallback"
  run --separate-stderr switchyard_route "https://mail.example.com" "$fixtures/rules-basic.json" "$BATS_TEST_TMPDIR/fallback"
  [ "$status" -eq 0 ]
  [ "$output" = $'first.desktop\trule:*.example.com' ]
}

@test "uppercase, port and userinfo are normalised" {
  echo "firefox.desktop" >"$BATS_TEST_TMPDIR/fallback"
  run --separate-stderr switchyard_route "HTTPS://user:pass@GITHUB.com:443/foo?bar=1" "$fixtures/rules-basic.json" "$BATS_TEST_TMPDIR/fallback"
  [ "$status" -eq 0 ]
  [ "$output" = $'zen.desktop\trule:github.com' ]
}

@test "http and https both match" {
  echo "firefox.desktop" >"$BATS_TEST_TMPDIR/fallback"
  run --separate-stderr switchyard_route "http://github.com" "$fixtures/rules-basic.json" "$BATS_TEST_TMPDIR/fallback"
  [ "$output" = $'zen.desktop\trule:github.com' ]

  run --separate-stderr switchyard_route "https://github.com" "$fixtures/rules-basic.json" "$BATS_TEST_TMPDIR/fallback"
  [ "$output" = $'zen.desktop\trule:github.com' ]
}

@test "mailto, ftp and a bare word fall back" {
  echo "firefox.desktop" >"$BATS_TEST_TMPDIR/fallback"
  run --separate-stderr switchyard_route "mailto:a@github.com" "$fixtures/rules-basic.json" "$BATS_TEST_TMPDIR/fallback"
  [ "$output" = $'firefox.desktop\tfallback' ]

  run --separate-stderr switchyard_route "ftp://github.com" "$fixtures/rules-basic.json" "$BATS_TEST_TMPDIR/fallback"
  [ "$output" = $'firefox.desktop\tfallback' ]

  run --separate-stderr switchyard_route "github.com" "$fixtures/rules-basic.json" "$BATS_TEST_TMPDIR/fallback"
  [ "$output" = $'firefox.desktop\tfallback' ]
}

@test "missing rules file falls back" {
  echo "firefox.desktop" >"$BATS_TEST_TMPDIR/fallback"
  run --separate-stderr switchyard_route "https://github.com" "$BATS_TEST_TMPDIR/no-such-rules.json" "$BATS_TEST_TMPDIR/fallback"
  [ "$status" -eq 0 ]
  [ "$output" = $'firefox.desktop\tfallback' ]
  [ -z "$stderr" ]
}

@test "invalid JSON falls back with the stderr line" {
  echo "firefox.desktop" >"$BATS_TEST_TMPDIR/fallback"
  run --separate-stderr switchyard_route "https://github.com" "$fixtures/rules-invalid.json" "$BATS_TEST_TMPDIR/fallback"
  [ "$status" -eq 0 ]
  [ "$output" = $'firefox.desktop\tfallback' ]
  [[ $stderr == *"rules.json is invalid, using the fallback"* ]]
}

@test "rules.json whose rules is not an array falls back with the stderr line" {
  echo "firefox.desktop" >"$BATS_TEST_TMPDIR/fallback"
  run --separate-stderr switchyard_route "https://github.com" "$fixtures/rules-not-array.json" "$BATS_TEST_TMPDIR/fallback"
  [ "$status" -eq 0 ]
  [ "$output" = $'firefox.desktop\tfallback' ]
  [[ $stderr == *"rules.json is invalid, using the fallback"* ]]
}

@test "a rule missing target is skipped and the next one matches" {
  echo "firefox.desktop" >"$BATS_TEST_TMPDIR/fallback"
  run --separate-stderr switchyard_route "https://good.example.com" "$fixtures/rules-missing-target.json" "$BATS_TEST_TMPDIR/fallback"
  [ "$status" -eq 0 ]
  [ "$output" = $'chromium.desktop\trule:good.example.com' ]
  [[ $stderr == *"rule 0 is missing host or target"* ]]
}

@test "a non-object rule is skipped and the next one matches" {
  echo "firefox.desktop" >"$BATS_TEST_TMPDIR/fallback"
  run --separate-stderr switchyard_route "https://github.com" "$fixtures/rules-non-object.json" "$BATS_TEST_TMPDIR/fallback"
  [ "$status" -eq 0 ]
  [ "$output" = $'zen.desktop\trule:github.com' ]
  [[ $stderr == *"rule 0 is missing host or target"* ]]
}

@test "a rule's host pattern matches regardless of its own case" {
  echo "firefox.desktop" >"$BATS_TEST_TMPDIR/fallback"
  run --separate-stderr switchyard_route "https://github.com" "$fixtures/rules-mixed-case.json" "$BATS_TEST_TMPDIR/fallback"
  [ "$status" -eq 0 ]
  [ "$output" = $'zen.desktop\trule:GitHub.com' ]
}

@test "webapp target" {
  echo "firefox.desktop" >"$BATS_TEST_TMPDIR/fallback"
  run --separate-stderr switchyard_route "https://work.example.org" "$fixtures/rules-basic.json" "$BATS_TEST_TMPDIR/fallback"
  [ "$status" -eq 0 ]
  [ "$output" = $'webapp\trule:work.example.org' ]
}

@test "fallback file read" {
  echo "brave.desktop" >"$BATS_TEST_TMPDIR/fallback"
  run --separate-stderr switchyard_route "https://no-match.example.net" "$fixtures/rules-basic.json" "$BATS_TEST_TMPDIR/fallback"
  [ "$status" -eq 0 ]
  [ "$output" = $'brave.desktop\tfallback' ]
}

@test "fallback file missing with xdg-settings pointing at a fake browser" {
  fake_browser zen.desktop
  cat >"$XDG_CONFIG_HOME/mimeapps.list" <<EOF
[Default Applications]
text/html=zen.desktop
x-scheme-handler/http=zen.desktop
x-scheme-handler/https=zen.desktop
EOF
  run --separate-stderr switchyard_route "https://no-match.example.net" "$fixtures/rules-basic.json" "$nonexistent_fallback"
  [ "$status" -eq 0 ]
  [ "$output" = $'zen.desktop\tfallback' ]
}
