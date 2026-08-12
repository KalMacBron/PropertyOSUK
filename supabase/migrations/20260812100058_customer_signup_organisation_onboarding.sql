create or replace function public.bootstrap_customer_organisation(
  organisation_name text,
  organisation_slug text,
  customer_display_name text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  actor_confirmed_at timestamptz;
  new_id uuid;
  clean_name text := trim(organisation_name);
  clean_slug text := lower(trim(organisation_slug));
  clean_display_name text := nullif(trim(customer_display_name), '');
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'authentication_required';
  end if;

  select user_record.email_confirmed_at into actor_confirmed_at
  from auth.users user_record
  where user_record.id = actor_id;
  if actor_confirmed_at is null then
    raise exception using errcode = '42501', message = 'email_confirmation_required';
  end if;

  if clean_name = '' or length(clean_name) > 120 then
    raise exception using errcode = '22023', message = 'organisation_name_invalid';
  end if;
  if clean_slug !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' then
    raise exception using errcode = '22023', message = 'organisation_slug_invalid';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('customer-bootstrap:' || actor_id::text, 0));
  if exists (
    select 1 from public.organisation_members membership
    where membership.user_id = actor_id
  ) then
    raise exception using errcode = '42501', message = 'workspace_creation_controlled';
  end if;

  insert into public.organisations (name, slug, created_by)
  values (clean_name, clean_slug, actor_id)
  returning id into new_id;

  insert into public.organisation_members (organisation_id, user_id, role)
  values (new_id, actor_id, 'owner');

  insert into public.profiles (user_id, display_name, active_organisation_id)
  values (actor_id, clean_display_name, new_id)
  on conflict (user_id) do update
  set display_name = coalesce(excluded.display_name, public.profiles.display_name),
      active_organisation_id = excluded.active_organisation_id,
      updated_at = now();

  insert into public.organisation_audit_events (
    organisation_id, event_type, title, description, source_type,
    source_id, actor_user_id
  ) values (
    new_id, 'customer_organisation_created', 'Organisation created',
    'Customer completed self-service organisation onboarding.',
    'organisation', new_id, actor_id
  );

  return new_id;
end;
$$;

revoke all on function public.bootstrap_customer_organisation(text,text,text)
  from public, anon;
grant execute on function public.bootstrap_customer_organisation(text,text,text)
  to authenticated;

-- Preserve the established RPC signature for older clients and tests, but
-- route it through the same confirmation, audit and one-workspace boundary.
create or replace function public.create_organisation(
  organisation_name text,
  organisation_slug text
)
returns uuid
language sql
security invoker
set search_path = ''
as $$
  select public.bootstrap_customer_organisation(
    organisation_name,
    organisation_slug,
    ''
  );
$$;

revoke all on function public.create_organisation(text,text) from public, anon;
grant execute on function public.create_organisation(text,text) to authenticated;
