# Organisation Export Alpha implementation contract

**Status:** Approved; implementation and local verification complete
**Branch:** `codex/organisation-export-alpha`

## Outcome

Meet the frozen Alpha portability requirement with an Owner/Admin-only,
organisation-scoped JSON export and a separate authorised private-document
download manifest.

## Included

- A Settings → Export screen for Owner and Admin.
- A versioned JSON export containing confirmed structured Alpha data, record
  counts, GBP currency context and export timestamp.
- Membership roles and invitation state, but no password, session, token or
  authentication metadata.
- Document metadata without Storage bucket/path, extracted content or
  unconfirmed AI analysis.
- A searchable document manifest with one-at-a-time, 60-second signed download
  links.
- Audit events for each structured export and authorised document download.
- Database enforcement for Owner/Admin and cross-organisation denial.

## Excluded

- ZIP archives, bulk document download or server-generated export jobs.
- Database backup, restore or import.
- Accounting integrations or alternative reporting formats beyond the existing
  expense CSV.
- Derived Today rows and raw/unconfirmed AI extraction payloads.
- Passwords, sessions, tokens, provider metadata or secret configuration.
- Organisation deletion or data-erasure workflows.

## Acceptance

1. Owner and Admin can download a versioned JSON snapshot for the active
   organisation.
2. Member, Viewer, anonymous and other-organisation users cannot request the
   export or complete document manifest.
3. The JSON has no Storage paths, document contents or authentication secrets.
4. Owner/Admin can search the manifest and download an authorised document via
   a short-lived signed URL.
5. Unknown or cross-organisation document IDs are indistinguishably
   unavailable.
6. Data and document exports append organisation audit events.

## Verification result

- Repository formatting check passed with 96 files unchanged.
- Flutter analysis passed with no issues.
- All 75 Flutter tests passed.
- Local Supabase rebuilt cleanly through the export migration.
- All 15 pgTAP files and 258 assertions passed, including 24 export-specific
  role, tenant, sensitive-field and audit assertions.
- Local database advisors returned no errors or new export-specific policy
  warnings; existing baseline performance warnings remain unchanged.
- Authenticated Alpha JSON-save and document-download journeys remain pending
  review, merge, migration and deployment approval.
