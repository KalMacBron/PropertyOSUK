-- Milestone 7: organisation-isolated property expenses and private evidence.

create table public.property_expenses (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null references public.organisations(id) on delete cascade,
  property_id uuid not null,
  ownership_entity_id uuid not null,
  compliance_record_id uuid,
  expense_date date not null,
  supplier text,
  description text not null check (length(btrim(description)) > 0),
  category text not null check (category in (
    'compliance_certificates',
    'repairs_maintenance',
    'insurance',
    'utilities_council_tax',
    'management_professional_fees',
    'mortgage_finance_costs',
    'improvements',
    'other'
  )),
  amount_pence bigint not null check (amount_pence > 0),
  vat_treatment text not null default 'not_specified'
    check (vat_treatment in ('included', 'excluded', 'not_specified')),
  vat_amount_pence bigint check (
    vat_amount_pence is null
    or (vat_amount_pence >= 0 and vat_amount_pence <= amount_pence)
  ),
  payment_status text not null default 'paid'
    check (payment_status in ('paid', 'unpaid', 'reimbursed')),
  notes text,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, organisation_id),
  unique (id, organisation_id, property_id)
);

alter table public.property_ownerships
  add constraint property_ownerships_expense_reference_key
  unique (property_id, ownership_entity_id, organisation_id);

alter table public.property_compliance_records
  add constraint compliance_expense_reference_key
  unique (id, organisation_id, property_id);

alter table public.property_expenses
  add constraint expenses_property_organisation_fkey
    foreign key (property_id, organisation_id)
    references public.properties(id, organisation_id),
  add constraint expenses_ownership_fkey
    foreign key (property_id, ownership_entity_id, organisation_id)
    references public.property_ownerships(
      property_id,
      ownership_entity_id,
      organisation_id
    ),
  add constraint expenses_compliance_fkey
    foreign key (compliance_record_id, organisation_id, property_id)
    references public.property_compliance_records(
      id,
      organisation_id,
      property_id
    );

create index property_expenses_register_idx
  on public.property_expenses (organisation_id, expense_date desc, id);
create index property_expenses_property_idx
  on public.property_expenses (organisation_id, property_id, expense_date desc);
create index property_expenses_category_idx
  on public.property_expenses (organisation_id, category);

alter table public.property_expenses enable row level security;

create policy expenses_select
on public.property_expenses
for select
to authenticated
using (public.is_organisation_member(organisation_id));

create policy expenses_insert
on public.property_expenses
for insert
to authenticated
with check (
  public.has_organisation_role(
    organisation_id,
    array['owner','admin','member']::public.member_role[]
  )
  and created_by = (select auth.uid())
);

create policy expenses_update
on public.property_expenses
for update
to authenticated
using (
  public.has_organisation_role(
    organisation_id,
    array['owner','admin','member']::public.member_role[]
  )
)
with check (
  public.has_organisation_role(
    organisation_id,
    array['owner','admin','member']::public.member_role[]
  )
);

create policy expenses_delete
on public.property_expenses
for delete
to authenticated
using (
  public.has_organisation_role(
    organisation_id,
    array['owner','admin']::public.member_role[]
  )
);

grant select, insert, delete on public.property_expenses to authenticated;
grant update (
  property_id,
  ownership_entity_id,
  compliance_record_id,
  expense_date,
  supplier,
  description,
  category,
  amount_pence,
  vat_treatment,
  vat_amount_pence,
  payment_status,
  notes,
  updated_at
) on public.property_expenses to authenticated;
revoke all on public.property_expenses from anon;

alter table public.documents add column expense_id uuid;
alter table public.documents
  add constraint documents_expense_fkey
  foreign key (expense_id, organisation_id, property_id)
  references public.property_expenses(id, organisation_id, property_id)
  on delete cascade;

