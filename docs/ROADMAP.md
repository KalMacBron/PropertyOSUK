# PropertyOS Roadmap and Guardrails

This roadmap records direction, not blanket approval to implement every item.
The frozen Alpha scope and Karl's explicit milestone approvals remain controlling.

## Now: establish a trustworthy Alpha baseline

1. Pin and verify the local, CI and Alpha build toolchain, including Node.js 24
   releases of the checkout and FTPS deployment actions.
2. Implement and pass TC-000 across authentication, database, Storage, Today,
   task completion, timeline and cross-organisation denial.
3. Verify deployed Supabase migrations and the certificate-processing Edge
   Function match the tested source.
4. Record formal acceptance results instead of relying on merged milestone names.

Completed on 05/08/2026: Karl accepted the deployed expense-deletion fix, and
PR #20 restored the foundation/onboarding RLS and Today suites to CI. The merge
commit passed all six database suites (71 assertions).

## Next: complete the frozen private Alpha

Subject to an approved implementation contract:

- Complete Tasks and Timeline first, because they close the central
  evidence-to-action vertical slice.
- Add the routed tenancy and maintenance workflows already represented in the
  database foundation.
- Complete organisation-scoped JSON/CSV export and authorised document export.
- Perform role, recovery, deletion, privacy, responsive and keyboard testing.
- Validate daily use with Karl's portfolio before inviting additional testers.

## Later candidates — not approved implementation scope

- Subscription and billing, after the core workflow is trusted.
- Broader rental-management or financial tracking.
- Further AI extraction improvements with transparent confirmation.
- Native iOS and Android clients after web validation.
- Optional integrations with independent KaelVaren products.

## Deliberate boundaries

PropertyOS, TradeOS and TradeCircle remain independent. Fire risk assessment
authoring is a distinct product area. Shared branding or future opt-in exchange
must not create a runtime dependency without explicit product, architecture and
security approval.

Prioritise the smallest evidence-backed step that makes PropertyOS dependable
for its first paying landlord.
