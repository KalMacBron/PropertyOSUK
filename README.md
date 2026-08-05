# PropertyOS

Private Alpha for KaelVaren's AI operating system for independent UK landlords.

## Current objective

Deliver the first working vertical slice:

`sign in → property → compliance record → expenses → document evidence → Today warning → completed task → timeline`

The current Alpha also validates the property-expenses layer so compliance work can be linked to cost and receipt evidence.

Start with `docs/HANDOVER.md` for the current operational baseline. See
`docs/PropertyOS_Alpha_Build_Specification.md` for the frozen Alpha scope and
acceptance criteria.

## Stack

- Flutter Web
- Riverpod
- GoRouter
- Supabase Auth, PostgreSQL and Storage
- Supabase CLI migrations and tests

## Repository layout

```text
lib/
  app/                 App shell, routing and theme
  core/                Shared configuration and services
  features/            Feature-first UI, domain and data code
supabase/
  migrations/          Versioned database changes
  seed.sql              Fictional local seed data
test/                   Unit and widget tests
integration_test/       Vertical-slice tests
docs/                   Product and engineering specifications
```

## Local setup

1. Install Flutter and the Supabase CLI.
2. Copy `.env.example` to `.env`.
3. Run `supabase start`.
4. Run `supabase db reset`.
5. Supply the local Supabase URL and anon key using `--dart-define`.
6. Run `flutter pub get`.
7. Run `flutter run -d chrome`.

Example:

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_LOCAL_PUBLISHABLE_KEY
```

Never commit `.env`, service-role keys or OpenAI credentials.

## Checks

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
supabase db reset
supabase test db
```

## Environments

- `local`: developer machine and fictional seed data
- `development`: private shared Alpha
- `production`: created only after Alpha security and recovery checks pass

Use separate Supabase projects for development and production.
