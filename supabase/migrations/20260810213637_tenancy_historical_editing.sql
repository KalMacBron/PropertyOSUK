-- Audit-safe corrections and explicit reopening for historical tenancies.

create function public.correct_historical_tenancy(
  target_tenancy_id uuid,
  target_property_id uuid,
  tenant_display_name text,
  tenancy_start_date date,
  tenancy_fixed_term_end_date date default null,
  tenancy_monthly_rent_pence integer default null,
  tenancy_rent_due_day smallint default null,
  tenancy_actual_end_date date default null
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  tenancy_record record;
  lead_tenant_id uuid;
  changed_fields text[];
  event_metadata jsonb;
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'authentication_required';
  end if;
  if nullif(btrim(tenant_display_name), '') is null then
    raise exception using errcode = '22023', message = 'tenant_display_name_required';
  end if;
  if tenancy_start_date is null then
    raise exception using errcode = '22023', message = 'tenancy_start_date_required';
  end if;
  if tenancy_fixed_term_end_date is not null
    and tenancy_fixed_term_end_date < tenancy_start_date then
    raise exception using errcode = '22023', message = 'tenancy_end_before_start';
  end if;
  if tenancy_actual_end_date is null
    or tenancy_actual_end_date < tenancy_start_date then
    raise exception using errcode = '22023', message = 'tenancy_actual_end_invalid';
  end if;
  if tenancy_monthly_rent_pence is not null and tenancy_monthly_rent_pence < 0 then
    raise exception using errcode = '22023', message = 'tenancy_rent_invalid';
  end if;
  if tenancy_rent_due_day is not null
    and tenancy_rent_due_day not between 1 and 28 then
    raise exception using errcode = '22023', message = 'tenancy_rent_due_day_invalid';
  end if;

  select tenancy.* into tenancy_record
  from public.tenancies tenancy
  where tenancy.id = target_tenancy_id
  for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'tenancy_missing';
  end if;
  if not public.has_organisation_role(
    tenancy_record.organisation_id,
    array['owner','admin','member']::public.member_role[]
  ) then
    raise exception using errcode = '42501', message = 'tenancy_correction_forbidden';
  end if;
  if tenancy_record.actual_end_date is null or tenancy_record.status <> 'archived' then
    raise exception using errcode = '22023', message = 'tenancy_not_historical';
  end if;
  if not exists (
    select 1 from public.properties property
    where property.id = target_property_id
      and property.organisation_id = tenancy_record.organisation_id
      and property.status = 'active'
  ) then
    raise exception using errcode = '23503', message = 'tenancy_property_missing';
  end if;

  select link.tenant_id into lead_tenant_id
  from public.tenancy_tenants link
  where link.tenancy_id = target_tenancy_id
    and link.organisation_id = tenancy_record.organisation_id
    and link.is_lead
  order by link.created_at, link.tenant_id
  limit 1;
  if lead_tenant_id is null then
    raise exception using errcode = 'P0002', message = 'tenancy_lead_tenant_missing';
  end if;

  changed_fields := array_remove(array[
    case when tenancy_record.property_id is distinct from target_property_id then 'property' end,
    case when tenancy_record.start_date is distinct from tenancy_start_date then 'start_date' end,
    case when tenancy_record.fixed_term_end_date is distinct from tenancy_fixed_term_end_date then 'fixed_term_end_date' end,
    case when tenancy_record.actual_end_date is distinct from tenancy_actual_end_date then 'actual_end_date' end,
    case when tenancy_record.monthly_rent_pence is distinct from tenancy_monthly_rent_pence then 'monthly_rent' end,
    case when tenancy_record.rent_due_day is distinct from tenancy_rent_due_day then 'rent_due_day' end,
    case when (select tenant.display_name from public.tenants tenant where tenant.id = lead_tenant_id)
      is distinct from btrim(tenant_display_name) then 'tenant_display_name' end
  ], null);
  if cardinality(changed_fields) = 0 then
    return target_tenancy_id;
  end if;

  update public.tenants
  set display_name = btrim(tenant_display_name)
  where id = lead_tenant_id and organisation_id = tenancy_record.organisation_id;
  update public.tenancies
  set property_id = target_property_id,
      start_date = tenancy_start_date,
      fixed_term_end_date = tenancy_fixed_term_end_date,
      actual_end_date = tenancy_actual_end_date,
      monthly_rent_pence = tenancy_monthly_rent_pence,
      rent_due_day = tenancy_rent_due_day
  where id = target_tenancy_id;

  event_metadata := jsonb_build_object(
    'changed_fields', to_jsonb(changed_fields),
    'old_property_id', tenancy_record.property_id,
    'property_id', target_property_id,
    'start_date', tenancy_start_date,
    'fixed_term_end_date', tenancy_fixed_term_end_date,
    'actual_end_date', tenancy_actual_end_date,
    'monthly_rent_pence', tenancy_monthly_rent_pence,
    'rent_due_day', tenancy_rent_due_day
  );
  insert into public.timeline_events (
    organisation_id, property_id, event_type, title, description,
    source_type, source_id, metadata, actor_user_id
  ) values (
    tenancy_record.organisation_id, tenancy_record.property_id,
    'tenancy_corrected', 'Historical tenancy corrected',
    btrim(tenant_display_name), 'tenancy', target_tenancy_id,
    event_metadata, actor_id
  );
  if tenancy_record.property_id is distinct from target_property_id then
    insert into public.timeline_events (
      organisation_id, property_id, event_type, title, description,
      source_type, source_id, metadata, actor_user_id
    ) values (
      tenancy_record.organisation_id, target_property_id,
      'tenancy_corrected', 'Historical tenancy moved to this property',
      btrim(tenant_display_name), 'tenancy', target_tenancy_id,
      event_metadata, actor_id
    );
  end if;
  return target_tenancy_id;
end;
$$;

create function public.reopen_tenancy(target_tenancy_id uuid)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  tenancy_record record;
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'authentication_required';
  end if;
  select tenancy.* into tenancy_record
  from public.tenancies tenancy
  where tenancy.id = target_tenancy_id
  for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'tenancy_missing';
  end if;
  if not public.has_organisation_role(
    tenancy_record.organisation_id,
    array['owner','admin','member']::public.member_role[]
  ) then
    raise exception using errcode = '42501', message = 'tenancy_reopen_forbidden';
  end if;
  if tenancy_record.actual_end_date is null or tenancy_record.status <> 'archived' then
    raise exception using errcode = '22023', message = 'tenancy_not_historical';
  end if;

  update public.tenancies
  set actual_end_date = null, status = 'active'
  where id = target_tenancy_id;
  insert into public.timeline_events (
    organisation_id, property_id, event_type, title, description,
    source_type, source_id, metadata, actor_user_id
  ) values (
    tenancy_record.organisation_id, tenancy_record.property_id,
    'tenancy_reopened', 'Tenancy reopened',
    'Previous actual end date removed after confirmation.',
    'tenancy', target_tenancy_id,
    jsonb_build_object('previous_actual_end_date', tenancy_record.actual_end_date),
    actor_id
  );
  return target_tenancy_id;
end;
$$;

revoke all on function public.correct_historical_tenancy(uuid,uuid,text,date,date,integer,smallint,date) from public, anon;
revoke all on function public.reopen_tenancy(uuid) from public, anon;
grant execute on function public.correct_historical_tenancy(uuid,uuid,text,date,date,integer,smallint,date) to authenticated;
grant execute on function public.reopen_tenancy(uuid) to authenticated;
