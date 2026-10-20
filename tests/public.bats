load helpers

# This repo is published by mirroring its main branch into a public repo, so
# nothing tracked may point at private planning notes.

@test "no tracked file refers to the private planning notes" {
  run git -C "$REPO_ROOT" grep -n -I -E \
    'CLAUDE\.md|AGENTS\.md|\.claude/|TASKS\.md|LEAD\.md|\b[AX][0-9]+\b' \
    -- . ':!tests/public.bats'
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "no tracked file is a workflow file for the private planning notes" {
  run git -C "$REPO_ROOT" ls-files -- \
    ":(glob)**/CLAUDE.md" ":(glob)**/AGENTS.md" ":(glob)**/.claude/**"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
