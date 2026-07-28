begin;

alter table public.documents
  add constraint documents_id_organisation_id_key unique (id, organisation_id);

create table public.certificate_analyses (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  property_id uuid not null,
  compliance_record_id uuid not null,
  document_id uuid not null,
  requested_by uuid not null references auth.users(id),
  idempotency_key uuid not null,
  status text not null default 'reserved'
    check (status in ('reserved', 'completed', 'failed', 'confirmed')),
  model text,
  schema_version integer not null default 1,
  suggestions jsonb not null default '{}'::jsonb,
  confirmed_values jsonb not null default '{}'::jsonb,
  failure_code text,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  confirmed_at timestamptz,
  confirmed_by uuid references auth.users(id),
  unique (requested_by, idempotency_key),
  foreign key (property_id, organisation_id)
    references public.properties(id, organisation_id),
  foreign key (compliance_record_id, organisation_id)
    references public.property_compliance_records(id, organisation_id),
  foreign key (document_id, organisation_id)
    references public.documents(id, organisation_id) on delete cascade
);

create index certificate_analyses_organisation_created_idx
  on public.certificate_analyses (organisation_id, created_at desc);
create index certificate_analyses_document_idx
  on public.certificate_analyses (document_id, created_at desc);

alter table public.certificate_analyses enable row level security;

create policy certificate_analyses_select
on public.certificate_analyses
for select
to authenticated
using (public.is_organisation_member(organisation_id));

revoke all privileges on table public.certificate_analyses from public, anon, authenticated;
grant select on table public.certificate_analyses to authenticated;

create or replace function public.reserve_certificate_analysis(
  target_organisation_id uuid,
  target_property_id uuid,
  target_compliance_record_id uuid,
  target_document_id uuid,
  target_user_id uuid,
  target_idempotency_key uuid
)
returns public.certificate_analyses
language plpgsql
security definer
set search_path = ''
as $$
declare
  existing public.certificate_analyses;
  reserved public.certificate_analyses;
begin
  perform pg_advisory_xact_lock(hashtextextended(target_organisation_id::text, 0));

  select * into existing
  from public.certificate_analyses
  where requested_by = target_user_id
    and idempotency_key = target_idempotency_key;

  if found then
    return existing;
  end if;

  if (
    select count(*)
    from public.certificate_analyses
    where organisation_id = target_organisation_id
      and created_at > now() - interval '24 hours'
  ) >= 20 then
    raise exception using
      errcode = 'P0001',
      message = 'certificate_analysis_rate_limit';
  end if;

  insert into public.certificate_analyses (
    organisation_id, property_id, compliance_record_id, document_id,
    requested_by, idempotency_key
  )
  values (
    target_organisation_id, target_property_id, target_compliance_record_id,
    target_document_id, target_user_id, target_idempotency_key
  )
  returning * into reserved;

  return reserved;
end;
$$;

revoke all on function public.reserve_certificate_analysis(
  uuid, uuid, uuid, uuid, uuid, uuid
) from public, anon, authenticated;
grant execute on function public.reserve_certificate_analysis(
  uuid, uuid, uuid, uuid, uuid, uuid
) to service_role;

create or replace function public.confirm_certificate_analysis(
  target_analysis_id uuid,
  target_user_id uuid,
  selected_values jsonb
)
returns public.certificate_analyses
language plpgsql
security definer
set search_path = ''
as $$
declare
  analysis public.certificate_analyses;
  current_record public.property_compliance_records;
  issue_value date;
  expiry_value date;
  reference_value text;
  notes_value text;
begin
  select * into analysis
  from public.certificate_analyses
  where id = target_analysis_id
  for update;

  if not found or analysis.status not in ('completed', 'confirmed') then
    raise exception using errcode = 'P0002', message = 'analysis_not_confirmable';
  end if;

  if not exists (
    select 1 from public.organisation_members
    where organisation_id = analysis.organisation_id
      and user_id = target_user_id
      and role in ('owner', 'admin', 'member')
  ) then
    raise exception using errcode = '42501', message = 'analysis_forbidden';
  end if;

  if analysis.status = 'confirmed' then
    return analysis;
  end if;

  select * into current_record
  from public.property_compliance_records
  where id = analysis.compliance_record_id
    and organisation_id = analysis.organisation_id
    and property_id = analysis.property_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'compliance_record_missing';
  end if;

  if selected_values ? 'issue_date' then
    issue_value := nullif(selected_values->>'issue_date', '')::date;
  else
    issue_value := current_record.issue_date;
  end if;
  if selected_values ? 'expiry_date' then
    expiry_value := nullif(selected_values->>'expiry_date', '')::date;
  else
    expiry_value := current_record.expiry_date;
  end if;
  if selected_values ? 'reference_number' then
    reference_value := nullif(btrim(selected_values->>'reference_number'), '');
  else
    reference_value := current_record.reference_number;
  end if;
  if selected_values ? 'notes' then
    notes_value := nullif(btrim(selected_values->>'notes'), '');
  else
    notes_value := current_record.notes;
  end if;

  update public.property_compliance_records
  set issue_date = issue_value,
      expiry_date = expiry_value,
      reference_number = reference_value,
      notes = notes_value,
      confirmed_at = now(),
      confirmed_by = target_user_id,
      updated_at = now()
  where id = current_record.id;

  update public.certificate_analyses
  set status = 'confirmed',
      confirmed_values = selected_values,
      confirmed_at = now(),
      confirmed_by = target_user_id
  where id = analysis.id
  returning * into analysis;

  return analysis;
end;
$$;

revoke all on function public.confirm_certificate_analysis(uuid, uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.confirm_certificate_analysis(uuid, uuid, jsonb)
  to service_role;

commit;
