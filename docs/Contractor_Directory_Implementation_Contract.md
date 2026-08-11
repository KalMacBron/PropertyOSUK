# Contractor Directory implementation contract

**Status:** Scope approved; implementation and local verification complete
**Branch:** `codex/contractor-directory`

## Outcome

Complete the bounded contractor selection gap in Maintenance by allowing an
organisation to maintain its contractor records and create a contractor while
reporting or editing an issue.

## Included

- An organisation-scoped Contractor Directory under Maintenance.
- Create and edit name, trade, email, telephone and notes.
- Archive and reactivate contractors instead of deleting historical records.
- Active contractors are available in the Maintenance assignment selector.
- An **Add contractor** action inside the Maintenance issue form immediately
  selects the newly created contractor.
- Owner, Admin and Member can create and update; Viewer is read-only.
- RPC-only mutations set audit ownership from the authenticated user and reject
  cross-organisation references.
- Widget, domain and pgTAP regression coverage.

## Excluded

- Contractor accounts, portals, invitations or authentication.
- Job dispatch, availability, quotes, purchase orders or approvals.
- Email, SMS, calendar, payment or accounting integrations.
- Contractor document packs, ratings or property-level preferred-contractor
  rules.
- Hard deletion of contractors.

## Acceptance

1. An authorised user can add a contractor from the directory or issue form.
2. The new active contractor can be selected without leaving the issue flow.
3. Contact fields can be edited and persist after refresh.
4. Archived contractors remain on historical issues but cannot be newly
   assigned; they can be reactivated.
5. Viewer sees directory details but no mutation controls.
6. Other organisations cannot read, infer or mutate contractor records.

## Verification result

- Repository formatting check passed with 90 files unchanged.
- Flutter analysis passed with no issues.
- All 70 Flutter tests passed.
- Local Supabase rebuilt cleanly through the Contractor Directory migration.
- All 14 pgTAP files and 234 assertions passed, including 18 contractor-specific
  security assertions.
- Local database advisors returned no errors or new contractor policy warning;
  existing baseline performance warnings remain recorded separately.
- Authenticated Alpha browser acceptance remains pending review, merge,
  migration and deployment approval.
