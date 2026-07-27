# ADR 0001: Flutter and Supabase for the PropertyOS Alpha

**Status:** Accepted  
**Date:** 2026-07-27

## Context

PropertyOS needs a private, database-backed web Alpha that can later target iOS
and Android without introducing infrastructure beyond the needs of validation.

## Decision

Use Flutter for the client and Supabase for authentication, PostgreSQL, private
object storage and server-side functions.

Use database Row-Level Security for organisation isolation. Keep deterministic
Today and compliance rules in SQL or tested application logic. Call external AI
services only from server-side functions.

## Consequences

- One client codebase can later support web and mobile.
- PostgreSQL remains portable and inspectable.
- Security depends on complete RLS policies and tests.
- Flutter Web suitability must be reassessed after real Alpha usage.
- No decision has been made to use AWS for the Alpha.

