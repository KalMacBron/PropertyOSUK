# PropertyOS Current State

**Baseline recorded:** 06/08/2026

## Source and deployment facts

| Item | Verified state |
|---|---|
| Repository `main` | `67f539804926270fb73ea5f28cb3e77368938905` |
| `origin/main` at baseline | Same commit as local `main` |
| Worktree at baseline review | Clean before documentation updates |
| Alpha URL | `https://alpha.propertyosuk.com` |
| Alpha `version.json` | Commit `67f539804926270fb73ea5f28cb3e77368938905` |
| Alpha deployment time | `2026-08-05T16:07:58Z` |
| Deployment source | Push to `main` via `.github/workflows/deploy-alpha.yml` |
| Production | Not evidenced as established or approved |

The hosted Flutter Alpha was directly verified after PR #20 merged and matches
`main` at `67f5398`.

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

## Material acceptance gaps

- `integration_test/vertical_slice_test.dart` is empty and skipped.
- Formal test tracker cases, including TC-000, remain `Not started`.
- Tenancy, maintenance, general Tasks, property Timeline, Settings and complete
  organisation export are not exposed as routed application workflows.
- Backup/restore, deletion, accessibility, responsive and full role/tenant
  separation evidence is not recorded.
- Private validation with real portfolio data is not documented as complete.

## Immediate priority

Pin the validated Flutter, Supabase CLI and Deno versions across local guidance,
CI and Alpha deployment, then implement TC-000 end to end. Do not infer overall
Alpha readiness from the number of merged implementation milestones.

The toolchain slice upgrades the official checkout action and the Hostinger FTP
deployment action to their Node.js 24 releases. CI must verify the exact pinned
Flutter, Supabase CLI and Deno versions before this baseline is accepted.
