# Contributing

## Development setup

The test suite uses a minimal dummy Rails app at `spec/dummy/`. Migrations from `db/migrate/` are applied automatically before the suite via `ActiveRecord::MigrationContext` in `spec/rails_helper.rb`.

```bash
bundle install
bundle exec rspec          # run all specs
bundle exec rspec <file>   # run a single spec file
bundle exec rubocop        # lint
```

Run both before opening a PR:

```bash
bundle exec rubocop && bundle exec rspec
```

## Workflow

- Never commit directly to `main` — branch → PR → merge.
- Branch naming: `feature/<short-description>`

## Style notes

RuboCop is enforced. A few non-obvious rules this project relies on:

- Spaces inside array literals: `[ "a", "b" ]`
- Files must end with a final newline