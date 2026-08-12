# Customer Signup and Organisation Onboarding implementation contract

**Status:** Approved on 12/08/2026; implemented and locally verified, awaiting
commit/review/deployment
**Branch:** `codex/customer-signup-onboarding`

## Outcome

A new independent UK landlord can create a PropertyOS account, confirm their
email, create one isolated organisation as its Owner and optionally establish
their first ownership entity and property without administrator intervention.

## Included

- Public email/password account creation from the PropertyOS landing page.
- Name, email, password and password-confirmation validation.
- Confirmation email through the configured Supabase Auth SMTP service and an
  exact Alpha redirect URL.
- Clear confirmation, expired-link and retry guidance.
- Existing invitation acceptance takes precedence over customer organisation
  creation.
- A transactional first-organisation bootstrap that creates the organisation,
  Owner membership, protected profile selection and audit event together.
- Branded first-run steps for organisation, ownership entity and first property.
- Ownership/property steps may be skipped without creating placeholder data.
- Database and Flutter coverage for signup states, Owner bootstrap and
  cross-organisation denial.

## Security boundaries

- Email must be confirmed before customer organisation bootstrap.
- The Flutter client receives no secret or service-role credential.
- User-editable Auth metadata may seed display text only and never grants a
  role or organisation access.
- Organisation membership remains the sole access authority.
- An uninvited user may self-create only their first organisation.
- Organisation, Owner membership, profile selection and audit evidence succeed
  or fail as one database transaction.
- New exposed functions receive explicit grants; direct table access remains
  governed by the existing RLS model.

## Excluded

- Billing, subscriptions or payments.
- Social login, MFA or passkeys.
- Multiple-organisation self-service creation.
- Organisation deletion or ownership transfer.
- Legal-document authoring or portfolio import.

## Acceptance

1. A signed-out visitor can submit a valid account request and receives clear
   email-confirmation guidance without being granted organisation access.
2. An unconfirmed account cannot bootstrap an organisation.
3. A confirmed account with no membership can create exactly one organisation
   and becomes its Owner.
4. A user with an invitation joins the invited organisation rather than being
   forced through customer organisation creation.
5. The first-run journey can add an ownership entity and property or skip those
   optional steps.
6. A second bootstrap attempt and cross-organisation access are denied by the
   database.
7. Organisation creation produces an organisation-scoped audit event.

## Hosted Auth configuration required before Alpha UAT

- Enable email/password signup and require email confirmation.
- Set the Site URL to `https://alpha.propertyosuk.com/`.
- Add the exact redirect URL `https://alpha.propertyosuk.com/`.
- Keep the configured Hostinger custom SMTP sender active.
- Verify the signup confirmation email template uses the redirect target and
  lands back on the Alpha application.

## Local verification result

- Formatting completed with 99 files unchanged.
- Flutter analysis passed with no issues.
- All 78 Flutter tests passed, including landing-page signup access and local
  signup validation.
- A clean Supabase reset applied the immutable onboarding migration.
- All 16 pgTAP files and 271 assertions passed, including confirmation,
  repeat-bootstrap, audit and cross-organisation denial coverage.
