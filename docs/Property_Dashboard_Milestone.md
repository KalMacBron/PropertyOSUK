# Property Dashboard milestone

**Contract approved:** 10/08/2026
**Status:** Implementation and local verification complete; awaiting review

## Outcome

Selecting a property from the portfolio index opens a property-scoped
operational dashboard. It provides a quick view of existing compliance,
tenancy, task, expense and timeline records without introducing a new business
domain or changing confirmed source facts.

## Included

- Routed property dashboard at `/properties/:propertyId`.
- Property identity, address, type, bedrooms and declared ownership summary.
- Deterministic compliance counts with property-and-status drill-downs.
- Current, upcoming or most recent historical tenancy summary.
- Open, overdue and recently completed task summaries.
- Current-calendar-year expense total and recent property expenses.
- Existing property timeline events.
- Writer quick actions with property preselection; Viewer remains read-only.
- Safe unavailable state for unknown, inactive or cross-organisation property
  identifiers.

## Excluded

Property editing or deletion, maintenance data, charts, valuation, mortgages,
yield, arrears, tax analysis, new compliance claims and additional tenant
personal information remain outside this milestone.

## Acceptance

- Selecting a property opens the matching dashboard.
- Each summary includes only the selected property and drills into its source
  workspace with the property filter preserved.
- Task, expense and tenancy create actions preselect the property for writers.
- A failure in one summary does not blank the other dashboard sections.
- Viewer sees no create actions.
- An unavailable property identifier does not disclose another organisation's
  data.
