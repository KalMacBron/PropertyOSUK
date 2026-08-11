-- Organisation Export Alpha: owner/admin-only structured data portability and
-- separately authorised document downloads. Storage paths never appear in the
-- structured export or document manifest.

create or replace function public.export_organisation_data(
  target_organisation_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  exported_at timestamptz := statement_timestamp();
  result jsonb;
begin
  if actor_id is null or not public.has_organisation_role(
    target_organisation_id,
    array['owner','admin']::public.member_role[]
  ) then
    raise exception using errcode = '42501', message = 'organisation_export_forbidden';
  end if;

  if not exists (
    select 1 from public.organisations organisation
    where organisation.id = target_organisation_id
  ) then
    raise exception using errcode = 'P0002', message = 'organisation_export_unavailable';
  end if;

  insert into public.organisation_audit_events (
    organisation_id, event_type, title, description, source_type,
    actor_user_id, occurred_at
  ) values (
    target_organisation_id, 'organisation_data_exported',
    'Organisation data exported',
    'A versioned JSON export of structured Alpha data was generated.',
    'organisation_export', actor_id, exported_at
  );

  select jsonb_build_object(
    'schema_version', 'propertyos-alpha-export-v1',
    'exported_at', exported_at,
    'currency', 'GBP',
    'organisation', (
      select jsonb_build_object(
        'id', organisation.id,
        'name', organisation.name,
        'slug', organisation.slug,
        'created_at', organisation.created_at,
        'updated_at', organisation.updated_at
      )
      from public.organisations organisation
      where organisation.id = target_organisation_id
    ),
    'record_counts', jsonb_build_object(
      'members', (select count(*) from public.organisation_members row where row.organisation_id = target_organisation_id),
      'invitations', (select count(*) from public.organisation_invitations row where row.organisation_id = target_organisation_id),
      'properties', (select count(*) from public.properties row where row.organisation_id = target_organisation_id),
      'ownership_entities', (select count(*) from public.ownership_entities row where row.organisation_id = target_organisation_id),
      'property_ownerships', (select count(*) from public.property_ownerships row where row.organisation_id = target_organisation_id),
      'tenants', (select count(*) from public.tenants row where row.organisation_id = target_organisation_id),
      'tenancies', (select count(*) from public.tenancies row where row.organisation_id = target_organisation_id),
      'compliance_records', (select count(*) from public.property_compliance_records row where row.organisation_id = target_organisation_id),
      'contractors', (select count(*) from public.contractors row where row.organisation_id = target_organisation_id),
      'maintenance_issues', (select count(*) from public.maintenance_issues row where row.organisation_id = target_organisation_id),
      'tasks', (select count(*) from public.tasks row where row.organisation_id = target_organisation_id),
      'expenses', (select count(*) from public.property_expenses row where row.organisation_id = target_organisation_id),
      'documents', (select count(*) from public.documents row where row.organisation_id = target_organisation_id),
      'timeline_events', (select count(*) from public.timeline_events row where row.organisation_id = target_organisation_id),
      'audit_events', (select count(*) from public.organisation_audit_events row where row.organisation_id = target_organisation_id)
    ),
    'data', jsonb_build_object(
      'members', coalesce((
        select jsonb_agg(jsonb_build_object(
          'user_id', member.user_id,
          'email', lower(user_record.email),
          'display_name', profile.display_name,
          'role', member.role,
          'created_at', member.created_at
        ) order by lower(user_record.email), member.user_id)
        from public.organisation_members member
        join auth.users user_record on user_record.id = member.user_id
        left join public.profiles profile on profile.user_id = member.user_id
        where member.organisation_id = target_organisation_id
      ), '[]'::jsonb),
      'invitations', coalesce((
        select jsonb_agg(to_jsonb(invitation) order by invitation.created_at, invitation.id)
        from public.organisation_invitations invitation
        where invitation.organisation_id = target_organisation_id
      ), '[]'::jsonb),
      'properties', coalesce((
        select jsonb_agg(to_jsonb(property) order by property.created_at, property.id)
        from public.properties property
        where property.organisation_id = target_organisation_id
      ), '[]'::jsonb),
      'ownership_entities', coalesce((
        select jsonb_agg(to_jsonb(entity) order by entity.created_at, entity.id)
        from public.ownership_entities entity
        where entity.organisation_id = target_organisation_id
      ), '[]'::jsonb),
      'property_ownerships', coalesce((
        select jsonb_agg(to_jsonb(ownership) order by ownership.property_id, ownership.ownership_entity_id)
        from public.property_ownerships ownership
        where ownership.organisation_id = target_organisation_id
      ), '[]'::jsonb),
      'tenants', coalesce((
        select jsonb_agg(to_jsonb(tenant) order by tenant.created_at, tenant.id)
        from public.tenants tenant
        where tenant.organisation_id = target_organisation_id
      ), '[]'::jsonb),
      'tenancies', coalesce((
        select jsonb_agg(to_jsonb(tenancy) order by tenancy.start_date, tenancy.id)
        from public.tenancies tenancy
        where tenancy.organisation_id = target_organisation_id
      ), '[]'::jsonb),
      'tenancy_tenants', coalesce((
        select jsonb_agg(to_jsonb(link) order by link.tenancy_id, link.tenant_id)
        from public.tenancy_tenants link
        where link.organisation_id = target_organisation_id
      ), '[]'::jsonb),
      'compliance_requirement_types', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', requirement.id,
          'code', requirement.code,
          'name', requirement.name,
          'description', requirement.description,
          'default_warning_days', requirement.default_warning_days,
          'is_system', requirement.is_system
        ) order by requirement.code, requirement.id)
        from public.compliance_requirement_types requirement
        where exists (
          select 1 from public.property_compliance_records record
          where record.organisation_id = target_organisation_id
            and record.requirement_type_id = requirement.id
        )
      ), '[]'::jsonb),
      'compliance_records', coalesce((
        select jsonb_agg(to_jsonb(record) order by record.created_at, record.id)
        from public.property_compliance_records record
        where record.organisation_id = target_organisation_id
      ), '[]'::jsonb),
      'contractors', coalesce((
        select jsonb_agg(to_jsonb(contractor) order by contractor.created_at, contractor.id)
        from public.contractors contractor
        where contractor.organisation_id = target_organisation_id
      ), '[]'::jsonb),
      'maintenance_issues', coalesce((
        select jsonb_agg(to_jsonb(issue) order by issue.created_at, issue.id)
        from public.maintenance_issues issue
        where issue.organisation_id = target_organisation_id
      ), '[]'::jsonb),
      'tasks', coalesce((
        select jsonb_agg(to_jsonb(task) order by task.created_at, task.id)
        from public.tasks task
        where task.organisation_id = target_organisation_id
      ), '[]'::jsonb),
      'expenses', coalesce((
        select jsonb_agg(to_jsonb(expense) order by expense.expense_date, expense.id)
        from public.property_expenses expense
        where expense.organisation_id = target_organisation_id
      ), '[]'::jsonb),
      'documents', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', document.id,
          'organisation_id', document.organisation_id,
          'property_id', document.property_id,
          'tenancy_id', document.tenancy_id,
          'compliance_record_id', document.compliance_record_id,
          'maintenance_issue_id', document.maintenance_issue_id,
          'expense_id', document.expense_id,
          'scope', document.scope,
          'document_type', document.document_type,
          'original_filename', document.original_filename,
          'mime_type', document.mime_type,
          'size_bytes', document.size_bytes,
          'state', document.state,
          'confirmed_at', document.confirmed_at,
          'confirmed_by', document.confirmed_by,
          'created_by', document.created_by,
          'created_at', document.created_at,
          'updated_at', document.updated_at
        ) order by document.created_at, document.id)
        from public.documents document
        where document.organisation_id = target_organisation_id
      ), '[]'::jsonb),
      'timeline_events', coalesce((
        select jsonb_agg(to_jsonb(event) order by event.occurred_at, event.id)
        from public.timeline_events event
        where event.organisation_id = target_organisation_id
      ), '[]'::jsonb),
      'audit_events', coalesce((
        select jsonb_agg(to_jsonb(event) order by event.occurred_at, event.id)
        from public.organisation_audit_events event
        where event.organisation_id = target_organisation_id
      ), '[]'::jsonb)
    )
  ) into result;

  return result;
