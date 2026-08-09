 integration_test/

 End-to-end Alpha workflow tests for PropertyOS, run against a real Flutter build and Supabase backend.

This folder holds full-stack suites covering the primary vertical slice and the Alpha Acceptance Test:

 - TC-000: add property, add compliance record, upload evidence, confirm dates, calculate warning, show Today action, complete task, write timeline event, then confirm cross-organisation access is denied.
 - Full sign-in to sign-out flows for each role (owner, admin, member, viewer).
 - Export flow (JSON and CSV) end to end.

 See docs/testing/PropertyOS_Alpha_Test_Strategy.docx and docs/testing/PropertyOS_Alpha_Test_Cases.xlsx for the full test suite these scenarios are drawn from.

TC-000 requires a disposable local Supabase database. Reset it immediately
before running the suite, then provide only the local publishable client key:

```bash
supabase db reset
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/vertical_slice_test.dart -d chrome \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_LOCAL_PUBLISHABLE_KEY
```

The test creates fictional, uniquely named users and organisations. Never point
it at a shared or production Supabase project.
