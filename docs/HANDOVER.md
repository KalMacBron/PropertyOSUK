# PropertyOS Codex Handover

**Baseline reviewed:** 11/08/2026
**Repository source of truth:** `KalMacBron/PropertyOSUK`
**Baseline `main`:** `79a0ec1` — *Merge PR #39: Maintenance Alpha*
**Active implementation:** `codex/contractor-directory` — bounded Contractor
Directory and in-flow creation follow-up approved and in progress

This is the entry point for a new PropertyOS engineering session. GitHub is the
source of truth for code. The frozen Alpha boundary remains
`PropertyOS_Alpha_Build_Specification.md`; this handover set records the later
implementation and operational state without silently changing that scope.

## Read in this order

1. `../AGENTS.md` — engineering rules and approval gates.
2. [Project context](PROJECT_CONTEXT.md) — product purpose and boundaries.
3. [Current state](CURRENT_STATE.md) — source, deployment, defect and gaps.
4. [Engineering runbook](ENGINEERING_RUNBOOK.md) — setup, checks and release flow.
5. [Roadmap](ROADMAP.md) — current direction and deferred candidates.
6. [Alpha build specification](PropertyOS_Alpha_Build_Specification.md) — frozen
   Alpha scope and acceptance criteria.

## Supporting design and test material

- [Architecture decision 0001](Architecture_Decisions/0001_Flutter_Supabase.md)
- [Compliance register](Milestone_3_Property_Compliance_Register.md)
- [Compliance evidence](Milestone_4_Compliance_Evidence.md)
- [Multi-agent workflow](Codex_Multi_Agent_Development_Workflow.md)
- `testing/PropertyOS_Alpha_Test_Strategy.docx`
- `testing/PropertyOS_Alpha_Test_Cases.xlsx`

The test strategy and tracker originated as planning artefacts on 27/07/2026. Their
milestone numbering and statements such as “no software has been built” are
historical, not current-state evidence. TC-000 now records a local automated
`Pass`; all other tracker rows retain their existing execution state.

## Current handoff

TC-000, Tasks, SaaS Foundations 1 and 2, Viewer Read-Only Hardening and
Tenancies Alpha and its editing follow-up are merged. The hosted Alpha is at
`79a0ec1`; both Tenancies migrations are applied and Karl has accepted creation,
editing, historical correction and reopening. Property Dashboard PR #38 passed
pre-merge and post-merge CI, deployed successfully, and was accepted by Karl on
11/08/2026. Maintenance Alpha PR #39 passed CI, was merged, migrated and
deployed, and Karl accepted the screen and workflow. The active bounded
follow-up adds a Contractor Directory and in-form contractor creation while
keeping contractor portals, dispatch and messaging outside Alpha scope.

## First-session verification

Before changing the product:

```text
Read AGENTS.md and docs/HANDOVER.md, including each linked baseline document.
Do not modify code yet.

Confirm the repository head and worktree, fetch the Alpha version metadata,
summarise the product boundary, architecture, delivered increments, known
defects, acceptance gaps and required checks, then recommend the smallest
evidence-backed change. Treat user-reported UAT failures as open until retested.
```

## Secrets and real data

Never commit Supabase secrets, FTP credentials, OpenAI credentials, `.env`
files, real tenant identity data or real portfolio documents. The browser-safe
Supabase publishable key is injected at build time. Server credentials belong
only in server-side environment secrets.
