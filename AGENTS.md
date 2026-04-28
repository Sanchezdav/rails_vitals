# AGENTS.md — RailsVitals

RailsVitals is a mountable Rails Engine gem that instruments every request and surfaces performance diagnostics via an embedded admin UI.

## Commands

```bash
# Install dependencies
bundle install

# Run all tests
bin/rails db:test:prepare test
# or
bundle exec rake test

# Run a single test file
bin/rails test test/lib/rails_vitals/collector_test.rb

# Run a single test by name
bin/rails test test/lib/rails_vitals/collector_test.rb -n test_add_query

# Run tests matching a pattern
bin/rails test -p /n_plus_one/

# Lint
bin/rubocop
bin/rubocop -f github   # CI format
```

## Testing Patterns

RailsVitals uses Minitest (no mock extensions). Tests rely on manual stubs:

```ruby
# Stub a class method
with_stub(MyClass, :method_name, return_value_or_lambda) { ... }

# Struct doubles for complex objects
RecordDouble = Struct.new(:id, :queries) { def total_query_count; queries.size; end }
StoreDouble = Struct.new(:all) { def find(id); all.find { |r| r.id == id }; end }

# Access private methods in tests
result = Analyzer.send(:detect_n1, queries)
```

**Support helpers** (in `test/support/rails_vitals_test_support.rb`):
- `with_stub(target, method_name, value)` — temporarily redefine a singleton method
- `with_rails_vitals_config(overrides)` — temporarily override gem config
- `build_query(sql:, duration_ms:, source:)` — create a query hash
- `build_collector(queries:, callbacks:)` — create a Collector with preloaded data

Always call private methods with `.send(:method_name, args)` in tests. Keep stubs simple — only override what the test needs.

## Code Style

This project follows **rubocop-rails-omakase** (`.rubocop.yml`). Key conventions:

### Imports & Requires
- Use `require_relative` for local files within the same directory tree
- Gem entry point (`lib/rails_vitals.rb`) uses bare `require` for all lib files in load order
- Test files always start with `require "test_helper"`

### Naming Conventions
- Classes/Modules: `PascalCase` (e.g., `NPlusOneAggregator`, `PanelInjector`)
- Methods/variables: `snake_case` (e.g., `total_query_count`, `duration_ms`)
- Test classes: `RailsVitalsCollectorTest` (prefix with module name)
- Test methods: `test "#method_name does something"` (string description style)
- Constants: `UPPER_SNAKE_CASE` (e.g., `COLOR_GREEN`, `VERSION`)

### Formatting
- 2-space indentation (no tabs)
- Trailing commas in multi-line arrays/hashes
- Space inside hash rockets: `{ key: "value" }` and `{ "key" => "value" }`
- Prefer `do...end` for multi-line blocks, `{...}` for single-line
- Max line length: 120 chars (Rubocop default from omakase)

### Types & Data Structures
- Use `Struct.new(..., keyword_init: true)` for lightweight data carriers and test doubles
- Hash keys for query data use symbols (`:sql`, `:duration_ms`, `:source`)
- Thread-local state lives in `Thread.current[:rails_vitals_collector]` — never assume it exists outside request context

### Error Handling
- Wrap external calls (EXPLAIN, sandbox eval) in safe guards with rescue blocks
- Never raise in middleware; log and continue
- Nil-safe helpers in `ApplicationHelper` (e.g., `format_ms(value)` handles nil)

### Views & ERB
- Use shared partials from `app/views/rails_vitals/shared/` — never duplicate markup
- Avoid `class="badge-<%= color %>"` — use helper method: `class="<%= badge_class(color) %>"`
- Dynamic ERB values (colors from runtime data) must stay inline; static colors belong in `ApplicationHelper` constants
- No JS frameworks — vanilla JS only, tables for data, SVG for diagrams

### Architecture Notes
- **Zero JS dependencies** — no Chart.js, D3, Chartkick
- **PostgreSQL-specific** — EXPLAIN ANALYZE assumes Postgres; runs only in development/test
- **No migrations** — entirely in-memory ring buffer (default 200 requests)
- **Thread-local state** — every request gets its own Collector; no shared mutable state
