# Changelog

All notable changes to RailsVitals will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.4.1] — 2026-04-05

### Changed

- Extracted reusable view partials into `app/views/rails_vitals/shared/`: `_page_header`, `_empty_state`, `_score_badge`, `_n1_indicator` — all views now use these instead of duplicating markup.
- Added `badge_class(color)`, `format_ms(value)`, and `percentage(count, total)` helper methods to `ApplicationHelper`; views no longer compute formatting or percentages inline.
- Extracted `ApplicationHelper.score_color_for` as a module-level method so plain Ruby classes (e.g. `PanelRenderer`) can resolve score colors without a helper instance.
- Moved plan node, score display, and EXPLAIN interpretation CSS from inline `<style>` blocks into `application.css`.
- Replaced inline JS string interpolation with `.to_json` calls in views to prevent XSS.
- Normalized hash alignment style across the codebase to comply with RuboCop defaults.

---

## [0.4.0] — 2026-03-23

### Added

#### 🧪 N+1 Fix Playground
- Added `PlaygroundsController` and `Playground::Sandbox` for running read-only ActiveRecord expressions against real app data inside RailsVitals.
- Added Playground UI at `GET /rails_vitals/playgrounds` with:
  - Query input for ActiveRecord expressions
  - Optional association-access simulation to surface N+1 behavior
  - Before/after comparison of score, query count, N+1 count, and duration
  - Query DNA breakdown for SQL fired by sandbox runs
- Added `POST /rails_vitals/playgrounds` to evaluate sandbox runs with a 100-record cap and 2s timeout.
- Added deep-link from N+1 Patterns to open a suggested fix directly in the Playground.

#### ✅ Test Coverage
- Added controller tests for EXPLAIN and Playground flows.
- Added analyzer tests for `ExplainAnalyzer`.
- Added sandbox tests for Playground guardrails, query normalization, and scoring.

### Changed

- Navigation now includes a dedicated Playground entry in the RailsVitals admin UI.
- SQL notification filtering explicitly skips internal queries such as `EXPLAIN`, schema lookups, and transaction control statements.

### Fixed

- Normalized badge rendering in Request Detail to avoid malformed class output.

---

## [0.3.0] — 2026-03-18

### Added

#### 🔬 EXPLAIN Visualizer
- Added `ExplainAnalyzer` to run `EXPLAIN (FORMAT JSON, ANALYZE true)` for captured `SELECT` queries and produce:
  - Execution-plan tree nodes with operation metadata and education copy
  - Warning detection (sequential scan, sort without index, large nested loop)
  - Actionable fix suggestions (including migration/command hints where applicable)
  - Summary interpretation, total cost, actual time, and rows examined
- Added `ExplainsController#show` and EXPLAIN views:
  - `app/views/rails_vitals/explains/show.html.erb`
  - `app/views/rails_vitals/explains/_plan_node.html.erb`
- Added request-scoped EXPLAIN route:
  - `GET /rails_vitals/requests/:request_id/explain/:query_index`
- Added EXPLAIN entry point from Request Detail on `SELECT` queries.

#### 🧩 UI Structure Improvements
- Added shared JavaScript asset `app/assets/javascripts/rails_vitals/application.js`.
- Moved inline page JS into shared functions (`toggleDna`, `toggleCard`, `toggleExplanation`, `selectNode`, `closePanel`).
- Added stylesheet utility classes/components in `app/assets/stylesheets/rails_vitals/application.css`.
- Included shared JS in the engine layout.

#### 🤝 Community Docs
- Added `CONTRIBUTING.md`.
- Added `CODE_OF_CONDUCT.md`.

### Changed

- Query capture now persists bind values for each query (`Collector#add_query` + notifications subscriber) so EXPLAIN can analyze stored request SQL without requiring SQL in the URL.
- README updated with EXPLAIN feature documentation and the new request-scoped route format.
- Refactored multiple RailsVitals views to use shared CSS utilities and centralized JS behavior.

### Fixed

- Removed debug logging from `NPlusOnesController#index`.

---

## [0.2.1] — 2026-03-13

### Added

#### Support for Rails 7+
- Modify the gemspec to support Rails 7+ apps

---

## [0.2.0] — 2026-03-13

### Added

#### 🧬 Query DNA — Visual SQL Fingerprinting
- SQL tokenizer (`SqlTokenizer`) that decomposes any query into labeled, color-coded tokens
- 14 recognized token types: `SELECT *`, `SELECT`, `COUNT(*)`, `AGGREGATE`, `FROM`, `WHERE fk =`, `WHERE`, `IN (...)`, `INNER JOIN`, `LEFT JOIN`, `ORDER BY`, `LIMIT`, `OFFSET`, `GROUP BY`
- Risk classification per token: `:healthy`, `:neutral`, `:warning`, `:danger`
- Complexity scoring (1–10) based on structural token weights
- Repetition bar showing how many times a query pattern fired in the same request
- Full education card per token — expandable inline on click, explaining what the token means, why it matters, and how to fix it
- Integrated into Request Detail page — click any query row to expand its DNA

