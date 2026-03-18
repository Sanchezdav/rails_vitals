# Contributing to RailsVitals

Thanks for your interest in contributing to RailsVitals!
All participation in this project is expected to follow our [Code of Conduct](CODE_OF_CONDUCT.md).

## Reporting Issues

Before opening a new issue, please:

- Search existing issues to avoid duplicates
- Verify the issue against the latest code on `main`
- Provide a minimal reproduction (ideally a small Rails app or isolated failing test)
- Include your Ruby, Rails, database, and OS versions
- Include logs, stack traces, and exact steps to reproduce

If you found a security issue, **do not open a public GitHub issue**.
Please report it privately to: **sanchez.dav90@gmail.com**

## Suggesting Enhancements

Feature requests are welcome. Please include:

- The problem you are trying to solve
- Why existing behavior is insufficient
- A proposed API/UX (if relevant)
- Tradeoffs or alternatives considered

## Submitting Pull Requests

1. Fork the repository and create a focused branch
2. Keep PRs small and scoped to one concern
3. Add or update tests for behavior changes
4. Update docs when behavior/API changes
5. Ensure tests pass before opening the PR
6. Open a clear PR description with context and rationale

### Commit and PR Quality

- Prefer clear, descriptive commit messages
- Keep backward compatibility when possible
- Avoid unrelated refactors in the same PR
- Explain any intentional breaking behavior

## Development Setup

```bash
git clone https://github.com/Sanchezdav/rails_vitals.git
cd rails_vitals
bundle install
```

If you want to test RailsVitals in another app locally:

```ruby
# Gemfile of the target app
gem "rails_vitals", path: "../rails_vitals"
```

## Running Tests

Run the test suite from the gem root:

```bash
bundle exec rake test
```

If needed, run specific tests:

```bash
bundle exec ruby -Itest test/controllers/rails_vitals/dashboard_controller_test.rb
```

## Coding Guidelines

- Follow the existing style and structure in the codebase
- Prefer small, focused methods and readable naming
- Keep dependencies minimal (RailsVitals aims to stay lightweight)
- Add tests for bug fixes and new features
- Keep docs in sync with behavior

## Documentation Contributions

Documentation improvements are always welcome, including:

- README clarity and examples
- Better troubleshooting notes
- More accurate architecture explanations
- Typos, formatting, and consistency fixes

## Questions

For usage questions, check [README.md](README.md) first.
If something is unclear, open an issue with the `question` context and relevant details.

Thanks again for helping improve RailsVitals ⚡
