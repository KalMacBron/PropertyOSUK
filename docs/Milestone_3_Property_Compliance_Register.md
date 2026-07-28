# Milestone 3: Property Compliance Register

Milestone 3 introduces PropertyOS's first portfolio-wide compliance workflow.

## Tracked categories

- Gas Safety
- Electrical Installation Condition Report (EICR)
- Energy Performance Certificate (EPC)
- Smoke alarms
- Carbon monoxide alarms

## Status rules

- **Not recorded**: no record or applicable expiry/review date
- **Overdue**: applicable date is before today
- **Due soon**: applicable date is today or within 30 days
- **Compliant**: applicable date is more than 30 days away

These are operational tracking statuses. They do not certify legal compliance.

## Security model

Records are scoped by `organisation_id` and property. Row-level security permits
authenticated organisation members to manage only records belonging to their
organisation. Requirement types must be global system types or belong to the same
organisation as the compliance record.
