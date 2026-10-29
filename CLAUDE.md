# PropertyOS: Claude Code instructions

The engineering rules for this repository live in `AGENTS.md` and apply to
Claude Code exactly as they apply to Codex:

@AGENTS.md

## Starting a session

Follow the reading order in `docs/HANDOVER.md` before changing the product.
`docs/HANDOVER.md` and `docs/CURRENT_STATE.md` record a baseline from August
2026; confirm the current `main` head and the Alpha `version.json` before
relying on them.

## Multi-agent workflow in Claude Code

The Codex team in `.codex/agents/` is mirrored as Claude Code subagents in
`.claude/agents/`, using hyphenated names:

| Codex agent | Claude Code subagent | Access |
|---|---|---|
| `product_lead` | `product-lead` | Read-only |
| `solution_architect` | `solution-architect` | Read-only |
| `security_reviewer` | `security-reviewer` | Read-only |
| `qa_engineer` | `qa-engineer` | Read-only, may run checks |
| `release_manager` | `release-manager` | Read-only, may run checks |
| `flutter_engineer` | `flutter-engineer` | Write |
| `supabase_engineer` | `supabase-engineer` | Write |

`docs/Codex_Multi_Agent_Development_Workflow.md` defines the handoffs and
Karl's approval gates for both tools. When a role changes, update the Codex
TOML and the matching Claude Code file together.

## Deployment

A merge into `main` deploys the Alpha web app (and the marketing site when
`marketing/` changes) through GitHub Actions. Merging is therefore a deployment
and needs Karl's explicit approval. Hosted Supabase migrations are applied
separately and must be applied before the web build that depends on them.
