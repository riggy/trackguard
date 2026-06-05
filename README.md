# Trackguard

A Rails Engine gem for visitor analytics and page view tracking. Designed to be mounted into a host Rails 8.1+ application.

## Adapters

Trackguard ships with two adapters:

- **Local** (default) — stores visitors, page views, and blocked requests in your app's database. Includes an admin UI, background jobs for bot detection, and database-driven block/allow rules. Requires running migrations.
- **Hub** — sends tracking data to a hosted Trackguard project. Rules (blocked agents, blocked paths, whitelisted IPs) are managed in the hub dashboard and fetched remotely. No local database tables or background jobs required.

## Requirements

- Rails 8.1+
- Active Job (local adapter only)
- SQLite, PostgreSQL, or MySQL (local adapter only)

## Installation

### Hub adapter

**1. Add to your `Gemfile`:**

```ruby
gem "trackguard"
```

**2. Create an initializer:**

```ruby
# config/initializers/trackguard.rb
Trackguard.configure do |config|
  config.adapter        = :hub
  config.hub_api_key    = ENV["TRACKGUARD_API_KEY"]
  config.hub_secret_key = ENV["TRACKGUARD_SECRET_KEY"]
end
```

**3. Include the tracking concern:**

```ruby
class ApplicationController < ActionController::Base
  include Trackguard::PageTracker

  track_page_views
end
```

**4. Add the header helper to your layout:**

```erb
<%# app/views/layouts/application.html.erb %>
<head>
  <%= trackguard_header_tags %>
</head>
```

In production this renders a `<script>` tag that loads the hub's client-side tracker. No engine mount, no migrations, no background jobs needed.

