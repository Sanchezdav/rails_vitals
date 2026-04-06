# Test

Run the relevant tests for changed files, report failures, and fix them using the test output as guidance.

## Steps

1. Identify changed `.rb` files using `git diff --name-only HEAD`.
2. Map each source file to its test counterpart:
   - `lib/rails_vitals/foo/bar.rb` → `test/lib/rails_vitals/foo/bar_test.rb`
   - `app/controllers/rails_vitals/foo_controller.rb` → `test/controllers/rails_vitals/foo_controller_test.rb`
   - `app/helpers/rails_vitals/foo_helper.rb` → `test/helpers/rails_vitals/foo_helper_test.rb`
   - If the changed file is already a test file, run it directly.
   - If no matching test file exists, run the full suite with `bin/rails test`.
3. Run the mapped test files with `bin/rails test <files>`.
4. If all tests pass, report success and stop.
5. If tests fail, read the failure output carefully, then read the relevant source and test files.
6. Fix the failing code (prefer fixing source over changing tests, unless the test expectation is clearly wrong).
7. Re-run the same test files to confirm they pass.
8. Report a summary: files tested, number of failures fixed, and final status.

## Rules

- Never delete or comment out a failing test to make it pass.
- Do not change test assertions unless the expected behavior itself changed.
- Use `with_stub` for dependency isolation, do not modify global state in tests.
- If a failure is ambiguous or the fix would change observable behavior, ask the user before editing.
