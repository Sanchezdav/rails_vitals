# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture

**RailsVitals** is a mountable Rails Engine gem that instruments every request and surfaces performance diagnostics via an embedded admin UI at `/rails_vitals`.

### Request lifecycle

1. `Middleware::PanelInjector` (Rack) wraps each request
2. `Notifications::Subscriber` hooks `sql.active_record` and `process_action.action_controller` via `ActiveSupport::Notifications`
3. `Instrumentation::CallbackInstrumentation` times AR callbacks via `Module#prepend` on `ActiveRecord::Base`
4. `Collector` accumulates per-request data in `Thread.current[:rails_vitals_collector]` — no shared state between concurrent requests
5. On completion, a `RequestRecord` (immutable snapshot) is pushed into the `Store` (thread-safe in-memory ring buffer, default 200 requests — no DB writes, no migrations)

### Analysis & scoring

- `Analyzers::SqlTokenizer` — normalizes and tokenizes SQL into 14 token types for pattern matching (SELECT, SELECT *, COUNT(*), AGGREGATE, FROM, WHERE fk =, WHERE, IN (...), INNER JOIN, LEFT JOIN, ORDER BY, LIMIT, OFFSET, GROUP BY); each token has a risk level (healthy/neutral/warning/danger)
- `Analyzers::NPlusOneAggregator` — detects repeated query patterns across requests; normalized SQL fingerprint must appear ≥2 times per request to flag N+1
- `Scorers::CompositeScorer` — weighted combination: `(QueryScore × 40%) + (N+1Score × 60%)`, returns 0–100
  - QueryScore (40%): linear penalty between `query_warn_threshold` (10, default) and `query_critical_threshold` (25, default)
  - N+1Score (60%): 100 minus 25 per detected pattern, floored at 0 (so 1 pattern = 75, 2 = 50, 3 = 25, 4+ = 0)
- `Analyzers::ExplainAnalyzer` — PostgreSQL-specific; runs `EXPLAIN (FORMAT JSON, ANALYZE)` on SELECT queries, parses execution plan, detects warnings (sequential scans, sorts without index, large nested loops), and generates actionable fix suggestions with migration hints
- `Analyzers::AssociationMapper` — uses `ActiveRecord::Base.reflect_on_all_associations`; generates SVG layout with nodes (models) and edges (associations), colors by N+1 status, annotates edges with FK names and index status
- `Playground::Sandbox` — safe, read-only ActiveRecord expression evaluator; blocks INSERT/UPDATE/DELETE/DROP, enforces 100-record limit and 2s timeout, detects N+1 patterns within sandbox runs, applies same scoring logic as production

### Admin UI controllers (`app/controllers/rails_vitals/`)

| Controller | Purpose |
|---|---|
| `DashboardController` | Health score overview |
| `RequestsController` | Request history and per-request detail |
| `HeatmapController` | Endpoint rankings |
| `ModelsController` | Per-model query breakdown |
| `NPlusOnesController` | N+1 patterns and fix suggestions |
| `AssociationsController` | Association map SVG |
| `PlaygroundsController` | Eager-loading sandbox |
| `ExplainsController` | EXPLAIN ANALYZE visualizer |

### Key design notes

- **Zero JS dependencies** — tables for data, SVG for diagrams, vanilla JS (no Chart.js, D3, Chartkick)
- **PostgreSQL-specific** — EXPLAIN ANALYZE and some SQL filters assume Postgres; runs only in development/test
- **No migrations** — entirely in-memory; safe to add to any app without DB changes
- **Thread-local state** — every request gets its own Collector; no shared mutable state between concurrent requests
- **Ring buffer storage** — requests are stored in a fixed-size in-memory buffer (default 200); oldest requests are dropped as new ones arrive
- **Intended for development only** — production use requires explicit opt-in via `config.enabled` and is disabled by default

---

## Adding Features to RailsVitals

### Adding a new analyzer

1. Create a class in `lib/rails_vitals/analyzers/` (e.g., `lib/rails_vitals/analyzers/custom_analyzer.rb`)
2. Add a static `analyze` or entry method that accepts request data and returns a result
3. Require it in `lib/rails_vitals.rb` before the Engine is loaded
4. Call it from the appropriate controller or helper (e.g., in `RequestsController#show`)
5. Test via stub: `with_stub(Analyzers::CustomAnalyzer, :analyze, stub_result) { ... }`

### Adding a new admin UI page

