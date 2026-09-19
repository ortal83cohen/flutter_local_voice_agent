@AGENTS.md

## Claude Code specifics

- Use plan mode before starting the `implement` phase of any `/feature` work item.
- Skills live in `.claude/skills/`. Subagents live in `.claude/agents/`. Both are shared with Cursor; do not duplicate them under `.cursor/`.
- Path-scoped rules live in `.claude/rules/`. Their Cursor mirrors live in `.cursor/rules/`. When you change one, change the other in the same commit.
- Run `python3 tools/lint_wiki.py` before reporting any phase complete.
