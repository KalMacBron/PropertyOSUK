create or replace function public.list_organisation_users(target_organisation_id uuid)
returns table (
  record_type text,
  record_id uuid,
  email text,
  display_name text,
  role public.member_role,
  state text,
  created_at timestamptz,
  expires_at timestamptz,
  is_current_user boolean
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not public.has_organisation_role(
    target_organisation_id,
    array['owner','admin']::public.member_role[]
  ) then
    raise exception using errcode = '42501', message = 'user_admin_forbidden';
  end if;

  return query
  select 'member', member.user_id, lower(user_record.email), profile.display_name,
    member.role, 'active', member.created_at, null::timestamptz,
    member.user_id = auth.uid()
  from public.organisation_members member
  join auth.users user_record on user_record.id = member.user_id
  left join public.profiles profile on profile.user_id = member.user_id
  where member.organisation_id = target_organisation_id
  union all
  select 'invitation', invitation.id, invitation.email, null, invitation.role,
    case when invitation.state = 'pending' and invitation.expires_at <= now()
      then 'expired' else invitation.state::text end,
    invitation.created_at, invitation.expires_at, false
  from public.organisation_invitations invitation
  where invitation.organisation_id = target_organisation_id
    and invitation.state <> 'accepted'
  order by created_at desc;
end;
$$;

revoke all on function public.list_organisation_users(uuid) from public, anon;
grant execute on function public.list_organisation_users(uuid) to authenticated;
