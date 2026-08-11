-- Contractor Directory: organisation-authorised contractor creation and
-- maintenance without exposing direct client writes or breaking historical
-- maintenance references.

drop policy if exists contractors_write on public.contractors;

revoke insert, update, delete on public.contractors from authenticated;
grant select on public.contractors to authenticated;

create or replace function public.create_contractor(
  target_organisation_id uuid,
  contractor_name text,
  contractor_trade text default null,
  contractor_email text default null,
  contractor_phone text default null,
  contractor_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  created_id uuid;
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'authentication_required';
  end if;
  if not public.has_organisation_role(
    target_organisation_id,
    array['owner','admin','member']::public.member_role[]
  ) then
    raise exception using errcode = '42501', message = 'contractor_write_forbidden';
  end if;
  if nullif(btrim(contractor_name), '') is null then
    raise exception using errcode = '22023', message = 'contractor_name_required';
  end if;
  if char_length(btrim(contractor_name)) > 160
    or char_length(coalesce(btrim(contractor_trade), '')) > 120
    or char_length(coalesce(btrim(contractor_email), '')) > 320
    or char_length(coalesce(btrim(contractor_phone), '')) > 80
    or char_length(coalesce(btrim(contractor_notes), '')) > 2000 then
    raise exception using errcode = '22023', message = 'contractor_value_too_long';
  end if;

  insert into public.contractors (
    organisation_id, name, trade, email, phone, notes, status, created_by
  ) values (
    target_organisation_id,
    btrim(contractor_name),
    nullif(btrim(contractor_trade), ''),
    lower(nullif(btrim(contractor_email), '')),
    nullif(btrim(contractor_phone), ''),
    nullif(btrim(contractor_notes), ''),
    'active',
    actor_id
  ) returning id into created_id;
  return created_id;
end;
$$;

create or replace function public.update_contractor(
  target_contractor_id uuid,
  contractor_name text,
  contractor_trade text default null,
  contractor_email text default null,
  contractor_phone text default null,
  contractor_notes text default null,
  contractor_status public.record_status default 'active'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  contractor_record record;
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'authentication_required';
  end if;
  select contractor.id, contractor.organisation_id
  into contractor_record
  from public.contractors contractor
  where contractor.id = target_contractor_id
    and public.has_organisation_role(
      contractor.organisation_id,
      array['owner','admin','member']::public.member_role[]
    );
  if not found then
    raise exception using errcode = 'P0002', message = 'contractor_unavailable';
  end if;
  if nullif(btrim(contractor_name), '') is null then
    raise exception using errcode = '22023', message = 'contractor_name_required';
  end if;
  if char_length(btrim(contractor_name)) > 160
    or char_length(coalesce(btrim(contractor_trade), '')) > 120
    or char_length(coalesce(btrim(contractor_email), '')) > 320
    or char_length(coalesce(btrim(contractor_phone), '')) > 80
    or char_length(coalesce(btrim(contractor_notes), '')) > 2000 then
    raise exception using errcode = '22023', message = 'contractor_value_too_long';
  end if;

  update public.contractors
  set name = btrim(contractor_name),
      trade = nullif(btrim(contractor_trade), ''),
      email = lower(nullif(btrim(contractor_email), '')),
      phone = nullif(btrim(contractor_phone), ''),
      notes = nullif(btrim(contractor_notes), ''),
      status = contractor_status,
      updated_at = now()
  where id = target_contractor_id;
  return target_contractor_id;
end;
$$;

revoke all on function public.create_contractor(
  uuid,text,text,text,text,text
) from public, anon;
revoke all on function public.update_contractor(
  uuid,text,text,text,text,text,public.record_status
) from public, anon;
grant execute on function public.create_contractor(
  uuid,text,text,text,text,text
) to authenticated;
grant execute on function public.update_contractor(
  uuid,text,text,text,text,text,public.record_status
) to authenticated;
