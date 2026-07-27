-- PropertyOS Alpha security hardening following Supabase advisor review.

begin;

alter function public.set_updated_at() set search_path = '';

-- Be explicit for API roles as well as PUBLIC. The membership helpers must remain
-- callable by authenticated users because RLS policies invoke them.
revoke all on function public.is_organisation_member(uuid) from anon;
revoke all on function public.has_organisation_role(uuid, public.member_role[]) from anon;
revoke all on function public.create_organisation(text, text) from anon;

commit;
