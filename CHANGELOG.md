# Changelog

All notable changes to Trackguard are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased] — 0.28.0

### Added
- `suspicious_state` column on `Visitor` (`normal` / `suspicious` / `blocked`) with migration template
  and install generator entry — **requires migration on upgrade**
- `Visitor#normal?`, `#suspicious?`, `#blocked?` predicate methods
- `PageView#js_layer?`, `#backend_layer?` predicate methods
- `tracking_layer` column on page views distinguishes client-side (`js`) from server-side (`backend`) tracking
- Dashboard visit row shows `js` / `srv` text badges (green / orange) for tracking layer
- Dashboard visit row shows yellow background and question-mark icon for suspicious visitors
- `TrackPageView` service object extracted from `TrackPageViewJob`
- Hub adapter (`Adapters::Hub`) for receiving rules from a central cloud service
- `trackguard_hub_js_tag` helper for injecting hub JS into host app layouts
- `hub_api_key` config option alongside the renamed `hub_secret_key`
- `HubHelper` extracted for hub-related view helpers
- Expanded `FLAGGED_BY` constant; detection job now records `"Recurring Job"` as flagger

### Changed
- Backend-only page views (no paired JS view) now set state to `suspicious` rather than immediately blocking;
  subsequent job runs escalate to `blocked` or recover to `normal` based on new view patterns
- Detection job continues analysing after marking a visitor suspicious — a single run can still
  block if another signal (UA, scoring, probe path) also fires
- `mark_blocked!` / `mark_suspicious!` / `mark_normal!` replace the old `flag!` method;
  `mark_suspicious!` and `mark_normal!` include guard clauses to prevent redundant updates
- Dashboard "Flag status" detail row replaced with "Status" showing the full three-state label

---

## [0.27.1] — 2026-05-19

### Changed
- Reworked `trackguard:cleanup_monolithic_migration` rake task to handle edge cases
  when the old monolithic migration has already been partially cleaned up

---

## [0.27.0] — 2026-05-19

### Changed
- Split the monolithic `create_trackguard_tables` migration into one file per table;
  the install generator is now idempotent and can be re-run safely
- Removed the separate upgrade generator — `trackguard:install` covers fresh installs
  and incremental upgrades alike
- Added `seed_blocked_paths` rake task with a default set of common probe patterns

---

## [0.26.0] — 2026-05-18

### Added
- `BlockedPath` model, admin API (`GET /admin/blocked_paths`), and seeding rake task
- Rack::Attack rule to block requests matching any `BlockedPath` pattern
- Probe-path detection in `DetectSuspiciousVisitorsJob`: visitors hitting a blocked path
  are immediately flagged

---

## [0.25.0] — 2026-05-18

### Changed
- Scoring: removed the `no_referer` signal; flag threshold lowered from 6 to 5 points
- Detection job extended with broader user-agent checks (bare `Mozilla/5.0`, quoted UA,
  duplicate `Mozilla/5.0`) and single-path / no-session / no-referrer shortcut rule

---

## [0.24.0] — 2026-05-17

### Changed
- Whitelisting an IP that has no existing visitor record now auto-creates the visitor row
  so the whitelist entry is always properly associated

---

## [0.23.0] — 2026-05-17

### Changed
- Tracking guards moved into `Adapters::Base`; `PageViewRecorder` service removed
- `back_url` config renamed to `admin_path` for clarity
- Adapter interface stabilised: storage, tracking, and detection are now three distinct
  extension points

---

## [0.22.0] — 2026-05-15

### Added
- Admin UI partials extracted for easier host-app overriding
- `Overridable` concern provides `nav_path` and `after_action_path` helpers that
  host apps can override without touching engine controllers

---

## [0.21.0] — 2026-05-13

### Changed
- Admin UI rethemed to a light colour scheme (replaces the previous dark/red theme)

---

## [0.20.0] — 2026-05-12

### Added
- `AnalyticsQuery` service object encapsulates dashboard aggregation logic
- `Overridable` concern replaces hardcoded model and path references in controllers

---

## [0.19.1] — 2026-05-10

### Fixed
- `create_trackguard_visitors` migration template now includes the `name` column,
  matching what the upgrade path was already applying

---

## [0.19.0] — 2026-05-07

### Changed
- Admin logo replaced with a PNG asset; admin UI rethemed to red

---

## [0.18.0] — 2026-05-06

