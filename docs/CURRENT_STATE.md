# PropertyOS Current State

**Baseline recorded:** 05/08/2026

## Source and deployment facts

| Item | Verified state |
|---|---|
| Repository `main` | `6fd767f862b4ef5923100eb5f7e8bcc25be9ee50` |
| `origin/main` at baseline | Same commit as local `main` |
| Worktree at baseline review | Clean before documentation updates |
| Alpha URL | `https://alpha.propertyosuk.com` |
| Alpha `version.json` | Commit `6fd767f862b4ef5923100eb5f7e8bcc25be9ee50` |
| Alpha deployment time | `2026-08-03T13:50:38Z` |
| Deployment source | Push to `main` via `.github/workflows/deploy-alpha.yml` |
| Production | Not evidenced as established or approved |

The earlier handover evidence for deployed commit `a23abb7` is superseded by a
direct check on 05/08/2026. The hosted Flutter Alpha now matches `main` at
`6fd767f`.

This proves the frontend bundle version only. It does not by itself prove that
the linked Supabase project has every migration and Edge Function from the same
commit. GitHub Actions run metadata was not available during baseline review
because the local `gh` authentication was invalid.

## Delivered implementation increments

| Increment | Repository state |
|---|---|
| Flutter/Supabase foundation, Auth, organisations and RLS | Merged |
| Workspace, property and declared-ownership onboarding | Merged |
| Portfolio compliance register and deterministic classification | Merged |
| Private compliance evidence and authorised document links | Merged |
| AI-assisted certificate proposals and confirmation boundary | Merged |
| Compliance dashboard and reminders | Merged |
| Expense register, optional compliance link, receipt evidence and expense CSV | Merged |
| Alpha landing page and deployment-from-main repair | Merged |
| Expense action/delete Hotfixes 9.1–9.3 | Merged and frontend deployed |

“Merged” does not mean the frozen Alpha acceptance criteria are complete. The
repository milestone numbers describe implementation increments and do not map
one-to-one to the five milestones in the Alpha build specification.

## Open UAT defect: expense deletion

Karl reported that deleting an expense from the Expenses screen still failed,
including earlier behaviour in which the screen became blank. The relevant
hotfixes are now deployed, but there is no recorded post-deployment acceptance
result. Keep the defect open until observed behaviour passes.

On 05/08/2026 the blank-screen cause was traced to the confirmation dialog
closing the nested Expenses route instead of its root dialog. A local fix and
widget regression test are present in the working tree but are not yet checked,
committed, deployed or accepted in Alpha.

Acceptance requires:

1. As owner and member, create and delete a harmless Alpha expense.
2. Keep the screen usable and show a clear result.
3. Confirm the expense remains absent after refresh and a new session.
4. Confirm the database/API no longer returns the row for the organisation.
5. Confirm a viewer has no delete control and cannot delete through the API.
6. Add or strengthen an automated regression test for the demonstrated cause.

## Material acceptance gaps

- `integration_test/vertical_slice_test.dart` is empty and skipped.
- Formal test tracker cases, including TC-000, remain `Not started`.
- Tenancy, maintenance, general Tasks, property Timeline, Settings and complete
  organisation export are not exposed as routed application workflows.
- CI does not currently execute `001_rls_and_today.sql` or
  `002_auth_property_onboarding.sql`.
- Backup/restore, deletion, accessibility, responsive and full role/tenant
  separation evidence is not recorded.
- Private validation with real portfolio data is not documented as complete.

## Immediate priority

First retest expense deletion against deployed `6fd767f`. Then establish a
passing baseline by restoring omitted security suites to CI and implementing
TC-000 end to end. Do not infer overall Alpha readiness from the number of
merged implementation milestones.
