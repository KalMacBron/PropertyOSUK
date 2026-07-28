# Codex Multi-Agent Development Workflow

## Purpose

PropertyOS uses a small Codex specialist team to improve implementation quality while Karl remains Product Owner and final approval authority.

GitHub remains the source of truth for code. Hermes remains KaelVaren's knowledge and operations system; it does not orchestrate PropertyOS code changes.

## Team

| Role | Primary responsibility | Default access |
|---|---|---|
| Primary agent | Coordinates the milestone, reconciles specialist outputs and reports decisions to Karl | Inherits the active session |
| Product Lead | Requirements, acceptance criteria, exclusions and user journeys | Read-only |
| Solution Architect | Architecture, data boundaries and material decisions | Read-only |
| Flutter Engineer | Application implementation and focused fixes | Workspace write |
| Supabase Engineer | Migrations, RLS, Storage and data contracts | Workspace write |
| QA Engineer | Test coverage, regressions and Alpha acceptance journeys | Read-only |
| Security Reviewer | Auth, authorization, tenant isolation, secrets and data exposure | Read-only |
| Release Manager | CI, deployment evidence and PR readiness | Read-only |

## Operating model

1. Karl approves the milestone objective and boundary.
2. The primary agent delegates independent discovery to Product Lead and Solution Architect.
3. The primary agent produces one implementation contract and identifies approval decisions.
4. One write-enabled implementation owner works at a time.
5. QA and Security review the completed change independently.
6. The implementation owner addresses verified findings.
7. Release Manager checks the exact branch head, CI, Alpha deployment and unresolved findings.
8. Karl performs user acceptance and approves movement from draft to ready.
9. Karl approves merge into `main`.
10. Production deployment requires separate explicit approval.

Parallel work should be read-heavy. Flutter Engineer and Supabase Engineer must not edit overlapping files concurrently. The primary agent decides sequencing when a feature crosses both areas.

## Karl approval gates

Stop and request approval before:

- changing an approved milestone's scope or exclusions;
- adopting a new service, framework, major dependency or architectural pattern;
- destructive migrations, existing-data transformations or material data-model changes;
- moving a pull request from draft to ready;
- merging into `main`;
- creating or changing the production environment;
- deploying to production;
- accepting an unresolved high-severity security issue.

Routine formatting, analysis fixes, test corrections, documentation alignment and Alpha deployment may proceed within an approved milestone.

## Standard milestone prompt

Use this prompt after Karl approves a milestone:

```text
Use the PropertyOS multi-agent workflow for this milestone.

Have product_lead and solution_architect independently review the approved scope. Wait for both and produce one implementation contract, highlighting any decision that requires my approval.

After I approve the contract, use one write-enabled implementation owner at a time. When implementation and checks are complete, have qa_engineer and security_reviewer review the exact branch diff in parallel. Address verified findings, then have release_manager perform the final PR-readiness check.

Keep the PR draft. Do not merge into main or deploy to production without my explicit approval.
```

## Review-only prompt

```text
Review the current branch against main using the PropertyOS specialist agents. Have solution_architect review maintainability and boundaries, qa_engineer review behavior and test gaps, and security_reviewer review security and tenant isolation. Wait for all three, then consolidate findings by severity with file references. Do not edit code.
```

## Success criteria

The workflow is useful only if it improves release confidence without slowing delivery. Reassess it after Milestones 4 and 5 using:

- defects found before Karl's Alpha acceptance;
- rework caused by unclear handoffs;
- time from approved milestone to testable Alpha;
- token/runtime overhead;
- conflicts or duplicated investigation;
- whether every approval gate remained visible.
