# PropertyOS Roadmap and Guardrails

This roadmap records direction, not blanket approval to implement every item.
The frozen Alpha scope and Karl's explicit milestone approvals remain controlling.

## Now: establish a trustworthy Alpha baseline

1. ~~Pin and verify the local, CI and Alpha build toolchain.~~ Completed in
   PR #21.
2. ~~Implement and pass TC-000 locally across authentication, database,
   Storage, Today, task completion, timeline and cross-organisation denial.~~
   Completed on `codex/milestone-10-tc000`.
3. ~~Review, merge and deploy TC-000 through the approval gates, then execute
   the same journey on Alpha.~~ Completed and deployed.
4. Verify deployed Supabase migrations and the certificate-processing Edge
   Function match the tested source.
5. Continue recording formal acceptance results instead of relying on merged
   milestone names.

Completed on 05/08/2026: Karl accepted the deployed expense-deletion fix, and
PR #20 restored the foundation/onboarding RLS and Today suites to CI. The merge
commit passed all six database suites (71 assertions).

## Next: complete the frozen private Alpha

Subject to an approved implementation contract:

- ~~Extend the TC-000 task-completion and property-timeline foundation into a
  routed Tasks workspace with Today drill-downs.~~ Completed and accepted.
- ~~SaaS Foundation 1: explicit authorised organisation context, persisted
  workspace selection, safe switching and final-owner safeguards.~~ Completed,
  deployed and accepted.
- **In progress:** SaaS Foundation 2: invitations, member administration, role
  changes and organisation-scoped audit history.
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
- Complete the remaining User Management lifecycle and multi-factor
  authentication (MFA), including recovery and step-up authentication for
  sensitive actions.

## Deliberate boundaries

PropertyOS, TradeOS and TradeCircle remain independent. Fire risk assessment
authoring is a distinct product area. Shared branding or future opt-in exchange
must not create a runtime dependency without explicit product, architecture and
security approval.

Prioritise the smallest evidence-backed step that makes PropertyOS dependable
for its first paying landlord.
