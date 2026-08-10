# KaelVaren UI foundation

Status: approved for PropertyOS Alpha on 9 August 2026.

PropertyOS uses the KaelVaren suite visual language: deep navy operational
navigation, warm amber accents, cool-grey workspaces, white bordered surfaces,
editorial serif headings and neutral sans-serif interface copy.

## Core tokens

- Deep navy: `#071F2F`; primary navy: `#0B2A3C`; selected navy: `#194A64`
- Amber: `#F2B426`; amber text: `#A76A08`
- Workspace: `#F3F6F7`; border: `#D7E0E5`
- Ink: `#102B3D`; muted text: `#718697`
- Success: `#238A68`; warning: `#D99A16`; critical: `#D65353`

Status meaning must never rely on colour alone. Use a label or icon as well.

## Layout and components

- Desktop uses a persistent suite sidebar and slim contextual top bar.
- Narrow layouts retain the same hierarchy in a drawer.
- Page headings use an uppercase operational eyebrow, serif title and concise
  supporting copy.
- Panels, tables and forms use square edges, fine borders and minimal shadow.
- Feature screens consume shared theme tokens and suite components rather than
  defining local colours.

## Product boundary

Visual changes must not invent metrics, change business rules or weaken the
Alpha's compliance disclaimers. PropertyOS wording and landlord workflows stay
distinct from other KaelVaren suite products.

## Alpha rollout

The shared `WorkspacePage` pattern is the standard feature-screen frame for
Today, Properties, Compliance, Expenses and Ownership. It constrains wide
desktop content, wraps page actions on narrow screens and keeps headings and
operational context consistent. `SuiteEmptyState` is used when a register has
no records; it must explain the next valid action without implying missing
data is compliant or complete.

Today is the portfolio summary dashboard. Its headline tiles must be derived
from confirmed organisation-scoped records and use the same status rules as
their source register. Compliance totals link to the Compliance workspace;
they are management prompts and never assertions that a property is legally
compliant.

Compliance summary links use URL status filters (`compliant`, `dueSoon`,
`overdue`, or `notRecorded`). The selected status is visibly highlighted, the
register shows only matching property requirements, and users can return to the
full register without losing the underlying data context.