end;
$$;

create or replace function public.list_organisation_export_documents(
  target_organisation_id uuid
)
returns table (
  document_id uuid,
  property_id uuid,
  property_name text,
  scope public.document_scope,
  document_type text,
  original_filename text,
  mime_type text,
  size_bytes bigint,
  created_at timestamptz
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
    raise exception using errcode = '42501', message = 'organisation_export_forbidden';
  end if;

  return query
  select document.id, document.property_id,
    coalesce(property.display_name, property.address_line_1),
    document.scope, document.document_type, document.original_filename,
    document.mime_type, document.size_bytes, document.created_at
  from public.documents document
  left join public.properties property
    on property.id = document.property_id
    and property.organisation_id = document.organisation_id
  where document.organisation_id = target_organisation_id
  order by document.created_at desc, document.id;
end;
$$;

create or replace function public.prepare_organisation_document_export(
  target_organisation_id uuid,
  target_document_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  document_record record;
begin
  if actor_id is null or not public.has_organisation_role(
    target_organisation_id,
    array['owner','admin']::public.member_role[]
  ) then
    raise exception using errcode = '42501', message = 'organisation_export_forbidden';
  end if;

  select document.id, document.storage_bucket, document.storage_path,
    document.original_filename
  into document_record
  from public.documents document
  where document.id = target_document_id
    and document.organisation_id = target_organisation_id;
  if not found then
    raise exception using errcode = 'P0002', message = 'document_export_unavailable';
  end if;

  insert into public.organisation_audit_events (
    organisation_id, event_type, title, description, source_type, source_id,
    actor_user_id
  ) values (
    target_organisation_id, 'organisation_document_exported',
    'Organisation document downloaded', document_record.original_filename,
    'document', document_record.id, actor_id
  );

  return jsonb_build_object(
    'storage_bucket', document_record.storage_bucket,
    'storage_path', document_record.storage_path
  );
end;
$$;

revoke all on function public.export_organisation_data(uuid) from public, anon;
revoke all on function public.list_organisation_export_documents(uuid) from public, anon;
revoke all on function public.prepare_organisation_document_export(uuid,uuid) from public, anon;
grant execute on function public.export_organisation_data(uuid) to authenticated;
grant execute on function public.list_organisation_export_documents(uuid) to authenticated;
grant execute on function public.prepare_organisation_document_export(uuid,uuid) to authenticated;
