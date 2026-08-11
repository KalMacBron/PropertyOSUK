# Maintenance Alpha implementation contract

**Prepared:** 11/08/2026
**Contract approved:** 11/08/2026
**Status:** Implementation and local verification complete; awaiting review

## Outcome

An authorised landlord can record, prioritise and progress a property
maintenance issue from report to resolution. PropertyOS surfaces actionable
issues on Today and the Property Dashboard while preserving organisation
isolation, Viewer read-only access and an auditable history.

This milestone completes the Maintenance slice already included in the frozen
Alpha specification. It is operational tracking, not a contractor portal,
procurement system or accounting workflow.

## User journey

1. An Owner, Admin or Member opens Maintenance or a property's dashboard and
   records an issue against one property.
2. They enter a title, optional description, priority, reported date, optional
   target date, optional contractor and optional estimated cost.
3. They progress the issue through its supported status workflow and may add
   notes or supporting evidence.
4. High and urgent open issues appear deterministically on Today. The property
   dashboard shows open issues and recent resolved issues.
5. On resolution, the user records the resolution date, optional actual cost
   and completion notes. PropertyOS records timeline and audit evidence.
6. A Viewer can inspect and download authorised evidence but cannot create,
   edit, progress, resolve, cancel or delete an issue.

## Included product scope

### Maintenance workspace

- Routed `/maintenance` workspace with open, resolved and cancelled views.
- Search and filters for property, priority and status.
- Create, inspect and edit an issue in a stable detail flow.
- Status progression using the existing database states:
  `reported`, `triaged`, `quoted`, `approved`, `scheduled`, `in_progress`,
  `resolved` and `cancelled`.
- Alpha permits movement between non-terminal states so users can correct or
  simplify a real workflow. Resolving or cancelling is explicit; a terminal
  issue can leave that state only through the explicit reopen action, which
  returns it to `reported`.
- Reopening a resolved or cancelled issue requires an explicit action and audit
  entry; history is retained.
- UK interface conventions: GBP, `dd/MM/yyyy`, landlord terminology and no
  claims that work or a property is legally compliant.

### Issue data

- Required property and title.
- Priority: low, medium, high or urgent.
- Optional description, reported date, target date, contractor, estimated cost,
  actual cost and notes.
- Money remains integer pence in PostgreSQL and is formatted as GBP in Flutter.
- Resolution records `resolved_at`; reopening clears the current resolution
  marker without deleting its timeline or audit event.
- Contractor selection reuses organisation-scoped contractor data. A small
  in-flow contractor creation affordance may be included only if the existing
  contractor repository can support it without expanding into contractor
  management.

### Connected workflows

- Today uses the existing deterministic rule: high or urgent issues that are
  not resolved or cancelled produce an action linked to the issue.
- Property Dashboard gains open counts, urgent/high emphasis and recent resolved
  issues with property-scoped drill-downs.
- Important create, status-change, resolution, cancellation and reopening
  actions append property timeline events.
- Supporting evidence uses the existing private Storage/document boundary with
  `maintenance` scope and organisation-prefixed paths.
- Issue detail may show linked tasks and expenses using their existing optional
  `maintenance_issue_id` relationships. Creating a linked task or expense must
  use the existing workflow with property and maintenance issue preselected;
  this milestone does not duplicate task or expense state.

## Authorisation and data integrity

- Every issue, contractor reference, linked task, expense, document and timeline
  event must share the authenticated organisation and property context.
- Owner, Admin and Member may write; Viewer is read-only.
- The client capability gate improves UX but PostgreSQL RLS and authenticated
  database functions remain authoritative.
- Mutating operations use reviewed RPCs where atomic status, audit and timeline
  writes are required; the client must not compose multi-step operational writes.
- Unknown, inactive and cross-organisation identifiers return a safe unavailable
  result without confirming that another organisation's record exists.
- Applied migrations are immutable. Any schema, policy or RPC change is a new
  migration with pgTAP coverage.

## Expected implementation shape

- Feature-first Flutter module under `lib/features/maintenance/` with domain,
  data/application and presentation layers.
- GoRouter routes for portfolio Maintenance and issue detail.
- Riverpod providers scoped by the active authorised organisation.
- A new migration is expected to harden maintenance mutation APIs, audit and
  timeline behaviour. The existing `maintenance_issues` table, enums, RLS,
  Today view, document relationship and task/expense relationships are reused
  rather than replaced.
- No AI processing is required for this milestone.

## Acceptance criteria

1. Owner, Admin and Member can create an issue for a property and see it in the
   Maintenance workspace and Property Dashboard.
2. Viewer sees the same authorised issue data but every mutation is denied in
   both the interface and direct database tests.
3. Cross-organisation reads, writes and references are denied, including IDs
   supplied directly to RPCs or routes.
4. Required fields, dates, state transitions and non-negative pence values are
   validated consistently by UI and database.
5. Supported state changes persist, append audit/timeline evidence and do not
   erase earlier operational history.
6. Resolving records the resolution date; explicit reopening restores an open
   state without deleting the prior resolution event.
7. High and urgent open issues appear on Today with correct property, reason,
   priority and deep link; resolved/cancelled issues do not.
8. Property Dashboard maintenance summaries include only the selected property
   and drill into the property-filtered Maintenance workspace.
9. A supporting document remains private and can be accessed only through an
   authorised short-lived link.
10. Linked task and expense creation preserves organisation, property and
    maintenance issue context without duplicating the source records.
11. Empty, loading, partial-error and unavailable states do not blank unrelated
    workspace or dashboard content.
12. Formatting, Flutter analysis/tests, clean database reset and all pgTAP
    suites pass before commit and again in CI.

## Required test evidence

- Domain tests for status presentation, open/resolved classification, priority
  ordering, cost formatting and deterministic summaries.
- Widget tests for create/edit/progress, Viewer read-only UI, filters, empty and
  partial-error states, Today deep links and Property Dashboard drill-downs.
- pgTAP tests for roles, cross-organisation isolation, forged references,
  transition validation, atomic timeline/audit writes and document access.
- At least one browser-level Alpha journey: create, progress, attach evidence,
  resolve, verify Today removal and property timeline, then verify Viewer denial.

## Explicit exclusions

- Contractor portal, invitations, messaging, job dispatch or availability.
- Quote comparison, tendering, purchase orders and approval chains.
- Rent deductions, arrears, insurance claims, invoicing, payment or accounting.
- Automated supplier emails, SMS, calendar booking or external integrations.
- Recurring/preventive maintenance schedules and asset registers.
- AI diagnosis, price estimates or assertions that work is safe, certified or
  legally sufficient.
- Hard deletion of maintenance history.
- Broad contractor-management screens beyond the bounded selection need.

## Approval gate

Approval authorises implementation of this contract on a feature branch. Any
material change to the status model, tenant boundary, Storage design, financial
scope or external integrations requires a separate decision before coding.

## Implementation record

Implementation is complete locally on `codex/maintenance-alpha-contract`. The
approved status model and product exclusions remain unchanged. The existing
expense table did not contain the optional maintenance relationship assumed by
the contract, so the new migration adds a same-organisation, same-property
foreign key rather than relying on client-side association. No external system
or additional financial workflow has been introduced.

Local verification passes with 67 Flutter tests and 216 database assertions,
including 35 Maintenance-specific workflow, role, tenant, evidence and linked
task checks. Supabase security/performance advisors report no
Maintenance-specific warning or error. The required authenticated browser
journey remains explicitly pending until the migration and web build are
deployed to Alpha after review and merge approval.