### Added
- Adapter-based architecture: `Adapters::Default` ships with the gem; host apps can
  substitute their own storage, tracking, or detection adapters

---

## [0.17.0] — 2026-05-05

### Added
- Visitor name detection: `BlockedUserAgent` patterns are matched against the UA string
  when a visitor is flagged, and the matched pattern name is stored on `visitors.name`
- Admin UI displays the detected name in the visitor detail card

---

## [0.16.1] — 2026-05-05

### Fixed
- Generator correctly separates install (fresh) from upgrade (existing) migration sets

---

## [0.16.0] — 2026-05-05

### Added
- `BlockedRequest` model using STI on a `Visit` base class; blocked requests are now
  stored separately from page views with a `block_reason` column

---

## [0.15.2] — 2026-05-04

### Changed
- Applied RuboCop autocorrections across the codebase (no behavioural changes)

---

## [0.15.1] — 2026-05-04

### Changed
- Gem prepared for RubyGems release: gemspec metadata, licence, and description updated

---

## [0.15.0] — 2026-05-03

### Added
- Rack::Attack rules bundled into the engine; host apps no longer need to configure
  rules manually
- `Visitor.flagged?(ip)` and `WhitelistedIp.whitelisted?(ip)` cache lookups with a
  5-minute and 10-minute TTL respectively

---

## [0.14.0] — 2026-05-03

### Added
- `BlockedUserAgent` model and admin API (`GET/POST/DELETE /admin/blocked_user_agents`)
  for managing UA patterns that are always blocked

---

## [0.13.0] — 2026-04-30

### Changed
- `back_url` is now a static configurable string (defaults to `/admin`) rather than
  a dynamic helper, simplifying host-app integration

---

## [0.12.0] — 2026-04-30

### Changed
- Admin UI fully rebuilt: grid dashboard with summary stats, a dedicated All Visits page,
  and all admin controllers moved to the `Admin::` namespace

---

## [0.11.0] — 2026-04-30

### Added
- `Trackguard::Admin::AnalyticsController` with `GET /admin/analytics` JSON endpoint;
  supports `?since`, `?flagged`, and `?whitelisted` query parameters

---

## [0.10.0] — 2026-04-25

### Added
- `WhitelistedIpsController` with create / destroy actions
- Admin UI whitelist button on each visitor row (7-day default expiry)

---

## [0.9.0] — 2026-04-24

### Added
- `Trackguard::DetectSuspiciousVisitorsJob`: scores visitors by volume, session
  presence, and referrer; flags automatically when threshold exceeded
- `WhitelistedIp` model with `expires_at`; whitelisted visitors are skipped by the
  detection job

---

## [0.8.0] — 2026-04-23

### Added
- Bearer token authentication for admin and analytics endpoints (`Trackguard.local_api_token`)

### Fixed
- Visitor flag / unflag routes correctly scoped under the engine mount point

---

## [0.7.0] — 2026-04-20

### Added
- Admin visitor flagging UI: flag form (with optional reason and name) and unflag button
- `Visitor::FLAGGED_BY` constant listing valid flagging actors

---

## [0.6.0] — 2026-04-14

### Added
- Self-contained admin UI with its own layout, CSS, and Stimulus controllers;
  no dependency on the host app's asset pipeline

---

## [0.5.1] — 2026-04-10

### Fixed
- `Trackguard::ApplicationHelper` now auto-included in host app controllers so
  `trackguard_meta_tags` is available without manual inclusion

---

## [0.5.0] — 2026-04-10

### Added
- `trackguard_meta_tags` view helper renders trace ID and session ID as meta tags
- `PageTracker#set_trace_id` sets a per-request trace ID for SPA deduplication

---

## [0.4.1] — 2026-04-10

### Fixed
- Stimulus controller now posts to `/trackguard/page_views` (engine-scoped path)
  instead of the bare `/page_views` route

---

## [0.4.0] — 2026-04-10

### Changed
- Admin routes scoped directly under the engine; `Admin::` namespace removed from
  route helpers for simpler host-app URL generation

---

## [0.3.0] — 2026-04-10

### Added
- Admin dashboard Rails engine mounted at `/trackguard` with `isolate_namespace`

---

## [0.2.1] — 2026-04-09

### Added
- `trackguard:install` generator producing individual migration files
- All classes namespaced under `Trackguard::`
- Isolated RSpec test suite with a minimal dummy Rails app
- DB tables renamed to `trackguard_visitors` / `trackguard_visits`
