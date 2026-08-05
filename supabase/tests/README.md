# supabase/tests/

Database and Row-Level Security tests for PropertyOS Alpha.

This folder contains pgTAP SQL suites covering:

- Migration applies cleanly to an empty Supabase project.
- SEC-01/SEC-02: RLS denies cross-organisation SELECT, INSERT, UPDATE and DELETE on every organisation-scoped table.
- Storage object paths are organisation-prefixed and cross-organisation document access is denied.
- COMP-03 to COMP-08: compliance status views return the correct status for each date/condition boundary.
- TODAY-02 to TODAY-12: Today query thresholds at 14/45/30/60-day boundaries.
- Archived records are excluded from normal views but remain recoverable.

See docs/testing/PropertyOS_Alpha_Test_Strategy.docx and docs/testing/PropertyOS_Alpha_Test_Cases.xlsx for the full test suite these scenarios are drawn from, especially the Security / RLS and Today sections.

CI and local verification run every SQL suite discovered in this directory:

```bash
supabase start
supabase db reset
supabase test db
```

Do not replace the directory-wide test command with a hand-maintained filename
list: a new security suite must fail CI until it passes, not remain silently
unexecuted.
