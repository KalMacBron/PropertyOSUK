-- Milestone 4: private compliance evidence and tenant-safe Storage access.

begin;

update storage.buckets
set public = false,
    file_size_limit = 10485760,
    allowed_mime_types = array['application/pdf', 'image/jpeg', 'image/png']::text[]
where id = 'property-documents';

alter table public.documents
  add constraint documents_compliance_evidence_shape
  check (
    scope <> 'compliance'
    or (
      property_id is not null
      and compliance_record_id is not null
      and tenancy_id is null
      and maintenance_issue_id is null
      and storage_bucket = 'property-documents'
      and mime_type in ('application/pdf', 'image/jpeg', 'image/png')
      and size_bytes between 1 and 10485760
      and storage_path =
        organisation_id::text || '/' ||
        property_id::text || '/' ||
        compliance_record_id::text || '/' ||
        id::text || '/' ||
        regexp_replace(original_filename, '[^A-Za-z0-9._-]+', '_', 'g')
    )
  );

create index documents_compliance_record_idx
  on public.documents (organisation_id, compliance_record_id, created_at desc)
  where scope = 'compliance';

drop policy if exists documents_write on public.documents;
drop policy if exists documents_insert on public.documents;
drop policy if exists documents_delete on public.documents;
drop policy if exists documents_update on public.documents;

create policy documents_insert
on public.documents
for insert
to authenticated
with check (
  scope = 'compliance'
  and created_by = (select auth.uid())
  and public.has_organisation_role(
    organisation_id,
    array['owner','admin','member']::public.member_role[]
  )
  and exists (
    select 1
    from public.property_compliance_records compliance
    where compliance.id = compliance_record_id
      and compliance.organisation_id = documents.organisation_id
      and compliance.property_id = documents.property_id
  )
);

create policy documents_delete
on public.documents
for delete
to authenticated
using (
  public.has_organisation_role(
    organisation_id,
    array['owner','admin']::public.member_role[]
  )
);

-- Correct the Milestone 3 requirement-type organisation comparison. The table
-- qualifier avoids the inner requirement alias shadowing the target row.
drop policy if exists compliance_insert on public.property_compliance_records;
drop policy if exists compliance_update on public.property_compliance_records;

create policy compliance_insert
on public.property_compliance_records
for insert
to authenticated
with check (
  public.has_organisation_role(
    organisation_id,
    array['owner','admin','member']::public.member_role[]
  )
  and exists (
    select 1
    from public.compliance_requirement_types requirement
    where requirement.id = requirement_type_id
      and (
        requirement.organisation_id is null
        or requirement.organisation_id =
          property_compliance_records.organisation_id
      )
  )
);

create policy compliance_update
on public.property_compliance_records
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
  and exists (
    select 1
    from public.compliance_requirement_types requirement
    where requirement.id = requirement_type_id
      and (
        requirement.organisation_id is null
        or requirement.organisation_id =
          property_compliance_records.organisation_id
      )
  )
);

create or replace function public.can_access_compliance_evidence(
  object_name text,
  allowed_roles public.member_role[]
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  path_parts text[];
  target_organisation_id uuid;
  target_property_id uuid;
  target_compliance_id uuid;
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
    target_compliance_id := path_parts[3]::uuid;
    target_document_id := path_parts[4]::uuid;
  exception when invalid_text_representation then
    return false;
  end;

  return exists (
    select 1
    from public.organisation_members member
    join public.property_compliance_records compliance
      on compliance.organisation_id = member.organisation_id
     and compliance.id = target_compliance_id
     and compliance.property_id = target_property_id
    where member.organisation_id = target_organisation_id
      and member.user_id = auth.uid()
      and member.role = any(allowed_roles)
      and path_parts[4] = target_document_id::text
  );
end;
$$;

revoke all on function public.can_access_compliance_evidence(
  text,
  public.member_role[]
) from public, anon;
grant execute on function public.can_access_compliance_evidence(
  text,
  public.member_role[]
) to authenticated;

drop policy if exists storage_documents_select on storage.objects;
drop policy if exists storage_documents_insert on storage.objects;
drop policy if exists storage_documents_update on storage.objects;
drop policy if exists storage_documents_delete on storage.objects;
drop policy if exists storage_documents_rollback on storage.objects;

create policy storage_documents_select
on storage.objects
for select
to authenticated
using (
  bucket_id = 'property-documents'
  and public.can_access_compliance_evidence(
    name,
    array['owner','admin','member','viewer']::public.member_role[]
  )
);

create policy storage_documents_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'property-documents'
  and public.can_access_compliance_evidence(
    name,
    array['owner','admin','member']::public.member_role[]
  )
);

create policy storage_documents_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'property-documents'
  and public.can_access_compliance_evidence(
    name,
    array['owner','admin']::public.member_role[]
  )
);

-- A member may remove only an object they just uploaded when metadata creation
-- failed. Once a documents row exists, only owner/admin deletion is allowed.
create policy storage_documents_rollback
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'property-documents'
  and owner_id = (select auth.uid()::text)
  and public.can_access_compliance_evidence(
    name,
    array['owner','admin','member']::public.member_role[]
  )
  and not exists (
    select 1
    from public.documents document
    where document.storage_bucket = bucket_id
      and document.storage_path = name
  )
);

revoke update on storage.objects from authenticated;

commit;