1. Create a controller in `app/controllers/rails_vitals/` (inherit from `ApplicationController`)
2. Add route(s) in `config/routes.rb` (scoped under the engine's routing namespace)
3. Create views in `app/views/rails_vitals/your_controller/`
4. Use shared partials from `app/views/rails_vitals/shared/` where applicable (see below)
5. Add nav link in `app/views/layouts/rails_vitals/application.html.erb`
6. Test the controller with integration tests; use stub Store/Analyzer calls

### Shared view partials

Reusable UI components live in `app/views/rails_vitals/shared/`. Always prefer these over duplicating markup.

| Partial | Locals | Description |
|---|---|---|
| `_page_header` | `title:`, optional `subtitle:`, `back_path:`, `back_label:` | Standard page heading with optional subtitle and back link |
| `_empty_state` | `message:` | Full-width "no data" card |
| `_score_badge` | `color:`, `score:`, optional `label:` | Colored score badge pill |
| `_n1_indicator` | `patterns:`, optional `suffix:`, `none_label:` | N+1 count badge or "None" span |

**Usage example:**
```erb
<%= render "rails_vitals/shared/page_header",
           title: "My Page",
           subtitle: "#{@total} items",
           back_path: rails_vitals.root_path,
           back_label: "← Dashboard" %>

<%= render "rails_vitals/shared/score_badge", color: r.color, score: r.score %>

<%= render "rails_vitals/shared/n1_indicator",
           patterns: r.n_plus_one_patterns,
           suffix: "detected",
           none_label: "None detected" %>

<%= render "rails_vitals/shared/empty_state", message: "No data yet." %>
```

### View helpers (`ApplicationHelper`)

All helper methods and color constants live in `app/helpers/rails_vitals/application_helper.rb`.

| Helper | Returns | Use for |
|---|---|---|
| `badge_class(color)` | `"badge badge-healthy"` etc. | Full class string for score badge `<span>` |
| `score_color(color)` | hex string | Score number text color |
| `score_label_to_color(score)` | `"healthy"` / `"acceptable"` / `"warning"` / `"critical"` | CSS class suffix for a numeric score |
| `risk_color(risk)` | hex string | DNA token risk color (`:healthy`, `:warning`, etc.) |
| `callback_color(kind)` | hex string | Callback badge background |
| `query_heat_color(count)` | hex string | Query count heat color |
| `time_heat_color(ms)` | hex string | DB time heat color |
| `n1_heat_color(pct)` | hex string | N+1 frequency heat color |
| `format_ms(value)` | `"12.3ms"` | Unified millisecond formatting; nil-safe |
| `percentage(count, total)` | `42.5` | Safe percentage (returns 0 when total is zero) |

Color constants (`COLOR_GREEN`, `COLOR_RED`, etc.) are defined at the top of the module. Use these in helpers instead of hardcoding hex values. The module-level `ApplicationHelper.score_color_for(color)` method allows plain Ruby classes (e.g. `PanelRenderer`) to resolve score colors without a helper instance.

1. Create a class in `lib/rails_vitals/scorers/` that inherits from `BaseScorer`
2. Implement `score(request_record)` → returns 0–100 Integer
3. Add to `CompositeScorer` if it should affect the overall health score
4. Test in isolation with constructed `RequestRecord` doubles

### Common gotchas

- **Collector state**: Thread-local at `Thread.current[:rails_vitals_collector]`; don't assume it exists outside request context
- **Request filtering**: RailsVitals skips instrumentation for its own routes (detection via `SCRIPT_NAME`)
- **SQL normalization**: Bind values are replaced with `?` for fingerprinting; exact value matching won't work
- **Test isolation**: Always wrap stubs with `with_stub` or use `Struct.new` doubles; don't modify global state
- **EXPLAIN availability**: Only works on `SELECT` queries in development/test; wrapped in safe guards in `ExplainAnalyzer`
- **Inline styles**: Dynamic ERB values (colors from runtime data like `token[:color]`) must stay inline. All static colors belong in `ApplicationHelper` constants and helper methods. Never define `risk_colors` or similar hashes in views.
- **Class attribute interpolation**: Avoid `class="badge-<%= color %>"`. Use a helper method (`badge_class(color)`) so the entire class string is a single ERB expression: `class="<%= badge_class(color) %>"`.

## Commands

```bash
# Run all tests
bin/rails db:test:prepare test

# Run a single test file
bin/rails test test/lib/rails_vitals/collector_test.rb

# Run a single test by name
bin/rails test test/lib/rails_vitals/collector_test.rb -n test_add_query

# Lint
bin/rubocop
bin/rubocop -f github   # CI format
```

## Testing Patterns

RailsVitals uses Minitest without mock extensions, so tests rely on manual stubs via the `with_stub` helper:

```ruby
# Stub a class method or instance method
with_stub(MyClass, :method_name, return_value_or_lambda) do
  # test code here
end

# Example: stub analytics
result = Analyzer.send(:detect_n1, queries)  # private method
with_stub(Analyzers::N1Aggregator, :aggregate, []) do
  get "/rails_vitals/n_plus_ones"
  assert_response :success
end
```

**Common patterns:**
- Use `with_stub` for dependencies (Store, Analyzers, etc.)
- Create Struct doubles for complex objects (e.g., `RecordDouble = Struct.new(:id, :queries)`)
- Always call private methods with `.send(:method_name, args)` in tests
- Keep stubs simple — only override what the test needs
