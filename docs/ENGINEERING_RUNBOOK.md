# PropertyOS Engineering Runbook

## Local setup

Install Flutter, Docker and the Supabase CLI. From the repository root:

```bash
cp .env.example .env
supabase start
supabase db reset
flutter pub get
flutter run -d chrome \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_LOCAL_PUBLISHABLE_KEY
```

Use fictitious data locally. `.env` is local-only and must never be committed.
The client requires `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`.

## Required validation

Run the available relevant subset before committing or requesting review:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
supabase db reset
supabase test db
```

Run `flutter test integration_test` when the integration environment is
available. A skipped test is an uncompleted acceptance target, not a pass.

For Edge Function changes, also run:

```bash
deno fmt --check supabase/functions
deno check supabase/functions/certificate-processing/index.ts
```

Report every unavailable or unrun check explicitly in the PR.

## Data-change rules

- Shared migrations are immutable; add a new migration for subsequent changes.
- Review every organisation-scoped table, relationship, view, function and
  Storage path for tenant isolation and add a focused SQL test.
- Store money as integer pence and calendar-only dates as PostgreSQL `date`.
- Use private organisation-prefixed Storage paths.
- Do not broaden Data API grants without a tested rationale.

## Branch, PR and approval flow

1. Confirm the approved outcome, acceptance criteria and exclusions.
2. Create a focused branch from current `main`.
3. Implement the smallest coherent change with tests.
4. Run and record the relevant checks.
5. Open a draft PR describing behaviour, security impact and unrun checks.
6. Keep it draft until Karl approves readiness.
7. Karl separately approves merge into `main`.
8. Alpha deployment may proceed inside approved scope.
9. Production creation or deployment always requires separate approval.

Use [the specialist workflow](Codex_Multi_Agent_Development_Workflow.md) only
when Karl explicitly requests delegation or the PropertyOS multi-agent workflow.

## Alpha deployment verification

Pushes to `main` build Flutter Web, disable the Alpha PWA worker, version the
application bundle, write `version.json`, and upload incrementally to Hostinger.

After deployment:

1. Fetch `https://alpha.propertyosuk.com/version.json`.
2. Compare its full commit to the tested `main` head and Actions run.
3. Sign in with a safe test account and execute the changed journey.
4. Use a hard refresh or private window when investigating stale assets.
5. Record the exact commit, environment, time and acceptance result.

Frontend version equality does not prove database migrations or Edge Functions
are current. Verify those separately for backend-dependent changes.

Never expose FTP, Supabase service-role or OpenAI secrets in logs, screenshots
or documentation.
