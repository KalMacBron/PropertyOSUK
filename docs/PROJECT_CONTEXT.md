# PropertyOS Project Context

## Product and commercial purpose

PropertyOS is KaelVaren's private Alpha operating system for independent UK
residential landlords, initially those managing roughly 5–50 properties. It
must earn its place by turning property records into clear daily actions and a
useful property history.

PropertyOS is KaelVaren's first commercial product. Work on other products must
not distract from validating PropertyOS with paying customers.

## Product principles

- Put **Today** and actionable decisions before data entry.
- Link important statuses and actions to evidence.
- Use deterministic rules for dates, warnings and operational status.
- Require human confirmation before AI-derived facts affect confirmed data.
- Use calm UK landlord terminology, GBP and `dd/MM/yyyy` dates.
- Minimise personal data and enforce organisation isolation.
- Prefer simple, maintainable solutions over speculative architecture.

## Product boundary

PropertyOS is not a public compliance authority, legal adviser or full
accounting product. It must operate independently of TradeOS, TradeCircle, Fire
Assessment OS and other KaelVaren products.

The frozen Alpha proposition is:

`sign in → property → compliance record → evidence → Today action → completed task → timeline`

Expense capture and receipt evidence were delivered later as a bounded Alpha
validation increment. This does not approve full accounting, rent collection,
arrears, open banking or tax advice. Any expansion of the expense feature needs
an approved scope decision.

For authoritative inclusions, exclusions and acceptance criteria, use
[PropertyOS_Alpha_Build_Specification.md](PropertyOS_Alpha_Build_Specification.md).

## Technical direction

| Concern | Current decision |
|---|---|
| Client | Flutter Web, structured for possible future mobile targets |
| State/navigation | Riverpod and GoRouter |
| Backend | Supabase Auth, PostgreSQL, private Storage and Edge Functions |
| Security | `organisation_id`, composite relationships and PostgreSQL RLS |
| AI | Server-side suggestions; no silent change to confirmed facts |
| Source | Private GitHub repository |
| Environments | Local, hosted private Alpha, production only after approval |

See [ADR 0001](Architecture_Decisions/0001_Flutter_Supabase.md) for the original
architecture rationale.
