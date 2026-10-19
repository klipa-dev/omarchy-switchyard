load helpers

# This repo is published by mirroring its main branch into a public repo, so
# nothing tracked may point back at the private planning workspace it is
# developed in.

@test "no tracked file refers to the private planning workspace" {
  run git -C "$REPO_ROOT" grep -n -I -E \
    'TASKS\.md|LEAD\.md|CLAUDE\.md|AGENTS\.md|repos/app\.md|omarchy-switchyard-workspace|\bA[0-9]+\b|\bX[0-9]+\b' \
    -- . ':!tests/public.bats'
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "no tracked file is a workflow file for the private workspace" {
  run git -C "$REPO_ROOT" ls-files -- \
    ":(glob)**/CLAUDE.md" ":(glob)**/AGENTS.md" ":(glob)**/.claude/**"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
