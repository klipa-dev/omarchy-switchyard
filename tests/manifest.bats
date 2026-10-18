load helpers

@test "manifest.json parses as JSON" {
  run jq -e . "$REPO_ROOT/manifest.json"
  [ "$status" -eq 0 ]
}

@test "manifest id is klipa.switchyard" {
  run jq -e -r '.id' "$REPO_ROOT/manifest.json"
  [ "$status" -eq 0 ]
  [ "$output" = "klipa.switchyard" ]
}

@test "manifest schemaVersion is 1" {
  run jq -e '.schemaVersion == 1' "$REPO_ROOT/manifest.json"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "every entry point names an existing file" {
  while IFS= read -r ep; do
    [ -f "$REPO_ROOT/$ep" ]
  done < <(jq -r '.entryPoints[]' "$REPO_ROOT/manifest.json")
}

@test "omarchy plugin validate accepts the repo" {
  run omarchy plugin validate "$REPO_ROOT"
  [ "$status" -eq 0 ]
}
