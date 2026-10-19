load helpers

@test "manifest.json parses as JSON" {
  run jq -e . "$REPO_ROOT/manifest.json"
  [ "$status" -eq 0 ]
}

@test "manifest id is benviu.switchyard" {
  run jq -e -r '.id' "$REPO_ROOT/manifest.json"
  [ "$status" -eq 0 ]
  [ "$output" = "benviu.switchyard" ]
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

@test "manifest kinds contains panel" {
  run jq -e '.kinds | index("panel") != null' "$REPO_ROOT/manifest.json"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "manifest entryPoints.panel is Panel.qml" {
  run jq -e -r '.entryPoints.panel' "$REPO_ROOT/manifest.json"
  [ "$status" -eq 0 ]
  [ "$output" = "Panel.qml" ]
}

@test "Panel.qml exists" {
  [ -f "$REPO_ROOT/Panel.qml" ]
}

@test "qmllint accepts Panel.qml" {
  run qmllint -I /usr/lib/qt6/qml -I /usr/share/omarchy/shell "$REPO_ROOT/Panel.qml"
  [ "$status" -eq 0 ]
}

@test "Panel.qml implements the summoned-panel host contract" {
  run grep -c 'function open\|function close\|property bool opened' "$REPO_ROOT/Panel.qml"
  [ "$status" -eq 0 ]
  [ "$output" -eq 3 ]
}
