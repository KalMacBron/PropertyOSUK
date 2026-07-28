# Milestone 4 — Compliance Evidence

## Outcome

PropertyOS users can attach private PDF, JPEG and PNG evidence to an existing
compliance record, inspect it through a short-lived authorised link and remove
an incorrect attachment without changing the compliance status or dates.

## Product boundary

Evidence is managed inside the compliance register. This milestone does not add
a general document library, AI extraction, previews, sharing, versioning or
automated compliance conclusions.

## Permissions

| Action | Roles |
|---|---|
| Upload | owner, admin, member |
| View or download | owner, admin, member, viewer |
| Delete | owner, admin |

## Storage contract

- Private bucket: `property-documents`
- Maximum file size: 10 MB
- Types: `application/pdf`, `image/jpeg`, `image/png`
- Immutable path:
  `organisation/property/compliance_record/document/sanitised_filename`
- Signed links are created on demand and expire after 60 seconds.
- Object overwrite and update are disabled.
- If metadata creation fails, the just-uploaded orphan is removed.
- Existing foreign keys block compliance-record deletion while evidence remains.

## Security

Database and Storage policies validate membership, role, organisation, property
and compliance-record linkage. Malformed object paths are rejected safely before
UUID conversion. A member may delete only their own orphaned upload when no
matching metadata row exists; normal evidence deletion remains owner/admin only.

## Acceptance

The draft pull request remains unmerged until Flutter checks, database policy
verification, Alpha deployment and Karl's upload/view/delete/persistence tests
have passed.
