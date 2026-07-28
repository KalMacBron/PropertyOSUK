-- Milestone 4: expose evidence metadata to the authenticated Data API.
-- RLS remains the authorization boundary for every operation.

begin;

grant select, insert, delete on public.documents to authenticated;
revoke update on public.documents from authenticated;
revoke all on public.documents from anon;

commit;
