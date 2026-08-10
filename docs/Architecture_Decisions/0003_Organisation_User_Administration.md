# ADR 0003: Organisation user administration

**Status:** Accepted for SaaS Foundation 2 on 10/08/2026

## Decision

- User access belongs to an organisation membership and is independent of the
  legal ownership entities attached to properties.
- Owners can invite admins, members and viewers and administer all membership
  roles. Admins can invite and administer members and viewers only.
- Owners cannot be created by invitation. Ownership transfer requires an
  explicit role change by an existing owner, and the database prevents the
  final owner being demoted or removed.
- Invitations are organisation-scoped, expire after seven days and have
  pending, accepted, revoked or failed states.
- Supabase Auth invitation email is sent only by an Edge Function holding the
  server secret. The Flutter client never receives privileged credentials.
- An authenticated user accepts matching invitations using the email held by
  Supabase Auth. User-editable JWT metadata is not used for authorisation.
- Membership administration writes to a dedicated organisation audit log. The
  property timeline remains property-specific.
- MFA and account recovery remain a later User Management milestone.

## Consequences

Tenancies and later workflows can use the shared owner/admin/member/viewer
matrix. Fine-grained property permissions are intentionally deferred.
