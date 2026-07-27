# PropertyOS

Private Alpha for KaelVaren's AI operating system for independent UK landlords.

## Current objective

Deliver the first working vertical slice:

`sign in → property → compliance record → document → Today warning → completed task → timeline`

See `docs/PropertyOS_Alpha_Build_Specification.md` for scope and acceptance criteria.

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
  --dart-define=SUPABASE_ANON_KEY=YOUR_LOCAL_ANON_KEY
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

