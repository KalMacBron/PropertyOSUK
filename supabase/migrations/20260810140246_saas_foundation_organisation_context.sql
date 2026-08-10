-- SaaS Foundation 1: explicit, persisted organisation context and membership
-- invariants. The saved preference is never authority: membership is checked on
-- every read and write through RLS and these invoker functions.

alter table public.profiles
  add column active_organisation_id uuid
  references public.organisations(id) on delete set null;

revoke all on public.profiles from anon;
grant select, insert, update on public.profiles to authenticated;

create or replace function public.list_my_organisations()
returns table (
  id uuid,
  name text,
  role public.member_role,
  is_active boolean
)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    organisation.id,
    organisation.name,
    membership.role,
    profile.active_organisation_id = organisation.id
  from public.organisation_members membership
  join public.organisations organisation
    on organisation.id = membership.organisation_id
  left join public.profiles profile
    on profile.user_id = membership.user_id
  where membership.user_id = auth.uid()
  order by organisation.name, organisation.id;
$$;

create or replace function public.set_active_organisation(
  target_organisation_id uuid
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'authentication_required';
  end if;

  if not public.is_organisation_member(target_organisation_id) then
    raise exception using errcode = '42501', message = 'organisation_access_denied';
  end if;

  insert into public.profiles (user_id, active_organisation_id)
  values (auth.uid(), target_organisation_id)
  on conflict (user_id) do update
  set active_organisation_id = excluded.active_organisation_id;
end;
$$;

-- Alpha users may bootstrap one workspace only. Additional memberships are
-- controlled membership operations, not self-created organisations.
create or replace function public.create_organisation(
  organisation_name text,
  organisation_slug text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  new_id uuid;
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'authentication_required';
  end if;

  if exists (
    select 1
    from public.organisation_members membership
    where membership.user_id = actor_id
  ) then
    raise exception using errcode = '42501', message = 'workspace_creation_controlled';
  end if;

  insert into public.organisations (name, slug, created_by)
  values (trim(organisation_name), lower(trim(organisation_slug)), actor_id)
  returning id into new_id;

  insert into public.organisation_members (organisation_id, user_id, role)
  values (new_id, actor_id, 'owner');

  insert into public.profiles (user_id, active_organisation_id)
  values (actor_id, new_id)
  on conflict (user_id) do update
  set active_organisation_id = excluded.active_organisation_id;

  return new_id;
end;
$$;

create or replace function public.protect_last_organisation_owner()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  target_organisation_id uuid := old.organisation_id;
begin
  if old.role <> 'owner'
    or (tg_op = 'UPDATE' and new.role = 'owner') then
    return case when tg_op = 'DELETE' then old else new end;
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended('organisation-owner:' || target_organisation_id::text, 0)
  );

  if not exists (
    select 1
    from public.organisation_members membership
    where membership.organisation_id = target_organisation_id
      and membership.user_id <> old.user_id
      and membership.role = 'owner'
  ) then
    raise exception using errcode = '23514', message = 'organisation_requires_owner';
  end if;

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

create trigger organisation_members_protect_last_owner
before update of role or delete on public.organisation_members
for each row execute function public.protect_last_organisation_owner();

revoke all on function public.list_my_organisations() from public, anon;
grant execute on function public.list_my_organisations() to authenticated;

revoke all on function public.set_active_organisation(uuid) from public, anon;
grant execute on function public.set_active_organisation(uuid) to authenticated;

revoke all on function public.create_organisation(text, text) from public, anon;
grant execute on function public.create_organisation(text, text) to authenticated;

revoke all on function public.protect_last_organisation_owner() from public, anon, authenticated;