#### 🗺️ Association Map — Visual AR Diagram
- SVG-based model graph generated from `reflect_on_all_associations` — zero data queries
- Auto-layout algorithm positions models by association depth (root models at top, leaf models at bottom)
- Nodes color-coded: green (healthy), red (N+1 detected), gray (not queried)
- Edges show association macro type (`has_many` / `belongs_to`), foreign key name, and index status
- Dashed edges signal missing indexes on foreign keys
- N+1 badge on affected nodes
- Click any node to open slide-in detail panel with query count, avg query time, N+1 count, all associations with index status, fix suggestions, and links to N+1 Patterns and filtered Request History
- New route: `GET /rails_vitals/associations`

---

## [0.1.0] — 2026-03-09

### Added

#### Core Infrastructure
- Mountable Rails Engine (`RailsVitals::Engine`) with isolated namespace
- Thread-local `Collector` for per-request instrumentation state
- Thread-safe in-memory ring buffer `Store` with configurable size (default: 200 requests)
- Immutable `RequestRecord` snapshot capturing all request data at completion
- `Configuration` object with sensible defaults and full customization via `RailsVitals.configure`

#### Instrumentation
- `ActiveSupport::Notifications` subscriber for `sql.active_record` — captures all SQL with timing
- `ActiveSupport::Notifications` subscriber for `process_action.action_controller` — captures endpoint, duration, status
- Module prepend on `ActiveRecord::Base#run_callbacks` for callback timing — no TracePoint, no monkey-patching
- Tracks: `before_validation`, `after_validation`, `before_save`, `after_save`, `before_create`, `after_create`, `before_update`, `after_update`, `before_destroy`, `after_destroy`, `after_commit`, `after_rollback`
- PostgreSQL internal query filter — excludes `pg_class`, `pg_attribute`, `pg_type`, `pg_namespace`, `information_schema`, `SHOW search_path`, `SHOW max_identifier_length`, and schema introspection queries from instrumentation

#### Scoring
- `BaseScorer` — abstract base class
- `QueryScorer` (40% weight) — linear penalty between `query_warn_threshold` and `query_critical_threshold`
- `NPlusOneScorer` (60% weight) — proportional penalty: 25 points per detected pattern, floor at 0
- `CompositeScorer` — weighted composite of QueryScorer and NPlusOneScorer
- Score labels: Healthy (90–100), Acceptable (70–89), Warning (50–69), Critical (0–49)

#### N+1 Detection
- SQL normalization via regex — replaces bind values with `?` to fingerprint query patterns
- Per-request N+1 detection: repeated normalized SQL patterns flagged with occurrence count
- `NPlusOneAggregator` — cross-request aggregation of N+1 patterns across all stored records
- Fix suggestion generation via `reflect_on_all_associations`:
  - Extracts table name from `FROM` clause
  - Extracts foreign key from `WHERE fk = ?` pattern
  - Infers owner model from foreign key name
  - Reflects on owner model's associations to find the matching one
  - Generates concrete `Model.includes(:association)` suggestion

#### Panel Injector
- Rack middleware `PanelInjector` — injects diagnostic panel into every HTML response
- `PanelRenderer` — renders collapsed/expanded panel with score, query count, DB time, N+1 count, callback time
- Panel is collapsed by default, expandable on click
- Auto-excluded from RailsVitals admin routes to prevent self-instrumentation

#### Admin UI
- Dark theme admin interface mounted at configurable path (default: `/rails_vitals`)
- **Dashboard** — score distribution table, health trend, query volume, summary stats
- **Request History** (`/rails_vitals/requests`) — paginated list with score, query count, DB time, N+1 count, duration; filterable by endpoint and model
- **Request Detail** (`/rails_vitals/requests/:id`) — full query list, callback map grouped by model and type, N+1 patterns with fix suggestions
- **Endpoint Heatmap** (`/rails_vitals/heatmap`) — endpoints ranked by worst average score; columns: avg score, hits, avg queries, avg DB time, avg callback time, N+1 frequency
- **Per-Model Breakdown** (`/rails_vitals/models`) — query-based aggregation by table; total queries, total DB time, avg query time, contributing endpoints
- **N+1 Patterns** (`/rails_vitals/n_plus_ones`) — cross-request pattern list with occurrence count, affected endpoints, fix suggestion
- **Impact Simulator** (`/rails_vitals/n_plus_ones/:id`) — per-pattern detail with affected requests, estimated query savings, fix suggestion

#### Authentication
- Three auth modes: `:none` (default), `:basic` (HTTP Basic Auth), `:lambda` (custom proc)
- Configurable via `config.auth`, `config.basic_auth_username`, `config.basic_auth_password`

#### Self-Instrumentation Guard
- Engine requests (`/rails_vitals/*`) are excluded from instrumentation via `SCRIPT_NAME` detection
- Prevents RailsVitals from instrumenting its own admin UI requests
