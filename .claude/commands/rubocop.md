# RuboCop

Run RuboCop on the changed files, auto-fix safe offenses, then iterate on remaining violations using the output as guidance until the code is clean.

## Steps

1. Identify changed files (staged + unstaged) using `git diff --name-only HEAD` filtered to `.rb` files. If no changed files, run on the whole project.
2. Run `bin/rubocop --format json <files>` to get structured violation output.
3. If there are auto-correctable offenses, run `bin/rubocop -A <files>` to apply all safe and unsafe auto-corrections.
4. Re-run `bin/rubocop --format json <files>` to get the remaining violations that could not be auto-corrected.
5. For each remaining violation, read the offending file and fix it manually using the Edit tool, following the cop name and message as guidance.
6. Re-run `bin/rubocop <files>` to confirm no offenses remain.
7. Report a summary: how many offenses were auto-fixed, how many were manually fixed, and whether the run is clean.

## Rules

- Never disable cops with `# rubocop:disable` comments unless the user explicitly asks.
- Prefer the simplest fix that satisfies the cop — do not refactor surrounding code.
- If a violation is ambiguous or the fix would meaningfully change behavior, ask the user before editing.