alter table public.documents
  add constraint documents_expense_evidence_shape
  check (
    document_type <> 'expense_evidence'
    or (
      scope = 'property'
      and property_id is not null
      and expense_id is not null
      and tenancy_id is null
      and compliance_record_id is null
      and maintenance_issue_id is null
      and storage_bucket = 'property-documents'
      and mime_type in ('application/pdf', 'image/jpeg', 'image/png')
      and size_bytes between 1 and 10485760
      and storage_path =
        organisation_id::text || '/' ||
        property_id::text || '/' ||
        expense_id::text || '/' ||
        id::text || '/' ||
        regexp_replace(original_filename, '[^A-Za-z0-9._-]+', '_', 'g')
    )
  );

create unique index documents_one_expense_evidence_idx
  on public.documents (expense_id)
  where expense_id is not null and document_type = 'expense_evidence';

create or replace function public.can_access_expense_evidence(
  object_name text,
  allowed_roles public.member_role[]
) returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  path_parts text[];
  target_organisation_id uuid;
  target_property_id uuid;
  target_expense_id uuid;
  target_document_id uuid;
begin
  if object_name !~ (
    '^[0-9a-fA-F-]{36}/[0-9a-fA-F-]{36}/' ||
    '[0-9a-fA-F-]{36}/[0-9a-fA-F-]{36}/[A-Za-z0-9._-]+$'
  ) then
    return false;
  end if;
  path_parts := string_to_array(object_name, '/');
  begin
    target_organisation_id := path_parts[1]::uuid;
    target_property_id := path_parts[2]::uuid;
    target_expense_id := path_parts[3]::uuid;
    target_document_id := path_parts[4]::uuid;
  exception when invalid_text_representation then
    return false;
  end;
  return exists (
    select 1
    from public.organisation_members member
    join public.property_expenses expense
      on expense.organisation_id = member.organisation_id
     and expense.id = target_expense_id
     and expense.property_id = target_property_id
    where member.organisation_id = target_organisation_id
      and member.user_id = auth.uid()
      and member.role = any(allowed_roles)
      and path_parts[4] = target_document_id::text
  );
end;
$$;

revoke all on function public.can_access_expense_evidence(text, public.member_role[])
  from public, anon, authenticated;
grant execute
  on function public.can_access_expense_evidence(text, public.member_role[])
  to authenticated;

drop policy if exists storage_documents_select on storage.objects;
create policy storage_documents_select
on storage.objects
for select
to authenticated
using (
  bucket_id = 'property-documents'
  and (
    public.can_access_compliance_evidence(
      name,
      array['owner','admin','member','viewer']::public.member_role[]
    )
    or public.can_access_expense_evidence(
      name,
      array['owner','admin','member','viewer']::public.member_role[]
    )
  )
);

drop policy if exists storage_documents_insert on storage.objects;
create policy storage_documents_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'property-documents'
  and (
    public.can_access_compliance_evidence(
      name,
      array['owner','admin','member']::public.member_role[]
    )
    or public.can_access_expense_evidence(
      name,
      array['owner','admin','member']::public.member_role[]
    )
  )
);

drop policy if exists storage_documents_delete on storage.objects;
create policy storage_documents_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'property-documents'
  and (
    public.can_access_compliance_evidence(
      name,
      array['owner','admin']::public.member_role[]
    )
    or public.can_access_expense_evidence(
      name,
      array['owner','admin']::public.member_role[]
    )
  )
);

drop policy if exists storage_documents_rollback on storage.objects;
create policy storage_documents_rollback
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'property-documents'
  and owner_id = (select auth.uid()::text)
  and (
    public.can_access_compliance_evidence(
      name,
      array['owner','admin','member']::public.member_role[]
    )
    or public.can_access_expense_evidence(
      name,
      array['owner','admin','member']::public.member_role[]
    )
  )
  and not exists (
    select 1 from public.documents document
    where document.storage_bucket = bucket_id
      and document.storage_path = name
  )
);
