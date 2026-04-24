# Trackguard

A Rails Engine gem for visitor analytics and page view tracking. Designed to be mounted into a host Rails 8.1+ application.

## Features

- Client-side page view tracking via a Stimulus controller (Turbo/SPA-aware)
- Server-side tracking via a concern mixin
- Bot filtering (Googlebot, Bingbot, social bots, curl, wget, and more)
- Visitor deduplication by IP with first/last seen timestamps
- SPA deduplication via `trace_id`
- Traffic source attribution (`ref` param → `utm_source` param → referrer)
- Visitor flagging for admin review
- Admin UI for reviewing visitors and page views

## Requirements

- Rails 8.1+
- Active Job (for background processing)
- SQLite, PostgreSQL, or MySQL

## Installation

Add to your `Gemfile`:

```ruby
gem "trackguard"
```

Mount the engine and copy migrations:

```ruby
# config/routes.rb
mount Trackguard::Engine => "/"
```

```bash
rails trackguard:install:migrations
rails db:migrate
```

## Usage

### Client-side tracking

Add the Stimulus controller to your layout. It listens for `turbo:load` events and hash changes, then POSTs to `/page_views` automatically.

### Server-side tracking

Include the concern in your `ApplicationController`:

```ruby
include Trackguard::PageTracker
```

Call `set_trace_id` in a `before_action` if you want server-rendered pages to share a trace ID with the client-side tracker.

### Source attribution

Traffic source is resolved in priority order: `ref` URL param → `utm_source` URL param → referrer meta tag.

## Architecture

### Data flow

1. **Frontend** — The Stimulus controller POSTs to `/page_views` with path, trace ID, session ID, and referral source.
2. **Controller** — `PageViewsController#create` delegates to `PageViewRecorder`, which filters bots and admin paths, then enqueues `TrackPageViewJob`.
3. **Background job** — `TrackPageViewJob` finds-or-creates a `Visitor` by IP, then creates a `PageView` record.

### Models

- **`Visitor`** — Unique visitor identified by IP address. Has `first_seen_at`, `last_seen_at`, and optional flagging fields (`flagged_at`, `flag_reason`, `flagged_by`).
- **`PageView`** — Individual page visit with `path`, `referer`, `session_id`, `trace_id`, `source`, associated to a `Visitor`.

### Key files

| File | Purpose |
|------|---------|
| `lib/trackguard/engine.rb` | Rails Engine: registers migrations, configures importmap |
| `app/services/trackguard/page_view_recorder.rb` | Bot filtering, admin path exclusion, job dispatch |
| `app/jobs/trackguard/track_page_view_job.rb` | Async visitor/page-view upsert logic |
| `app/controllers/trackguard/page_views_controller.rb` | API endpoint for frontend tracker |

### Namespacing

All classes live under `Trackguard::`. The engine is non-isolated so routes stay unprefixed (`/page_views`). Models declare `self.table_name` explicitly to avoid migration churn.

## License

MIT