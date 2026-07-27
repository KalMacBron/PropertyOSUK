-- PropertyOS Alpha
-- Supabase PostgreSQL schema
-- Apply through versioned migrations, never directly to production.

begin;

create extension if not exists pgcrypto;

create type public.member_role as enum ('owner', 'admin', 'member', 'viewer');
create type public.record_status as enum ('active', 'archived');
create type public.compliance_state as enum (
  'compliant', 'due_soon', 'expired', 'missing', 'needs_review', 'not_applicable'
);
create type public.task_priority as enum ('low', 'medium', 'high', 'urgent');
create type public.task_state as enum ('open', 'in_progress', 'completed', 'cancelled');
create type public.maintenance_state as enum (
  'reported', 'triaged', 'quoted', 'approved', 'scheduled', 'in_progress', 'resolved', 'cancelled'
);
create type public.document_state as enum ('uploaded', 'processing', 'needs_review', 'confirmed', 'failed');
create type public.document_scope as enum ('organisation', 'property', 'tenancy', 'compliance', 'maintenance');
create type public.ownership_entity_type as enum (
  'individual', 'joint', 'limited_company', 'trust', 'partnership', 'other'
);

create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.organisations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 1 and 120),
  slug text not null unique check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.organisation_members (
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.member_role not null default 'member',
  created_at timestamptz not null default now(),
  primary key (organisation_id, user_id)
);

create table public.properties (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  display_name text,
  address_line_1 text not null,
  address_line_2 text,
  town_or_city text not null,
  county text,
  postcode text not null,
  property_type text,
  bedrooms smallint check (bedrooms is null or bedrooms >= 0),
  notes text,
  status public.record_status not null default 'active',
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, organisation_id)
);

create table public.ownership_entities (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  entity_type public.ownership_entity_type not null,
  legal_name text not null check (length(trim(legal_name)) between 1 and 160),
  company_number text,
  notes text,
  status public.record_status not null default 'active',
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, organisation_id),
  check (
    entity_type <> 'limited_company'
    or company_number is null
    or company_number ~ '^[A-Za-z0-9]{8}$'
  )
);

create table public.property_ownerships (
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  property_id uuid not null,
  ownership_entity_id uuid not null,
  ownership_percentage numeric(5,2) not null
    check (ownership_percentage > 0 and ownership_percentage <= 100),
  ownership_started_on date,
  ownership_ended_on date,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  primary key (property_id, ownership_entity_id),
  foreign key (property_id, organisation_id)
    references public.properties(id, organisation_id) on delete cascade,
  foreign key (ownership_entity_id, organisation_id)
    references public.ownership_entities(id, organisation_id) on delete cascade,
  check (ownership_ended_on is null or ownership_started_on is null
    or ownership_ended_on >= ownership_started_on)
);

create table public.tenants (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  display_name text not null,
  email text,
  phone text,
  notes text,
  status public.record_status not null default 'active',
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, organisation_id)
);

create table public.tenancies (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  property_id uuid not null,
  start_date date not null,
  fixed_term_end_date date,
  actual_end_date date,
  monthly_rent_pence integer check (monthly_rent_pence is null or monthly_rent_pence >= 0),
  rent_due_day smallint check (rent_due_day is null or rent_due_day between 1 and 28),
  notes text,
  status public.record_status not null default 'active',
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (fixed_term_end_date is null or fixed_term_end_date >= start_date),
  check (actual_end_date is null or actual_end_date >= start_date),
  unique (id, organisation_id),
  foreign key (property_id, organisation_id)
    references public.properties(id, organisation_id)
);

create table public.tenancy_tenants (
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  tenancy_id uuid not null,
  tenant_id uuid not null,
  is_lead boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (tenancy_id, tenant_id),
  foreign key (tenancy_id, organisation_id)
    references public.tenancies(id, organisation_id) on delete cascade,
  foreign key (tenant_id, organisation_id)
    references public.tenants(id, organisation_id) on delete cascade
);

create table public.compliance_requirement_types (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid references public.organisations(id) on delete cascade,
  code text not null,
  name text not null,
  description text,
  default_warning_days integer not null default 45 check (default_warning_days >= 0),
  is_system boolean not null default false,
  created_at timestamptz not null default now(),
  unique nulls not distinct (organisation_id, code)
);

create table public.property_compliance_records (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  property_id uuid not null,
  requirement_type_id uuid not null references public.compliance_requirement_types(id),
  state_override public.compliance_state,
  issue_date date,
  completion_date date,
  expiry_date date,
  review_date date,
  reference_number text,
  notes text,
  confirmed_at timestamptz,
  confirmed_by uuid references auth.users(id),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (property_id, requirement_type_id),
  unique (id, organisation_id),
  foreign key (property_id, organisation_id)
    references public.properties(id, organisation_id)
);

