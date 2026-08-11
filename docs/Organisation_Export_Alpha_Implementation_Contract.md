# Organisation Export Alpha implementation contract

**Status:** JSON foundation deployed; Excel Portfolio Report follow-up
implemented and locally verified, awaiting commit/review/deployment

## Outcome

Meet the frozen Alpha portability requirement with an Owner/Admin-only,
organisation-scoped export. The original JSON and individual-document interface
was deployed, but Alpha UAT showed that it was too technical and that Safari
blocked the delayed document tab. Karl approved replacing the user-facing
interface with a formatted Excel Portfolio Report on 11/08/2026.

## Approved Excel Portfolio Report follow-up

- One clear **Download portfolio report (.xlsx)** action for Owner/Admin.
- Formatted sheets for Summary, Properties, Ownership, Compliance, Tenancies,
  Maintenance, Contractors, Tasks, Expenses, Users, Document Register and Audit
  History.
- UK dates, GBP values, filters, frozen headings and readable column widths.
- Typed spreadsheet dates, numbers, percentages and money values.
- Document metadata only; no Storage path, embedded file or individual-document
  download control on the Export screen.
- The existing privileged JSON RPC remains the internal, audited and
  organisation-scoped data source. JSON is not exposed as a normal user action.
- Clear warning that the workbook contains private tenant, user and financial
  information.

This is an explicitly approved adjustment to the frozen wording that documents
are exported separately through authorised links. Documents remain available
through their normal operational records, but the Export screen no longer acts
as a document downloader.

## Deployed foundation retained internally

- A versioned JSON export containing confirmed structured Alpha data, record
  counts, GBP currency context and export timestamp. This is now an internal
  workbook data source rather than a user-facing download.
- Membership roles and invitation state, but no password, session, token or
  authentication metadata.
- Document metadata without Storage bucket/path, extracted content or
  unconfirmed AI analysis.
- Existing document-export RPCs remain deployed but have no controls on the
  Export screen; documents are accessed through their operational records.
- Audit events for each structured export request.
- Database enforcement for Owner/Admin and cross-organisation denial.

## Excluded

- ZIP archives, bulk document download or server-generated export jobs.
- Database backup, restore or import.
- Accounting integrations or alternative reporting formats beyond the existing
  expense CSV.
- Derived Today rows and raw/unconfirmed AI extraction payloads.
- Passwords, sessions, tokens, provider metadata or secret configuration.
- Organisation deletion or data-erasure workflows.

## Excel follow-up acceptance

1. Owner and Admin see one clear portfolio-report download action; Viewer and
   other non-privileged roles remain denied.
2. The generated `.xlsx` contains exactly the 12 approved, clearly named
   worksheets with joined human-readable property, entity, tenant, contractor
   and requirement names.
3. Dates, counts, percentages and GBP amounts are typed spreadsheet values with
   UK formatting; headings are frozen, filters are enabled and widths are
   readable.
4. Empty sections state that no records exist instead of failing or producing
   an ambiguous blank sheet.
5. The workbook contains document metadata but no Storage path, embedded
   document, extracted AI data, password, session, token or authentication
   secret.
6. JSON and individual-document download controls are absent from the normal
   Export interface.
7. The existing Owner/Admin-only RPC remains the organisation-scoped and
   audited source of the workbook data.

## Verification result

- Repository formatting check passed with 98 files unchanged.
- Flutter analysis passed with no issues.
- All Flutter tests passed, including workbook structure, typed-value,
  sensitive-field exclusion and role/UI regression coverage.
- Local Supabase rebuilt cleanly through the export migration.
- All 15 pgTAP files and 258 assertions passed, including 24 export-specific
  role, tenant, sensitive-field and audit assertions.
- A representative workbook was imported and rendered across all 12 sheets;
  no formula errors, clipped headings or unreadable columns were found.
- The Flutter release web build completed successfully. The existing missing
  Cupertino icon-font warning remains unchanged.
- Authenticated Alpha workbook download UAT remains pending commit, review and
  deployment approval.
