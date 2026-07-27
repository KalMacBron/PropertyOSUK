 integration_test/

 End-to-end Alpha workflow tests for PropertyOS, run against a real Flutter build and Supabase backend.

 This folder will hold integration_test suites covering the primary vertical slice and the Alpha Acceptance Test:

 - TC-000: add property, add compliance record, upload evidence, confirm dates, calculate warning, show Today action, complete task, write timeline event, then confirm cross-organisation access is denied.
 - Full sign-in to sign-out flows for each role (owner, admin, member, viewer).
 - Export flow (JSON and CSV) end to end.

 See docs/testing/PropertyOS_Alpha_Test_Strategy.docx and docs/testing/PropertyOS_Alpha_Test_Cases.xlsx for the full test suite these scenarios are drawn from.

 Run with: flutter test integration_test