create table public.contractors (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  name text not null,
  trade text,
  email text,
  phone text,
  notes text,
  status public.record_status not null default 'active',
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, organisation_id)
);

create table public.maintenance_issues (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  property_id uuid not null,
  contractor_id uuid,
  title text not null,
  description text,
  priority public.task_priority not null default 'medium',
  state public.maintenance_state not null default 'reported',
  reported_at timestamptz not null default now(),
  target_date date,
  resolved_at timestamptz,
  estimated_cost_pence integer check (estimated_cost_pence is null or estimated_cost_pence >= 0),
  actual_cost_pence integer check (actual_cost_pence is null or actual_cost_pence >= 0),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, organisation_id),
  foreign key (property_id, organisation_id)
    references public.properties(id, organisation_id),
  foreign key (contractor_id, organisation_id)
    references public.contractors(id, organisation_id)
);

create table public.documents (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  property_id uuid,
  tenancy_id uuid,
  compliance_record_id uuid,
  maintenance_issue_id uuid,
  scope public.document_scope not null,
  document_type text not null,
  original_filename text not null,
  storage_bucket text not null default 'property-documents',
  storage_path text not null,
  mime_type text,
  size_bytes bigint check (size_bytes is null or size_bytes >= 0),
  state public.document_state not null default 'uploaded',
  extracted_data jsonb not null default '{}'::jsonb,
  extraction_confidence numeric(5,4)
    check (extraction_confidence is null or extraction_confidence between 0 and 1),
  confirmed_at timestamptz,
  confirmed_by uuid references auth.users(id),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (storage_bucket, storage_path),
  check (
    storage_path like organisation_id::text || '/%'
  ),
  foreign key (property_id, organisation_id)
    references public.properties(id, organisation_id),
  foreign key (tenancy_id, organisation_id)
    references public.tenancies(id, organisation_id),
  foreign key (compliance_record_id, organisation_id)
    references public.property_compliance_records(id, organisation_id),
  foreign key (maintenance_issue_id, organisation_id)
    references public.maintenance_issues(id, organisation_id)
);

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  property_id uuid,
  compliance_record_id uuid,
  maintenance_issue_id uuid,
  title text not null,
  description text,
  priority public.task_priority not null default 'medium',
  state public.task_state not null default 'open',
  due_date date,
  source_type text not null default 'manual',
  source_id uuid,
  completed_at timestamptz,
  completed_by uuid references auth.users(id),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (property_id, organisation_id)
    references public.properties(id, organisation_id),
  foreign key (compliance_record_id, organisation_id)
    references public.property_compliance_records(id, organisation_id),
  foreign key (maintenance_issue_id, organisation_id)
    references public.maintenance_issues(id, organisation_id)
);

create table public.timeline_events (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  property_id uuid not null,
  event_type text not null,
  title text not null,
  description text,
  source_type text,
  source_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  actor_user_id uuid references auth.users(id),
  created_at timestamptz not null default now(),
  foreign key (property_id, organisation_id)
    references public.properties(id, organisation_id)
);

create index properties_organisation_idx on public.properties (organisation_id, status);
create index ownership_entities_organisation_idx
  on public.ownership_entities (organisation_id, status, entity_type);
create index property_ownerships_entity_idx
  on public.property_ownerships (organisation_id, ownership_entity_id);
create index tenancies_property_idx on public.tenancies (organisation_id, property_id, fixed_term_end_date);
create index compliance_property_idx on public.property_compliance_records
  (organisation_id, property_id, expiry_date);
create index documents_property_idx on public.documents (organisation_id, property_id, created_at desc);
create index tasks_today_idx on public.tasks (organisation_id, state, due_date, priority);
create index maintenance_open_idx on public.maintenance_issues (organisation_id, state, priority);
create index timeline_property_idx on public.timeline_events (organisation_id, property_id, occurred_at desc);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_updated_at before update on public.profiles
for each row execute function public.set_updated_at();
create trigger organisations_updated_at before update on public.organisations
for each row execute function public.set_updated_at();
create trigger properties_updated_at before update on public.properties
for each row execute function public.set_updated_at();
create trigger ownership_entities_updated_at before update on public.ownership_entities
for each row execute function public.set_updated_at();
create trigger tenants_updated_at before update on public.tenants
for each row execute function public.set_updated_at();
create trigger tenancies_updated_at before update on public.tenancies
for each row execute function public.set_updated_at();
create trigger compliance_updated_at before update on public.property_compliance_records
for each row execute function public.set_updated_at();
create trigger contractors_updated_at before update on public.contractors
for each row execute function public.set_updated_at();
create trigger maintenance_updated_at before update on public.maintenance_issues
for each row execute function public.set_updated_at();
create trigger documents_updated_at before update on public.documents
for each row execute function public.set_updated_at();
create trigger tasks_updated_at before update on public.tasks
for each row execute function public.set_updated_at();

