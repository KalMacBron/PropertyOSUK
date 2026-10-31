# KaelVaren UI foundation

Status: approved for PropertyOS Alpha on 9 August 2026.

PropertyOS uses the KaelVaren suite visual language: deep navy operational
navigation, warm amber accents, cool-grey workspaces, white bordered surfaces,
editorial headings and neutral sans-serif interface copy.

## Core tokens

- Deep navy: `#071F2F`; primary navy: `#0B2A3C`; selected navy: `#194A64`
- Amber: `#F2B426`; amber text: `#8A5806`; amber tint: `#FFF4D8`
- Workspace: `#F3F6F7`; border: `#D7E0E5`
- Ink: `#102B3D`; muted text: `#5B6E7D`
- Success: `#1E7A5C`; warning: `#D99A16`; critical: `#B83A3A`

Text colours meet WCAG AA (4.5:1) on white and on the workspace grey. Amber
and warning are for fills, borders and icons only, never for text. Status
colours are also available as the `StatusColours` theme extension.

Status meaning must never rely on colour alone. Use a label or icon as well.
Compliance status words come from one helper: Overdue, Due soon, Not recorded
and Current. Never use "Compliant", which implies certification.

## Typography

No custom font is bundled. Flutter Web (CanvasKit) cannot load operating-system
fonts by name, so the earlier Georgia and Arial references always rendered in
the default sans-serif and have been removed. Bundling a licensed serif for
headings is a separate design decision.

Sizes come from the theme's text scale: page titles use `displayMedium`, panel
titles `headlineSmall`, uppercase labels `PropertyOsText.eyebrow` (12px, stored
in natural case and upper-cased when shown) and body text a 1.5 line height.
Counts and money use tabular figures.

## Focus and accessibility

- Every interactive element shows a visible keyboard focus state: a 2px navy
  outline on light surfaces, amber on the navy sidebar and filled buttons.
- Page and panel titles are marked as headings for screen readers, the current
  navigation item is announced as selected and form errors are live regions.

## Layout and components

- Desktop uses a persistent suite sidebar and slim contextual top bar.
- Narrow layouts retain the same hierarchy in a drawer.
- Page headings use an uppercase operational eyebrow, a display title and
  concise supporting copy.
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
