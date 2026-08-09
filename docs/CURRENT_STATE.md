# PropertyOS Current State

**Baseline recorded:** 07/08/2026

## Source and deployment facts

| Item | Verified state |
|---|---|
| Repository `main` | `f65568f8b7832144bf3be65d8cdea21c0d4c12b9` |
| `origin/main` at baseline | Same commit as local `main` |
| Worktree at baseline review | Clean before documentation updates |
| Alpha URL | `https://alpha.propertyosuk.com` |
| Alpha `version.json` | Commit `f65568f8b7832144bf3be65d8cdea21c0d4c12b9` |
| Alpha deployment time | `2026-08-07T11:15:04Z` |
| Deployment source | Push to `main` via `.github/workflows/deploy-alpha.yml` |
| Production | Not evidenced as established or approved |

The hosted Flutter Alpha metadata was verified on 07/08/2026 after PR #21 and
matches `main` at `f65568f`. TC-000 is implemented only on
`codex/milestone-10-tc000` and is not yet deployed.

This proves the frontend bundle version only. It does not by itself prove that
the linked Supabase project has every migration and Edge Function from the same
commit. GitHub Actions run `31023681109` passed on the merge commit: Flutter
format, analysis and tests; Edge Function format and type-check; clean database
rebuild; and all six pgTAP suites (71 assertions). The Alpha deployment run
`31023680833` also passed.

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

## TC-000 local acceptance result

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

This is local acceptance evidence, not Alpha deployment or UAT evidence.

## Remaining material acceptance gaps

- TC-000 has not yet passed CI, been deployed with its database migration, or
  been retested by Karl on the hosted Alpha.
- Formal tracker cases other than TC-000 remain unexecuted.
- Tenancy, maintenance, general Tasks, property Timeline, Settings and complete
  organisation export are not exposed as routed application workflows.
- Backup/restore, deletion, accessibility, responsive and full role/tenant
  separation evidence is not recorded.
- Private validation with real portfolio data is not documented as complete.

## Immediate priority

Review the TC-000 branch, run CI, and open a draft PR. After separate readiness,
merge and deployment approvals, apply the migration and frontend together to
Alpha and execute TC-000 UAT there. Do not infer overall Alpha readiness from
the local TC-000 pass or the number of merged implementation milestones.