create or replace function public.is_organisation_member(target_organisation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.organisation_members m
    where m.organisation_id = target_organisation_id
      and m.user_id = auth.uid()
  );
$$;

create or replace function public.has_organisation_role(
  target_organisation_id uuid,
  allowed_roles public.member_role[]
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.organisation_members m
    where m.organisation_id = target_organisation_id
      and m.user_id = auth.uid()
      and m.role = any(allowed_roles)
  );
$$;

revoke all on function public.is_organisation_member(uuid) from public;
revoke all on function public.has_organisation_role(uuid, public.member_role[]) from public;
grant execute on function public.is_organisation_member(uuid) to authenticated;
grant execute on function public.has_organisation_role(uuid, public.member_role[]) to authenticated;

create or replace function public.create_organisation(organisation_name text, organisation_slug text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  insert into public.organisations (name, slug, created_by)
  values (trim(organisation_name), lower(trim(organisation_slug)), auth.uid())
  returning id into new_id;

  insert into public.organisation_members (organisation_id, user_id, role)
  values (new_id, auth.uid(), 'owner');

  return new_id;
end;
$$;

revoke all on function public.create_organisation(text, text) from public;
grant execute on function public.create_organisation(text, text) to authenticated;

create or replace function public.compliance_state_for(
  expiry_date date,
  review_date date,
  confirmed_at timestamptz,
  state_override public.compliance_state,
  warning_days integer
)
returns public.compliance_state
language sql
stable
set search_path = ''
as $$
  select case
    when state_override is not null then state_override
    when confirmed_at is null then 'needs_review'::public.compliance_state
    when coalesce(expiry_date, review_date) is null then 'compliant'::public.compliance_state
    when coalesce(expiry_date, review_date) < current_date then 'expired'::public.compliance_state
    when coalesce(expiry_date, review_date) <= current_date + warning_days
      then 'due_soon'::public.compliance_state
    else 'compliant'::public.compliance_state
  end;
$$;

create view public.property_compliance_status
with (security_invoker = true)
as
select
  r.*,
  t.code as requirement_code,
  t.name as requirement_name,
  t.default_warning_days,
  public.compliance_state_for(
    r.expiry_date,
    r.review_date,
    r.confirmed_at,
    r.state_override,
    t.default_warning_days
  ) as calculated_state,
  coalesce(r.expiry_date, r.review_date) as action_date
from public.property_compliance_records r
join public.compliance_requirement_types t on t.id = r.requirement_type_id;

create view public.today_actions
with (security_invoker = true)
as
select
  c.organisation_id,
  c.property_id,
  'compliance'::text as source_type,
  c.id as source_id,
  case c.calculated_state
    when 'expired' then 'urgent'::public.task_priority
    when 'missing' then 'high'::public.task_priority
    when 'due_soon' then
      case when c.action_date <= current_date + 14
        then 'high'::public.task_priority
        else 'medium'::public.task_priority
      end
    else 'medium'::public.task_priority
  end as priority,
  c.action_date as due_date,
  case
    when c.calculated_state = 'expired' then c.requirement_name || ' has expired'
    when c.calculated_state = 'missing' then c.requirement_name || ' evidence is missing'
    else 'Review ' || c.requirement_name
  end as title,
  c.calculated_state::text as reason
from public.property_compliance_status c
where c.calculated_state in ('expired', 'missing', 'due_soon')

union all

select
  t.organisation_id,
  t.property_id,
  'task'::text,
  t.id,
  t.priority,
  t.due_date,
  t.title,
  case when t.due_date < current_date then 'overdue' else 'open' end
from public.tasks t
where t.state in ('open', 'in_progress')
  and (t.due_date is null or t.due_date <= current_date + 45)

union all

select
  m.organisation_id,
  m.property_id,
  'maintenance'::text,
  m.id,
  case when m.priority = 'urgent' then 'urgent'::public.task_priority
       else 'high'::public.task_priority end,
  m.target_date,
  m.title,
  'open_' || m.state::text
from public.maintenance_issues m
where m.priority in ('high', 'urgent')
  and m.state not in ('resolved', 'cancelled')

union all

select
  t.organisation_id,
  t.property_id,
  'tenancy'::text,
  t.id,
  case when t.fixed_term_end_date <= current_date + 30
    then 'high'::public.task_priority
    else 'medium'::public.task_priority
  end,
  t.fixed_term_end_date,
  'Review tenancy ending soon',
  'fixed_term_ending'
from public.tenancies t
where t.status = 'active'
  and t.fixed_term_end_date between current_date and current_date + 60;

alter table public.profiles enable row level security;
alter table public.organisations enable row level security;
alter table public.organisation_members enable row level security;
alter table public.properties enable row level security;
alter table public.ownership_entities enable row level security;
alter table public.property_ownerships enable row level security;
alter table public.tenants enable row level security;
alter table public.tenancies enable row level security;
alter table public.tenancy_tenants enable row level security;
alter table public.compliance_requirement_types enable row level security;
alter table public.property_compliance_records enable row level security;
alter table public.contractors enable row level security;
alter table public.maintenance_issues enable row level security;
alter table public.documents enable row level security;
alter table public.tasks enable row level security;
alter table public.timeline_events enable row level security;

create policy profiles_select_self on public.profiles
for select to authenticated using (user_id = auth.uid());
create policy profiles_update_self on public.profiles
for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy profiles_insert_self on public.profiles
for insert to authenticated with check (user_id = auth.uid());

create policy organisations_select_member on public.organisations
for select to authenticated using (public.is_organisation_member(id));
create policy organisations_update_admin on public.organisations
for update to authenticated
using (public.has_organisation_role(id, array['owner', 'admin']::public.member_role[]))
with check (public.has_organisation_role(id, array['owner', 'admin']::public.member_role[]));

create policy members_select_member on public.organisation_members
for select to authenticated using (public.is_organisation_member(organisation_id));
create policy members_manage_owner on public.organisation_members
for all to authenticated
using (public.has_organisation_role(organisation_id, array['owner']::public.member_role[]))
with check (public.has_organisation_role(organisation_id, array['owner']::public.member_role[]));

-- Standard organisation policies. Viewers may read; members and above may write.
create policy properties_select on public.properties for select to authenticated
using (public.is_organisation_member(organisation_id));
create policy properties_write on public.properties for all to authenticated
using (public.has_organisation_role(organisation_id, array['owner','admin','member']::public.member_role[]))
with check (public.has_organisation_role(organisation_id, array['owner','admin','member']::public.member_role[]));

create policy ownership_entities_select on public.ownership_entities for select to authenticated
using (public.is_organisation_member(organisation_id));
create policy ownership_entities_write on public.ownership_entities for all to authenticated
using (public.has_organisation_role(organisation_id, array['owner','admin','member']::public.member_role[]))
with check (public.has_organisation_role(organisation_id, array['owner','admin','member']::public.member_role[]));

create policy property_ownerships_select on public.property_ownerships for select to authenticated
using (public.is_organisation_member(organisation_id));
create policy property_ownerships_write on public.property_ownerships for all to authenticated
using (public.has_organisation_role(organisation_id, array['owner','admin','member']::public.member_role[]))
with check (public.has_organisation_role(organisation_id, array['owner','admin','member']::public.member_role[]));

create policy tenants_select on public.tenants for select to authenticated
using (public.is_organisation_member(organisation_id));
create policy tenants_write on public.tenants for all to authenticated
using (public.has_organisation_role(organisation_id, array['owner','admin','member']::public.member_role[]))
with check (public.has_organisation_role(organisation_id, array['owner','admin','member']::public.member_role[]));

create policy tenancies_select on public.tenancies for select to authenticated
using (public.is_organisation_member(organisation_id));
create policy tenancies_write on public.tenancies for all to authenticated
using (public.has_organisation_role(organisation_id, array['owner','admin','member']::public.member_role[]))
with check (public.has_organisation_role(organisation_id, array['owner','admin','member']::public.member_role[]));

create policy tenancy_tenants_select on public.tenancy_tenants for select to authenticated
using (public.is_organisation_member(organisation_id));
create policy tenancy_tenants_write on public.tenancy_tenants for all to authenticated
using (public.has_organisation_role(organisation_id, array['owner','admin','member']::public.member_role[]))
with check (public.has_organisation_role(organisation_id, array['owner','admin','member']::public.member_role[]));

create policy requirement_types_select on public.compliance_requirement_types for select to authenticated
using (organisation_id is null or public.is_organisation_member(organisation_id));
create policy requirement_types_write on public.compliance_requirement_types for all to authenticated
using (
  organisation_id is not null
  and public.has_organisation_role(organisation_id, array['owner','admin']::public.member_role[])
)
with check (
  organisation_id is not null
  and public.has_organisation_role(organisation_id, array['owner','admin']::public.member_role[])
);

create policy compliance_select on public.property_compliance_records for select to authenticated
using (public.is_organisation_member(organisation_id));
create policy compliance_write on public.property_compliance_records for all to authenticated
using (public.has_organisation_role(organisation_id, array['owner','admin','member']::public.member_role[]))
with check (public.has_organisation_role(organisation_id, array['owner','admin','member']::public.member_role[]));

create policy contractors_select on public.contractors for select to authenticated
using (public.is_organisation_member(organisation_id));
create policy contractors_write on public.contractors for all to authenticated
using (public.has_organisation_role(organisation_id, array['owner','admin','member']::public.member_role[]))
with check (public.has_organisation_role(organisation_id, array['owner','admin','member']::public.member_role[]));

create policy maintenance_select on public.maintenance_issues for select to authenticated
using (public.is_organisation_member(organisation_id));
create policy maintenance_write on public.maintenance_issues for all to authenticated
using (public.has_organisation_role(organisation_id, array['owner','admin','member']::public.member_role[]))
with check (public.has_organisation_role(organisation_id, array['owner','admin','member']::public.member_role[]));

create policy documents_select on public.documents for select to authenticated
using (public.is_organisation_member(organisation_id));
create policy documents_write on public.documents for all to authenticated
using (public.has_organisation_role(organisation_id, array['owner','admin','member']::public.member_role[]))
with check (public.has_organisation_role(organisation_id, array['owner','admin','member']::public.member_role[]));

create policy tasks_select on public.tasks for select to authenticated
using (public.is_organisation_member(organisation_id));
create policy tasks_write on public.tasks for all to authenticated
using (public.has_organisation_role(organisation_id, array['owner','admin','member']::public.member_role[]))
with check (public.has_organisation_role(organisation_id, array['owner','admin','member']::public.member_role[]));

create policy timeline_select on public.timeline_events for select to authenticated
using (public.is_organisation_member(organisation_id));
create policy timeline_insert on public.timeline_events for insert to authenticated
with check (public.has_organisation_role(organisation_id, array['owner','admin','member']::public.member_role[]));

insert into public.compliance_requirement_types
  (organisation_id, code, name, description, default_warning_days, is_system)
values
  (null, 'gas_safety', 'Gas Safety Certificate', 'Gas safety record and renewal date.', 45, true),
  (null, 'epc', 'Energy Performance Certificate', 'Energy performance evidence.', 90, true),
  (null, 'eicr', 'Electrical Installation Condition Report', 'Electrical installation inspection evidence.', 90, true),
  (null, 'deposit_protection', 'Deposit Protection', 'Evidence that a tenancy deposit is protected.', 0, true),
  (null, 'right_to_rent', 'Right to Rent', 'User-recorded check status; do not store identity documents in Alpha.', 0, true),
  (null, 'smoke_alarms', 'Smoke Alarm Check', 'Smoke alarm installation and check record.', 30, true),
  (null, 'co_alarms', 'CO Alarm Check', 'Carbon monoxide alarm installation and check record.', 30, true),
  (null, 'landlord_insurance', 'Landlord Insurance', 'Landlord insurance policy and renewal date.', 45, true);

-- Create the private bucket once Storage is available.
insert into storage.buckets (id, name, public)
values ('property-documents', 'property-documents', false)
on conflict (id) do update set public = false;

create policy storage_documents_select on storage.objects
for select to authenticated
using (
  bucket_id = 'property-documents'
  and public.is_organisation_member((storage.foldername(name))[1]::uuid)
);

create policy storage_documents_insert on storage.objects
for insert to authenticated
with check (
  bucket_id = 'property-documents'
  and public.has_organisation_role(
    (storage.foldername(name))[1]::uuid,
    array['owner','admin','member']::public.member_role[]
  )
);

create policy storage_documents_update on storage.objects
for update to authenticated
using (
  bucket_id = 'property-documents'
  and public.has_organisation_role(
    (storage.foldername(name))[1]::uuid,
    array['owner','admin','member']::public.member_role[]
  )
)
with check (
  bucket_id = 'property-documents'
  and public.has_organisation_role(
    (storage.foldername(name))[1]::uuid,
    array['owner','admin','member']::public.member_role[]
  )
);

create policy storage_documents_delete on storage.objects
for delete to authenticated
using (
  bucket_id = 'property-documents'
  and public.has_organisation_role(
    (storage.foldername(name))[1]::uuid,
    array['owner','admin']::public.member_role[]
  )
);

commit;
