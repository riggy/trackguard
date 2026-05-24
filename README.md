# Trackguard

A Rails Engine gem for visitor analytics and page view tracking. Designed to be mounted into a host Rails 8.1+ application.

## Features

- Client-side page view tracking via a Stimulus controller (Turbo/SPA-aware)
- Server-side tracking via a concern mixin
- Bot filtering via a database-driven blocked user agent list
- Path probe blocking via a database-driven blocked path list
- Automatic rate limiting and request blocking via `rack-attack`
- Suspicious visitor detection (nightly background job)
- Visitor deduplication by IP with first/last seen timestamps, optional name detection
- SPA deduplication via `trace_id`
- Traffic source attribution (`ref` param → `utm_source` param → referrer)
- Visitor flagging and IP whitelisting for admin review
- Admin UI for reviewing visitors, page views, and blocked requests

## Requirements

- Rails 8.1+
- Active Job (for background processing)
- SQLite, PostgreSQL, or MySQL

## Installation

Add to your `Gemfile`:

```ruby
gem "trackguard"
```

Mount the engine in `config/routes.rb`:

```ruby
mount Trackguard::Engine => "/"
```

Run the install generator, migrate, and seed:

```bash
rails generate trackguard:install
rails db:migrate
rails trackguard:seed_blocked_user_agents
rails trackguard:seed_blocked_paths
```

The generator creates five individual migrations — one per table. The seed tasks populate
`trackguard_blocked_user_agents` with known bot/scanner patterns and `trackguard_blocked_paths`
with common path probes (WordPress, PHP shells, config leaks, etc.).

## Upgrading

### From a version with individual per-table migrations

Re-run the install generator. It skips any migrations that already exist and only writes new ones:

```bash
rails generate trackguard:install
rails db:migrate
rails trackguard:seed_blocked_paths
```

### From v0.26.0 or earlier (monolithic `create_trackguard_tables` migration)

Versions up to and including 0.26.0 shipped a single migration that created all tables at once. Run the cleanup
task first — it replaces that migration with the individual per-table ones and updates
`schema_migrations` and `db/schema.rb` to match, without touching the actual tables:

```bash
rails trackguard:cleanup_monolithic_migration
rails generate trackguard:install
rails db:migrate
rails trackguard:seed_blocked_paths
```

The cleanup task will show you exactly what it intends to change and ask for confirmation
before proceeding.

## Configuration

Create an initializer (e.g. `config/initializers/trackguard.rb`):

```ruby
Trackguard.configure do |config|
  # Required: protect the admin UI. Called as a before_action.
  config.authenticate_admin_with = -> { redirect_to root_path unless current_user&.admin? }

  # Optional: link shown in admin header
  config.back_url   = "/dashboard"
  config.back_label = "Back to Dashboard"

  # Optional: bearer token for API requests to /page_views
  config.local_api_token = ENV["TRACKGUARD_API_TOKEN"]

  # Optional: rack-attack throttle (default: 100 req / 60 sec per IP)
  config.throttle_limit  = 100
  config.throttle_period = 60
end
```

## Usage

### Client-side tracking

Add `trackguard_meta_tags` to your layout `<head>` and attach the Stimulus controller to the
element you want tracked (typically `<body>`):

```erb
<%# app/views/layouts/application.html.erb %>
<head>
  <%= trackguard_meta_tags %>
</head>
<body data-controller="page-tracker">
  <%= yield %>
</body>
```

The Stimulus controller listens for `turbo:load` events and hash changes, then POSTs to
`/page_views` automatically. It reads the tracking URL and trace ID from the meta tags.

### Server-side tracking

Include the concern in your `ApplicationController` and call `track_page_views`:

```ruby
class ApplicationController < ActionController::Base
  include Trackguard::PageTracker

  track_page_views
end
```

`track_page_views` accepts the same options as `after_action` (e.g. `only:`, `except:`).
The concern also registers a `before_action :set_trace_id` automatically, so the meta tag
rendered by `trackguard_meta_tags` will carry the same trace ID as the server-side record.

### Source attribution

Traffic source is resolved in priority order: `ref` URL param → `utm_source` URL param → referrer.

### Admin UI

The admin interface is accessible at `/admin`. It covers traffic overviews, analytics, visit
logs, and bot/path pattern management. Authentication is required — configure it via
`authenticate_admin_with` in the initializer (see above).

## Architecture

### Data flow

1. **Frontend** — The Stimulus controller POSTs to `/page_views` with path, trace ID, session ID, and referral source.
2. **Controller** — `PageViewsController#create` delegates to `PageViewRecorder`, which filters bots and admin paths, then enqueues `TrackPageViewJob`.
3. **Background job** — `TrackPageViewJob` finds-or-creates a `Visitor` by IP, then creates a `PageView` record.
4. **Rack-attack** — Requests from flagged visitors or known scanners are blocked at middleware level; `TrackBlockedRequestJob` records them as `BlockedRequest` visits.

### Models

- **`Visitor`** — Unique visitor identified by IP. Has `first_seen_at`, `last_seen_at`, `name`, and flagging fields (`flagged_at`, `flag_reason`, `flagged_by`).
- **`Visit`** — STI base class stored in `trackguard_visits`. Subclasses:
  - **`PageView`** — A normal page visit with `path`, `referer`, `session_id`, `trace_id`, `source`, `http_method`.
  - **`BlockedRequest`** — A request blocked by rack-attack, with `block_reason`.
- **`BlockedUserAgent`** — Database-driven patterns matched against the `User-Agent` header to identify bots and scanners.
- **`BlockedPath`** — Database-driven patterns matched against the request path to detect probes (e.g. `/wp-admin`, `/.env`). Seeded via `trackguard:seed_blocked_paths`.
- **`WhitelistedIp`** — IPs exempt from blocking, with an `expires_at` timestamp.

### Key files

| File | Purpose |
|------|---------|
| `lib/trackguard.rb` | Module-level configuration |
| `lib/trackguard/engine.rb` | Rails Engine: importmap, asset precompile, rack-attack setup |
| `lib/trackguard/rack_attack.rb` | Throttle, safelist, blocklist rules |
| `lib/trackguard/adapters/local.rb` | Default adapter: DB models + background jobs |
| `app/services/trackguard/page_view_recorder.rb` | Bot filtering, admin path exclusion, job dispatch |
| `app/jobs/trackguard/track_page_view_job.rb` | Async visitor/page-view upsert |
| `app/jobs/trackguard/track_blocked_request_job.rb` | Async blocked request logging |
| `app/jobs/trackguard/detect_suspicious_visitors_job.rb` | Nightly bot/suspicious visitor detection |
| `app/controllers/trackguard/page_views_controller.rb` | `POST /page_views` endpoint |
| `app/controllers/concerns/trackguard/page_tracker.rb` | Server-side tracking mixin |
| `app/controllers/trackguard/admin/base_controller.rb` | Admin auth and layout |
| `app/helpers/trackguard/application_helper.rb` | `trackguard_meta_tags` helper |
| `app/assets/javascripts/controllers/page_tracker_controller.js` | Stimulus tracker |

### Namespacing

All classes live under `Trackguard::`. The engine is non-isolated so routes stay unprefixed
(`/page_views`, `/admin`). Models declare `self.table_name` explicitly.

## License

MIT