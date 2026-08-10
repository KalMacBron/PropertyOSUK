create type public.invitation_state as enum ('pending', 'accepted', 'revoked', 'failed');

create table public.organisation_invitations (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  email text not null check (email = lower(trim(email)) and email like '%@%'),
  role public.member_role not null check (role <> 'owner'),
  state public.invitation_state not null default 'pending',
  invited_by uuid not null references auth.users(id),
  expires_at timestamptz not null default now() + interval '7 days',
  accepted_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index organisation_invitations_pending_email_idx
  on public.organisation_invitations (organisation_id, email)
  where state = 'pending';
create index organisation_invitations_organisation_idx
  on public.organisation_invitations (organisation_id, created_at desc);

create trigger organisation_invitations_updated_at
before update on public.organisation_invitations
for each row execute function public.set_updated_at();

alter table public.organisation_invitations enable row level security;
revoke all on public.organisation_invitations from anon, authenticated;

create table public.organisation_audit_events (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  event_type text not null,
  title text not null,
  description text,
  source_type text not null,
  source_id uuid,
  actor_user_id uuid references auth.users(id),
  occurred_at timestamptz not null default now()
);
create index organisation_audit_events_organisation_idx
  on public.organisation_audit_events (organisation_id, occurred_at desc);
alter table public.organisation_audit_events enable row level security;
create policy organisation_audit_select_admin on public.organisation_audit_events
for select to authenticated using (public.has_organisation_role(
  organisation_id,array['owner','admin']::public.member_role[]));
revoke all on public.organisation_audit_events from anon;
grant select on public.organisation_audit_events to authenticated;

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
  order by created_at desc;
end;
$$;

create or replace function public.create_organisation_invitation(
  target_organisation_id uuid,
  invited_email text,
  invited_role public.member_role
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_role public.member_role;
  invitation_id uuid;
  normalised_email text := lower(trim(invited_email));
begin
  select role into actor_role from public.organisation_members
  where organisation_id = target_organisation_id and user_id = auth.uid();
  if actor_role is null or actor_role not in ('owner','admin') then
    raise exception using errcode = '42501', message = 'invitation_forbidden';
  end if;
  if invited_role = 'owner' or (actor_role = 'admin' and invited_role = 'admin') then
    raise exception using errcode = '42501', message = 'invitation_role_forbidden';
  end if;
  if normalised_email !~ '^[^@[:space:]]+@[^@[:space:]]+[.][^@[:space:]]+$' then
    raise exception using errcode = '22023', message = 'invitation_email_invalid';
  end if;
  if exists (
    select 1 from public.organisation_members member
    join auth.users user_record on user_record.id = member.user_id
    where member.organisation_id = target_organisation_id
      and lower(user_record.email) = normalised_email
  ) then
    raise exception using errcode = '23505', message = 'user_already_member';
  end if;

  insert into public.organisation_invitations
    (organisation_id, email, role, invited_by)
  values (target_organisation_id, normalised_email, invited_role, auth.uid())
  on conflict (organisation_id, email) where state = 'pending'
  do update set role = excluded.role, invited_by = excluded.invited_by,
    expires_at = now() + interval '7 days', updated_at = now()
  returning id into invitation_id;
  insert into public.organisation_audit_events (organisation_id,event_type,title,description,source_type,source_id,actor_user_id)
  values (target_organisation_id,'member_invited','User invited',normalised_email || ' invited as ' || invited_role::text,'organisation_invitation',invitation_id,auth.uid());
  return invitation_id;
end;
$$;

create or replace function public.revoke_organisation_invitation(target_invitation_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare invitation record; actor_role public.member_role;
begin
  select * into invitation from public.organisation_invitations where id = target_invitation_id;
  if not found then raise exception using errcode='P0002', message='invitation_missing'; end if;
  select role into actor_role from public.organisation_members
    where organisation_id=invitation.organisation_id and user_id=auth.uid();
  if actor_role is null or actor_role not in ('owner','admin')
    or (actor_role='admin' and invitation.role='admin') then
    raise exception using errcode='42501', message='invitation_revoke_forbidden';
  end if;
  update public.organisation_invitations set state='revoked', revoked_at=now()
    where id=target_invitation_id and state='pending';
  insert into public.organisation_audit_events (organisation_id,event_type,title,description,source_type,source_id,actor_user_id)
  values (invitation.organisation_id,'member_invitation_revoked','User invitation revoked',invitation.email,'organisation_invitation',invitation.id,auth.uid());
end; $$;

create or replace function public.accept_my_organisation_invitations()
returns integer language plpgsql security definer set search_path = '' as $$
declare actor_email text; accepted_count integer; invitation record;
begin
  if auth.uid() is null then raise exception using errcode='42501', message='authentication_required'; end if;
  select lower(email) into actor_email from auth.users where id=auth.uid();
  accepted_count := 0;
  for invitation in update public.organisation_invitations set state='accepted', accepted_at=now()
    where email=actor_email and state='pending' and expires_at>now()
    returning id,organisation_id,role
  loop
    insert into public.organisation_members (organisation_id,user_id,role)
    values (invitation.organisation_id,auth.uid(),invitation.role)
    on conflict (organisation_id,user_id) do nothing;
    if found then accepted_count := accepted_count + 1; end if;
    insert into public.organisation_audit_events (organisation_id,event_type,title,description,source_type,source_id,actor_user_id)
    values (invitation.organisation_id,'member_joined','User joined organisation',actor_email,'organisation_invitation',invitation.id,auth.uid());
  end loop;
  return accepted_count;
end; $$;

create or replace function public.change_organisation_member_role(
  target_organisation_id uuid, target_user_id uuid, target_role public.member_role
)
returns void language plpgsql security definer set search_path = '' as $$
declare actor_role public.member_role; existing_role public.member_role;
begin
  select role into actor_role from public.organisation_members where organisation_id=target_organisation_id and user_id=auth.uid();
  select role into existing_role from public.organisation_members where organisation_id=target_organisation_id and user_id=target_user_id;
  if existing_role is null then raise exception using errcode='P0002', message='member_missing'; end if;
  if actor_role='owner' then null;
  elsif actor_role='admin' and existing_role in ('member','viewer') and target_role in ('member','viewer') then null;
  else raise exception using errcode='42501', message='role_change_forbidden'; end if;
  update public.organisation_members set role=target_role where organisation_id=target_organisation_id and user_id=target_user_id;
  insert into public.organisation_audit_events (organisation_id,event_type,title,description,source_type,source_id,actor_user_id)
  values (target_organisation_id,'member_role_changed','User role changed',existing_role::text || ' to ' || target_role::text,'organisation_member',target_user_id,auth.uid());
end; $$;

create or replace function public.remove_organisation_member(
  target_organisation_id uuid, target_user_id uuid
)
returns void language plpgsql security definer set search_path = '' as $$
declare actor_role public.member_role; existing_role public.member_role;
begin
  select role into actor_role from public.organisation_members where organisation_id=target_organisation_id and user_id=auth.uid();
  select role into existing_role from public.organisation_members where organisation_id=target_organisation_id and user_id=target_user_id;
  if existing_role is null then raise exception using errcode='P0002', message='member_missing'; end if;
  if actor_role='owner' then null;
  elsif actor_role='admin' and existing_role in ('member','viewer') then null;
  else raise exception using errcode='42501', message='member_remove_forbidden'; end if;
  delete from public.organisation_members where organisation_id=target_organisation_id and user_id=target_user_id;
  insert into public.organisation_audit_events (organisation_id,event_type,title,description,source_type,source_id,actor_user_id)
  values (target_organisation_id,'member_removed','User access removed',existing_role::text,'organisation_member',target_user_id,auth.uid());
end; $$;

revoke all on function public.list_organisation_users(uuid) from public,anon;
revoke all on function public.create_organisation_invitation(uuid,text,public.member_role) from public,anon;
revoke all on function public.revoke_organisation_invitation(uuid) from public,anon;
revoke all on function public.accept_my_organisation_invitations() from public,anon;
revoke all on function public.change_organisation_member_role(uuid,uuid,public.member_role) from public,anon;
revoke all on function public.remove_organisation_member(uuid,uuid) from public,anon;
grant execute on function public.list_organisation_users(uuid), public.create_organisation_invitation(uuid,text,public.member_role), public.revoke_organisation_invitation(uuid), public.accept_my_organisation_invitations(), public.change_organisation_member_role(uuid,uuid,public.member_role), public.remove_organisation_member(uuid,uuid) to authenticated;
