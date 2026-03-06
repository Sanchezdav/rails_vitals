# RailsVitals

RailsVitals is a Rails engine that records per-request database behavior and injects a lightweight in-page health panel for fast feedback during development.

## What it does

- Subscribes to `sql.active_record` and `process_action.action_controller` events.
- Collects SQL statements, query counts, DB time, controller/action, status, and request duration.
- Detects repeated query fingerprints as potential N+1 patterns.
- Computes a request health score (`0..100`) and classifies it as `Healthy`, `Acceptable`, `Warning`, or `Critical`.
- Stores a rolling window of request records in memory.
- Exposes an engine UI at `/rails_vitals` with dashboard and request details.
- Injects a panel into HTML responses (non-XHR, non-Turbo Frame, non-engine requests).

## Installation

Add this line to your application's Gemfile:

```ruby
gem "rails_vitals"
```

Then run:

```bash
bundle install
```

Or install directly:

```bash
gem install rails_vitals
```

## Usage

### 1. Mount the engine

Add to `config/routes.rb` in your host app:

```ruby
mount RailsVitals::Engine => "/rails_vitals"
```

### 2. (Optional) Configure behavior

Create `config/initializers/rails_vitals.rb`:

```ruby
RailsVitals.configure do |config|
	config.enabled = Rails.env.development?
	config.store_size = 200
	config.store_enabled = true

	config.query_warn_threshold = 10
	config.query_critical_threshold = 25
	config.db_time_warn_ms = 100
	config.db_time_critical_ms = 500

	config.auth = :none
	# config.auth = :basic
	# config.basic_auth_username = ENV.fetch("RAILS_VITALS_USER")
	# config.basic_auth_password = ENV.fetch("RAILS_VITALS_PASSWORD")

	# config.auth = ->(controller) { controller.current_user&.admin? }
end
```

## Scoring model

- `QueryScorer` contributes `40%` of final score.
- `NPlusOneScorer` contributes `60%` of final score.
- Query count and DB time each contribute up to 50 points inside `QueryScorer`.
- N+1 detection flags normalized SQL repeated at least 3 times.
- Labels are based on score ranges:
	- `90..100`: Healthy
	- `70..89`: Acceptable
	- `50..69`: Warning
	- `0..49`: Critical

## Engine UI

- `GET /rails_vitals` shows dashboard metrics and recent requests.
- `GET /rails_vitals/requests` lists recorded requests.
- `GET /rails_vitals/requests/:id` shows per-request details, including all queries and N+1 patterns.

## Contributing

1. Run tests from the gem root:

```bash
bundle exec rake test
```

2. If you modify engine behavior, validate against the dummy app in `test/dummy`.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
