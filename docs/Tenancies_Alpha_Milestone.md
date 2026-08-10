# Tenancies Alpha milestone

**Contract approved:** 10/08/2026  
**Status:** Merged, deployed and accepted in Alpha; editing follow-up in progress

## Outcome

PropertyOS provides an organisation-scoped tenancy register containing current,
upcoming and historical tenancy dates. Fixed terms ending within 60 days remain
deterministic Today prompts and now drill into the tenancy workspace.

## Included

- One lead tenant display name or initials per Alpha tenancy.
- Property, start date, optional fixed-term end date, monthly rent in integer
  pence and payment day from 1 to 28.
- Create, edit and end workflows for owner, admin and member roles.
- Read-only access for Viewer.
- Actual end date and preserved historical record; no hard deletion.
- Audit-safe correction of historical records and an explicit, confirmed reopen
  action; both remain subject to the approved follow-up release.
- Atomic database operations and property timeline events.
- Organisation isolation, role and cross-property reference tests.

## Privacy and product exclusions

The Alpha interface does not collect tenant email, telephone number, identity
documents, bank details, Right to Rent evidence, deposit accounting, rent
collection or arrears. Tenant portals and additional linked tenants remain
outside this milestone. The underlying schema can support more than one tenant
later without changing the organisation boundary.

## Acceptance

- A writer can create, edit and end a tenancy without partial records.
- An ending fixed term appears on Today and opens its tenancy.
- Ended tenancies remain visible as history and leave the active Today window.
- Historical corrections preserve archived status and write changed fields to
  the property timeline; reopening is a separate confirmed action.
- Viewer can read but cannot reach or bypass write operations.
- A different organisation cannot read or mutate the tenancy, tenant link or
  associated timeline events.
