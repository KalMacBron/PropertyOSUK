# PropertyOS Roadmap and Guardrails

This roadmap records direction, not blanket approval to implement every item.
The frozen Alpha scope and Karl's explicit milestone approvals remain controlling.

## Now: establish a trustworthy Alpha baseline

1. Retest the reported expense-deletion failure against deployed `6fd767f` and
   close it only with recorded owner/member/viewer evidence.
2. Restore omitted foundation/onboarding RLS and Today suites to CI.
3. Implement and pass TC-000 across authentication, database, Storage, Today,
   task completion, timeline and cross-organisation denial.
4. Verify deployed Supabase migrations and the certificate-processing Edge
   Function match the tested source.
5. Record formal acceptance results instead of relying on merged milestone names.

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
