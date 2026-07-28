-- Limit the authenticated API role to the operations exposed by the
-- compliance-evidence repository. TRUNCATE bypasses row-level security, so
-- inherited table privileges must be removed before the required CRUD grants
-- are restored.
revoke all privileges on table public.documents from authenticated;
grant select, insert, delete on table public.documents to authenticated;

revoke all privileges on table public.documents from anon;
