# PropertyOS engineering instructions

## Product boundary

PropertyOS is a private Alpha for independent UK residential landlords. Keep
the frozen scope in `docs/PropertyOS_Alpha_Build_Specification.md`. New ideas
belong in the backlog unless they block an Alpha acceptance outcome.

## Architecture

- Flutter Web with Riverpod and GoRouter
- Supabase Auth, PostgreSQL and private Storage
- All business data is scoped by `organisation_id`
- Row-Level Security is mandatory before real data is used
- Today recommendations are deterministic and traceable to source records
- AI suggestions never alter confirmed operational facts without user approval

## Conventions

- Use UK terminology, GBP and `dd/MM/yyyy` in the interface.
- Use feature-first Flutter folders.
- Store money as integer pence and dates as PostgreSQL `date` where time is not
  meaningful.
- Never commit credentials, `.env` files, tenant identity documents or real
  portfolio data.
- Migrations are immutable after they have been applied to a shared environment.

## Required checks

Run the available subset before committing:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
supabase db reset
supabase test db
```

If a tool is unavailable, report the unrun check explicitly. A skipped
integration test is a visible milestone target, not evidence of a passing flow.

## Definition of done

- Code and migrations are reviewed for cross-organisation references.
- RLS policies cover every organisation-scoped table and Storage path.
- Tests cover the changed rule or workflow.
- User-facing claims do not certify compliance or provide legal or tax advice.
- Documentation reflects material architecture or scope changes.
