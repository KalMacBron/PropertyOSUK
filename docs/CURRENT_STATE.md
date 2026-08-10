# PropertyOS Current State

**Baseline recorded:** 10/08/2026

## Source and deployment facts

| Item | Verified state |
|---|---|
| Repository `main` | `04430c5cff52fab3462a88e77b44d31b5d2c2ee0` |
| `origin/main` at baseline | Same commit as local `main` |
| Worktree at baseline review | Clean before documentation updates |
| Alpha URL | `https://alpha.propertyosuk.com` |
| Alpha `version.json` | Commit `04430c5cff52fab3462a88e77b44d31b5d2c2ee0` |
| Alpha deployment time | `2026-08-10T11:00:21Z` |
| Deployment source | Push to `main` via `.github/workflows/deploy-alpha.yml` |
| Production | Not evidenced as established or approved |

The hosted Flutter Alpha metadata was verified on 10/08/2026 after PR #28 and
matches `main` at `04430c5`. TC-000 has been merged and deployed. Karl has also
accepted the refreshed KaelVaren UI, sign-out/landing flow, Today compliance
summary and filtered compliance drill-downs.

This proves the frontend bundle version only. It does not by itself prove that
the linked Supabase project has every migration and Edge Function from the same
commit. GitHub Actions CI passed on `04430c5`. Alpha deployment run
`31381497335` completed successfully, including the Hostinger FTPS upload.

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
| Expense action/delete Hotfixes 9.1–9.3 | Merged, frontend deployed and accepted by Karl |
| Milestone 10 database CI baseline | Merged and passing locally and in CI |
| TC-000 durable Today completion and property timeline | Merged and deployed |
| KaelVaren UI foundation, landing/sign-out flow and Today summary | Merged, deployed and accepted |
| Compliance summary filtered drill-downs | Merged, deployed and accepted |
| Portfolio Tasks workspace | In progress on `codex/tasks-workspace` |

“Merged” does not mean the frozen Alpha acceptance criteria are complete. The
repository milestone numbers describe implementation increments and do not map
one-to-one to the five milestones in the Alpha build specification.

## Closed UAT defect: expense deletion

The blank-screen cause was traced to the confirmation dialog closing the nested
Expenses route instead of its root dialog. Hotfix 9.3 corrected the dialog
navigation and added widget regression coverage. Karl retested the deployed
Alpha on 05/08/2026 and confirmed that expense deletion worked. Formal
owner/member/viewer API evidence remains part of the wider role-separation
acceptance gap below; the reported UI defect itself is closed.

## TC-000 acceptance result

TC-000 passes against a reset, disposable local Supabase stack in headless
Chrome. The executable test creates two fictional users and organisations and
verifies property onboarding, a Gas Safety expiry at today + 31 days,
`due_soon`, private evidence Storage, the dated Today action and deep link,
durable completion, the property timeline event, and denial of the same record,
document, task and action IDs to the second organisation.

Evidence recorded on 07/08/2026:

- clean database rebuild;
- seven pgTAP files, 92 assertions passing;
- Flutter analysis clean and 24 unit/widget tests passing;
- the TC-000 Flutter Web integration journey passing in Chrome;
- TC-000 marked `Pass` in the authoritative test tracker.

The implementation and migration subsequently passed CI and were deployed to
Alpha. The formal tracker still needs broader Alpha acceptance cases beyond
TC-000.

## Remaining material acceptance gaps

- Formal tracker cases other than TC-000 remain unexecuted.
- Tenancy, maintenance, Settings and complete organisation export are not
  exposed as routed application workflows. General Tasks is the current stage;
  timeline events are currently surfaced within compliance records.
- Backup/restore, deletion, accessibility, responsive and full role/tenant
  separation evidence is not recorded.
- Private validation with real portfolio data is not documented as complete.

## Immediate priority

Complete the approved Tasks workspace contract, verify it locally and in CI,
then obtain separate readiness, merge and deployment approvals. Follow with
Maintenance, Tenancies, Export and the remaining formal Alpha acceptance
coverage. Do not infer overall Alpha readiness from merged increments alone.
