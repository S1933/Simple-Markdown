# CLAUDE.md

Read [`AGENTS.md`](AGENTS.md) first — it holds every hard rule, convention,
and the build/test pipeline. This file only adds Claude Code specifics.

## Claude Code specifics

- Prefer `Edit` over rewriting whole files; diffs must stay surgical.
- Before "done": list changed files and why, then run the pipeline from
  `AGENTS.md` § Build & test. If you cannot, state
  "verification not run: no Xcode environment".
- Hard rules and conventions are in `AGENTS.md`. Do not duplicate them here.
