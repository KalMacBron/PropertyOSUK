# PropertyOS Codex Handover

**Baseline reviewed:** 05/08/2026  
**Repository source of truth:** `KalMacBron/PropertyOSUK`  
**Baseline repository head:** `6fd767f` — *Hotfix 9.3: Make expense delete explicit*

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

The test strategy and tracker are planning artefacts from 27/07/2026. Their
milestone numbering and statements such as “no software has been built” are
historical, not current-state evidence. The tracker has not yet recorded formal
execution of the Alpha acceptance suite.

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
