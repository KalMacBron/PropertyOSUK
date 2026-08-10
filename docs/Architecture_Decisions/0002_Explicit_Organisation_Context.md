# ADR 0002: Explicit organisation context

**Status:** Accepted for SaaS Foundation 1 on 10/08/2026

## Context

PropertyOS records are already scoped by `organisation_id`, but the Flutter
client previously selected the first membership returned by the database. That
implicit choice could not support a user belonging to multiple organisations
and would make later workspace switching vulnerable to stale client state.

## Decision

- A user may hold memberships in multiple organisations.
- The active organisation is an explicit application context, not an
  authorisation claim.
- The preferred organisation is stored on the user's RLS-protected profile.
- The database returns only live memberships and marks the preference active
  only when it still belongs to that authorised set.
- A sole membership is selected automatically. Multiple memberships without a
  valid preference require an explicit user choice.
- Organisation-scoped Riverpod providers depend on the active organisation and
  therefore reload when it changes.
- The application returns to Today after a workspace switch so record-specific
  routes from the previous workspace are not retained.
- Database RLS remains the authority. A saved organisation ID never grants
  access by itself.
- Alpha self-service bootstrap is limited to one organisation. Invitations and
  complete member administration are deferred.
- A database trigger prevents removal or demotion of the final organisation
  owner, including privileged or future membership-management paths.

## Consequences

Tenancies, Maintenance and other future workflows can depend on one explicit
workspace context without embedding a single-organisation assumption. Any new
organisation-scoped provider must watch `organisationProvider` rather than
choosing a membership independently.

Member invitations, lifecycle administration and MFA remain a later User
Management milestone and must preserve this context and RLS boundary.