> **Note:** Public signup at [trackguard.dev](https://trackguard.dev) is not yet open. Contact us if you'd like early access.

---

### Local adapter

**1. Add to your `Gemfile`:**

```ruby
gem "trackguard"
```

**2. Mount the engine in `config/routes.rb`:**

```ruby
mount Trackguard::Engine => "/"
```

This exposes `POST /page_views` (client-side tracking endpoint) and the `/admin` UI.

**3. Run the install generator, migrate, and seed:**

```bash
rails generate trackguard:install
rails db:migrate
rails trackguard:seed_blocked_user_agents
rails trackguard:seed_blocked_paths
```

The generator writes seven migrations: five that create tables and two that add columns.
If any of those migration files already exist in your app (e.g. from a previous install),
pass `--skip` to silently skip the existing ones:

```bash
rails generate trackguard:install --skip
```

The seed tasks populate `trackguard_blocked_user_agents` with known bot/scanner patterns and
`trackguard_blocked_paths` with common path probes (WordPress, PHP shells, config leaks, etc.).

**4. Include the tracking concern:**

```ruby
class ApplicationController < ActionController::Base
  include Trackguard::PageTracker

  track_page_views
end
```

**5. Add the header helper to your layout:**

```erb
<%# app/views/layouts/application.html.erb %>
<head>
  <%= trackguard_header_tags %>
</head>
```

**6. Add an initializer** (minimum: protect the admin UI):

```ruby
# config/initializers/trackguard.rb
Trackguard.configure do |config|
  config.authenticate_admin_with = -> { redirect_to root_path unless current_user&.admin? }
end
```

See [Configuration](#configuration) for the full option list.

## Upgrading

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

### Hub adapter

```ruby
Trackguard.configure do |config|
  config.adapter        = :hub
  config.hub_api_key    = ENV["TRACKGUARD_API_KEY"]   # required
  config.hub_secret_key = ENV["TRACKGUARD_SECRET_KEY"] # required

  # Optional: how long to cache rules fetched from the hub (default: 5 minutes)
  config.hub_rules_ttl = 5.minutes
end
```

Credentials are validated at boot — the app will raise `Trackguard::ConfigurationError` if any are missing.

### Local adapter

```ruby
Trackguard.configure do |config|
  # Required: protect the admin UI. Called as a before_action.
  config.authenticate_admin_with = -> { redirect_to root_path unless current_user&.admin? }

  # Optional: link shown in admin header
  config.back_label = "Back to Dashboard"

  # Optional: bearer token for programmatic access to the admin endpoints.
  # When set, requests that include `Authorization: Bearer <token>` bypass the
  # authenticate_admin_with check, allowing external tools to query analytics,
  # visitors, blocked agents, blocked paths, and whitelisted IPs without a browser session.
  config.local_api_token = ENV["TRACKGUARD_API_TOKEN"]

  # Optional: rack-attack throttle (default: 100 req / 60 sec per IP)
  config.throttle_limit  = 100
  config.throttle_period = 60
end
```

### Admin authentication examples

`authenticate_admin_with` is called as a `before_action` inside the admin controllers.
The lambda runs in the context of the controller, so any helper available in a
`before_action` works here.

**Devise** — redirect unless the current user has an `admin` flag:

```ruby
config.authenticate_admin_with = -> {
  redirect_to root_path unless current_user&.admin?
}
```

**HTTP Basic Auth** — no user model required:

```ruby
config.authenticate_admin_with = -> {
  authenticate_or_request_with_http_basic("Trackguard Admin") do |name, password|
    name == ENV["ADMIN_NAME"] && password == ENV["ADMIN_PASSWORD"]
  end
}
```

**Warden / Devise with a specific role** — halt if not signed in or not an admin:

```ruby
config.authenticate_admin_with = -> {
  authenticate_admin_user! # your Devise scope
}
```

## Usage

### Header tags

Add `trackguard_header_tags` to your layout `<head>`:

```erb
<%# app/views/layouts/application.html.erb %>
<head>
  <%= trackguard_header_tags %>
</head>
```

With the **hub adapter** this renders a `<script>` tag (production only) that loads the hub's client-side tracker. With the **local adapter** it renders a `<meta>` tag with the tracking URL and trace ID used by the Stimulus controller.

### Server-side tracking

Include the concern in your `ApplicationController` and call `track_page_views`:

```ruby
class ApplicationController < ActionController::Base
  include Trackguard::PageTracker

  track_page_views
end
```

`track_page_views` accepts the same options as `after_action` (e.g. `only:`, `except:`).
The concern also registers a `before_action :set_trace_id` automatically, so `@trace_id`
is available in views and carried through to the client-side tracker.

### Client-side tracking (local adapter only)

Attach the Stimulus controller to the element you want tracked (typically `<body>`):

```erb
<body data-controller="page-tracker">
  <%= yield %>
</body>
```

The Stimulus controller listens for `turbo:load` events and hash changes, then POSTs to
`/page_views` automatically.

### Source attribution

Traffic source is resolved in priority order: `ref` URL param → `utm_source` URL param → referrer.

### Admin UI (local adapter only)

The admin interface is accessible at `/admin`. It covers traffic overviews, analytics, visit
logs, and bot/path pattern management. Authentication is required — configure it via
`authenticate_admin_with` in the initializer (see above).

## Architecture

### Data flow

**Hub adapter:**
1. **Frontend** — The hub's `track.js` sends page views directly to the hub.
2. **Server-side** — `PageTracker` concern sends page view data to the hub via `SubmitPageViewJob`.
3. **Rack-attack** — Rules (blocked agents, paths, flagged IPs) are fetched from the hub and cached locally for `hub_rules_ttl`.

**Local adapter:**
1. **Frontend** — The Stimulus controller POSTs to `/page_views` with path, trace ID, session ID, and referral source.
2. **Controller** — `PageViewsController#create` delegates to `PageViewRecorder`, which filters bots and admin paths, then enqueues `TrackPageViewJob`.
3. **Background job** — `TrackPageViewJob` finds-or-creates a `Visitor` by IP, then creates a `PageView` record.
4. **Rack-attack** — Requests from flagged visitors or known scanners are blocked at middleware level; `TrackBlockedRequestJob` records them as `BlockedRequest` visits.

### Models (local adapter only)

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
| `lib/trackguard/adapters/local.rb` | Local adapter: DB models + background jobs |
| `lib/trackguard/adapters/hub.rb` | Hub adapter: remote rules cache + HTTP job dispatch |
| `app/jobs/trackguard/hub/submit_page_view_job.rb` | Sends page view to hub API |
| `app/jobs/trackguard/hub/submit_blocked_request_job.rb` | Sends blocked request to hub API |
| `app/services/trackguard/page_view_recorder.rb` | Bot filtering, admin path exclusion, job dispatch |
| `app/jobs/trackguard/track_page_view_job.rb` | Async visitor/page-view upsert (local adapter) |
| `app/jobs/trackguard/track_blocked_request_job.rb` | Async blocked request logging (local adapter) |
| `app/jobs/trackguard/detect_suspicious_visitors_job.rb` | Nightly bot/suspicious visitor detection (local adapter) |
| `app/controllers/trackguard/page_views_controller.rb` | `POST /page_views` endpoint (local adapter) |
| `app/controllers/concerns/trackguard/page_tracker.rb` | Server-side tracking mixin |
| `app/helpers/trackguard/application_helper.rb` | `trackguard_header_tags` helper |
| `app/assets/javascripts/controllers/page_tracker_controller.js` | Stimulus tracker (local adapter) |

### Namespacing

All classes live under `Trackguard::`. The engine is non-isolated so routes stay unprefixed
(`/page_views`, `/admin`). Models declare `self.table_name` explicitly.

## License

MIT