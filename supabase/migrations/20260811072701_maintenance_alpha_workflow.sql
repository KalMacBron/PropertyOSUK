-- Maintenance Alpha: atomic organisation-authorised issue creation, editing
-- and state transitions with append-only property timeline evidence.

alter table public.maintenance_issues
  add column notes text,
  add column completion_notes text;

alter table public.maintenance_issues
  add constraint maintenance_title_present
  check (length(btrim(title)) between 1 and 160);

alter table public.maintenance_issues
  add constraint maintenance_expense_reference_key
  unique (id, organisation_id, property_id);
alter table public.property_expenses
  add column maintenance_issue_id uuid,
  add constraint expenses_maintenance_fkey
  foreign key (maintenance_issue_id, organisation_id, property_id)
  references public.maintenance_issues (id, organisation_id, property_id);
grant update (maintenance_issue_id) on public.property_expenses to authenticated;

create index maintenance_property_activity_idx
  on public.maintenance_issues
  (organisation_id, property_id, updated_at desc);
create index tasks_maintenance_issue_idx
  on public.tasks (organisation_id, maintenance_issue_id)
  where maintenance_issue_id is not null;
create index expenses_maintenance_issue_idx
  on public.property_expenses (organisation_id, maintenance_issue_id)
  where maintenance_issue_id is not null;
create index documents_maintenance_issue_idx
  on public.documents (organisation_id, maintenance_issue_id, created_at desc)
  where maintenance_issue_id is not null;

grant select on public.maintenance_issues, public.contractors to authenticated;
revoke insert, update, delete on public.maintenance_issues from authenticated;
drop policy if exists maintenance_write on public.maintenance_issues;

create or replace function public.create_maintenance_issue(
  target_organisation_id uuid,
  target_property_id uuid,
  issue_title text,
  issue_description text default null,
  issue_priority public.task_priority default 'medium',
  issue_reported_date date default current_date,
  issue_target_date date default null,
  target_contractor_id uuid default null,
  issue_estimated_cost_pence integer default null,
  issue_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  created_issue_id uuid;
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'authentication_required';
  end if;
  if nullif(btrim(issue_title), '') is null
     or length(btrim(issue_title)) > 160 then
    raise exception using errcode = '22023', message = 'maintenance_title_invalid';
  end if;
  if issue_reported_date is null then
    raise exception using errcode = '22023', message = 'maintenance_reported_date_required';
  end if;
  if issue_estimated_cost_pence is not null and issue_estimated_cost_pence < 0 then
    raise exception using errcode = '22023', message = 'maintenance_cost_invalid';
  end if;
  if not public.has_organisation_role(
    target_organisation_id,
    array['owner','admin','member']::public.member_role[]
  ) then
    raise exception using errcode = '42501', message = 'maintenance_write_forbidden';
  end if;
  if not exists (
    select 1 from public.properties property
    where property.id = target_property_id
      and property.organisation_id = target_organisation_id
      and property.status = 'active'
  ) then
    raise exception using errcode = 'P0002', message = 'maintenance_context_unavailable';
  end if;
  if target_contractor_id is not null and not exists (
    select 1 from public.contractors contractor
    where contractor.id = target_contractor_id
      and contractor.organisation_id = target_organisation_id
      and contractor.status = 'active'
  ) then
    raise exception using errcode = 'P0002', message = 'maintenance_context_unavailable';
  end if;

  insert into public.maintenance_issues (
    organisation_id, property_id, contractor_id, title, description, priority,
    state, reported_at, target_date, estimated_cost_pence, notes, created_by
  ) values (
    target_organisation_id, target_property_id, target_contractor_id,
    btrim(issue_title), nullif(btrim(issue_description), ''), issue_priority,
    'reported', issue_reported_date::timestamptz, issue_target_date,
    issue_estimated_cost_pence, nullif(btrim(issue_notes), ''), actor_id
  ) returning id into created_issue_id;

  insert into public.timeline_events (
    organisation_id, property_id, event_type, title, description, source_type,
    source_id, metadata, actor_user_id
  ) values (
    target_organisation_id, target_property_id, 'maintenance_created',
    btrim(issue_title) || ' reported',
    'Maintenance issue recorded in the Maintenance workspace.',
    'maintenance', created_issue_id,
    jsonb_build_object(
      'state', 'reported', 'priority', issue_priority,
      'reported_date', issue_reported_date, 'target_date', issue_target_date,
      'estimated_cost_pence', issue_estimated_cost_pence
    ), actor_id
  );

  return created_issue_id;
end;
$$;

create or replace function public.update_maintenance_issue(
  target_issue_id uuid,
  target_property_id uuid,
  issue_title text,
  issue_description text default null,
  issue_priority public.task_priority default 'medium',
  issue_reported_date date default current_date,
  issue_target_date date default null,
  target_contractor_id uuid default null,
  issue_estimated_cost_pence integer default null,
  issue_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  issue_record record;
  changed_fields text[];
  audit_metadata jsonb;
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'authentication_required';
  end if;
  if nullif(btrim(issue_title), '') is null
     or length(btrim(issue_title)) > 160 then
    raise exception using errcode = '22023', message = 'maintenance_title_invalid';
  end if;
  if issue_reported_date is null then
    raise exception using errcode = '22023', message = 'maintenance_reported_date_required';
  end if;
  if issue_estimated_cost_pence is not null and issue_estimated_cost_pence < 0 then
    raise exception using errcode = '22023', message = 'maintenance_cost_invalid';
  end if;

  select issue.* into issue_record
  from public.maintenance_issues issue
  where issue.id = target_issue_id
    and public.has_organisation_role(
      issue.organisation_id,
      array['owner','admin','member']::public.member_role[]
    )
  for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'maintenance_unavailable';
  end if;
  if not exists (
    select 1 from public.properties property
    where property.id = target_property_id
      and property.organisation_id = issue_record.organisation_id
      and property.status = 'active'
  ) then
    raise exception using errcode = 'P0002', message = 'maintenance_context_unavailable';
  end if;
  if target_contractor_id is not null and not exists (
    select 1 from public.contractors contractor
    where contractor.id = target_contractor_id
      and contractor.organisation_id = issue_record.organisation_id
      and contractor.status = 'active'
  ) then
    raise exception using errcode = 'P0002', message = 'maintenance_context_unavailable';
  end if;

  changed_fields := array_remove(array[
    case when issue_record.property_id is distinct from target_property_id then 'property' end,
    case when issue_record.contractor_id is distinct from target_contractor_id then 'contractor' end,
    case when issue_record.title is distinct from btrim(issue_title) then 'title' end,
    case when issue_record.description is distinct from nullif(btrim(issue_description), '') then 'description' end,
    case when issue_record.priority is distinct from issue_priority then 'priority' end,
    case when issue_record.reported_at::date is distinct from issue_reported_date then 'reported_date' end,
    case when issue_record.target_date is distinct from issue_target_date then 'target_date' end,
    case when issue_record.estimated_cost_pence is distinct from issue_estimated_cost_pence then 'estimated_cost' end,
    case when issue_record.notes is distinct from nullif(btrim(issue_notes), '') then 'notes' end
  ], null);
  if cardinality(changed_fields) = 0 then
    return target_issue_id;
  end if;

  audit_metadata := jsonb_build_object(
    'changed_fields', to_jsonb(changed_fields),
    'previous_property_id', issue_record.property_id,
    'property_id', target_property_id,
    'previous_priority', issue_record.priority,
    'priority', issue_priority,
    'previous_target_date', issue_record.target_date,
    'target_date', issue_target_date
  );

  update public.maintenance_issues
  set property_id = target_property_id,
      contractor_id = target_contractor_id,
      title = btrim(issue_title),
      description = nullif(btrim(issue_description), ''),
      priority = issue_priority,
      reported_at = issue_reported_date::timestamptz,
      target_date = issue_target_date,
      estimated_cost_pence = issue_estimated_cost_pence,
      notes = nullif(btrim(issue_notes), '')
  where id = target_issue_id;

  insert into public.timeline_events (
    organisation_id, property_id, event_type, title, description, source_type,
    source_id, metadata, actor_user_id
  ) values (
    issue_record.organisation_id, issue_record.property_id,
    'maintenance_updated', btrim(issue_title) || ' updated',
    'Maintenance issue details updated.', 'maintenance', target_issue_id,
    audit_metadata, actor_id
  );
  if issue_record.property_id is distinct from target_property_id then
    insert into public.timeline_events (
      organisation_id, property_id, event_type, title, description, source_type,
      source_id, metadata, actor_user_id
    ) values (
      issue_record.organisation_id, target_property_id,
      'maintenance_updated', btrim(issue_title) || ' moved to this property',
      'Maintenance issue property association updated.', 'maintenance',
      target_issue_id, audit_metadata, actor_id
    );
  end if;
  return target_issue_id;
end;
$$;

create or replace function public.transition_maintenance_issue(
  target_issue_id uuid,
  target_state public.maintenance_state,
  issue_actual_cost_pence integer default null,
  issue_completion_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  issue_record record;
  event_verb text;
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'authentication_required';
  end if;
  if issue_actual_cost_pence is not null and issue_actual_cost_pence < 0 then
    raise exception using errcode = '22023', message = 'maintenance_cost_invalid';
  end if;

  select issue.* into issue_record
  from public.maintenance_issues issue
  where issue.id = target_issue_id
    and public.has_organisation_role(
      issue.organisation_id,
      array['owner','admin','member']::public.member_role[]
    )
  for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'maintenance_unavailable';
  end if;
  if issue_record.state = target_state then
    return target_issue_id;
  end if;
  if issue_record.state in ('resolved', 'cancelled') and target_state <> 'reported' then
    raise exception using errcode = '22023', message = 'maintenance_reopen_required';
  end if;

  event_verb := case
    when target_state = 'reported' and issue_record.state in ('resolved', 'cancelled') then 'reopened'
    when target_state = 'resolved' then 'resolved'
    when target_state = 'cancelled' then 'cancelled'
    else 'progressed'
  end;

  update public.maintenance_issues
  set state = target_state,
      resolved_at = case when target_state = 'resolved' then now() else null end,
      actual_cost_pence = case
        when target_state in ('resolved', 'cancelled') then issue_actual_cost_pence
        else actual_cost_pence
      end,
      completion_notes = case
        when target_state in ('resolved', 'cancelled')
          then nullif(btrim(issue_completion_notes), '')
        else completion_notes
      end
  where id = target_issue_id;

  insert into public.timeline_events (
    organisation_id, property_id, event_type, title, description, source_type,
    source_id, metadata, actor_user_id
  ) values (
    issue_record.organisation_id, issue_record.property_id,
    'maintenance_' || event_verb,
    issue_record.title || ' ' || event_verb,
    'Maintenance issue marked ' || replace(target_state::text, '_', ' ') || '.',
    'maintenance', target_issue_id,
    jsonb_build_object(
      'previous_state', issue_record.state, 'state', target_state,
      'actual_cost_pence', issue_actual_cost_pence
    ), actor_id
  );
  return target_issue_id;
end;
$$;

create or replace function public.create_maintenance_task(
  target_maintenance_issue_id uuid,
  task_title text,
  task_description text default null,
  task_priority public.task_priority default 'medium',
  task_due_date date default null
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  issue_record record;
  created_task_id uuid;
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'authentication_required';
  end if;
  if nullif(btrim(task_title), '') is null then
    raise exception using errcode = '22023', message = 'task_title_required';
  end if;
  select issue.id, issue.organisation_id, issue.property_id
  into issue_record
  from public.maintenance_issues issue
  where issue.id = target_maintenance_issue_id
    and public.has_organisation_role(
      issue.organisation_id,
      array['owner','admin','member']::public.member_role[]
    );
  if not found then
    raise exception using errcode = 'P0002', message = 'maintenance_unavailable';
  end if;

  insert into public.tasks (
    organisation_id, property_id, maintenance_issue_id, title, description,
    priority, state, due_date, source_type, source_id, created_by
  ) values (
    issue_record.organisation_id, issue_record.property_id,
    target_maintenance_issue_id, btrim(task_title),
    nullif(btrim(task_description), ''), task_priority, 'open', task_due_date,
    'maintenance', target_maintenance_issue_id, actor_id
  ) returning id into created_task_id;

  insert into public.timeline_events (
    organisation_id, property_id, event_type, title, description, source_type,
    source_id, metadata, actor_user_id
  ) values (
    issue_record.organisation_id, issue_record.property_id,
    'maintenance_task_created', btrim(task_title) || ' created',
    'Task created from a maintenance issue.', 'task', created_task_id,
    jsonb_build_object('maintenance_issue_id', target_maintenance_issue_id),
    actor_id
  );
  return created_task_id;
end;
$$;

revoke all on function public.create_maintenance_issue(
  uuid,uuid,text,text,public.task_priority,date,date,uuid,integer,text
) from public, anon;
revoke all on function public.update_maintenance_issue(
  uuid,uuid,text,text,public.task_priority,date,date,uuid,integer,text
) from public, anon;
revoke all on function public.transition_maintenance_issue(
  uuid,public.maintenance_state,integer,text
) from public, anon;
revoke all on function public.create_maintenance_task(
  uuid,text,text,public.task_priority,date
) from public, anon;
grant execute on function public.create_maintenance_issue(
  uuid,uuid,text,text,public.task_priority,date,date,uuid,integer,text
) to authenticated;
grant execute on function public.update_maintenance_issue(
  uuid,uuid,text,text,public.task_priority,date,date,uuid,integer,text
) to authenticated;
grant execute on function public.transition_maintenance_issue(
  uuid,public.maintenance_state,integer,text
) to authenticated;
grant execute on function public.create_maintenance_task(
  uuid,text,text,public.task_priority,date
) to authenticated;

alter table public.documents
  add constraint documents_maintenance_evidence_shape
  check (
    document_type <> 'maintenance_evidence'
    or (
      scope = 'maintenance'
      and property_id is not null
      and maintenance_issue_id is not null
      and tenancy_id is null
      and compliance_record_id is null
      and expense_id is null
      and storage_bucket = 'property-documents'
      and mime_type in ('application/pdf', 'image/jpeg', 'image/png')
      and size_bytes between 1 and 10485760
      and storage_path =
        organisation_id::text || '/' || property_id::text || '/' ||
        maintenance_issue_id::text || '/' || id::text || '/' ||
        regexp_replace(original_filename, '[^A-Za-z0-9._-]+', '_', 'g')
    )
  );

drop policy if exists documents_insert on public.documents;
create policy documents_insert on public.documents
for insert to authenticated with check (
  created_by = (select auth.uid())
  and public.has_organisation_role(
    organisation_id,
    array['owner','admin','member']::public.member_role[]
  )
  and (
    (
      scope = 'compliance'
      and exists (
        select 1 from public.property_compliance_records compliance
        where compliance.id = compliance_record_id
          and compliance.organisation_id = documents.organisation_id
          and compliance.property_id = documents.property_id
      )
    )
    or (
      document_type = 'expense_evidence'
      and scope = 'property'
      and exists (
        select 1 from public.property_expenses expense
        where expense.id = expense_id
          and expense.organisation_id = documents.organisation_id
          and expense.property_id = documents.property_id
      )
    )
    or (
      document_type = 'maintenance_evidence'
      and scope = 'maintenance'
      and exists (
        select 1 from public.maintenance_issues issue
        where issue.id = maintenance_issue_id
          and issue.organisation_id = documents.organisation_id
          and issue.property_id = documents.property_id
      )
    )
  )
);

create or replace function public.can_access_maintenance_evidence(
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
  target_issue_id uuid;
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
    target_issue_id := path_parts[3]::uuid;
  exception when invalid_text_representation then
    return false;
  end;
  return exists (
    select 1
    from public.organisation_members member
    join public.maintenance_issues issue
      on issue.organisation_id = member.organisation_id
     and issue.id = target_issue_id
     and issue.property_id = target_property_id
    where member.organisation_id = target_organisation_id
      and member.user_id = auth.uid()
      and member.role = any(allowed_roles)
  );
end;
$$;

revoke all on function public.can_access_maintenance_evidence(
  text,public.member_role[]
) from public, anon;
grant execute on function public.can_access_maintenance_evidence(
  text,public.member_role[]
) to authenticated;

drop policy if exists storage_documents_select on storage.objects;
create policy storage_documents_select on storage.objects
for select to authenticated using (
  bucket_id = 'property-documents' and (
    public.can_access_compliance_evidence(
      name,array['owner','admin','member','viewer']::public.member_role[]
    )
    or public.can_access_expense_evidence(
      name,array['owner','admin','member','viewer']::public.member_role[]
    )
    or public.can_access_maintenance_evidence(
      name,array['owner','admin','member','viewer']::public.member_role[]
    )
  )
);

drop policy if exists storage_documents_insert on storage.objects;
create policy storage_documents_insert on storage.objects
for insert to authenticated with check (
  bucket_id = 'property-documents' and (
    public.can_access_compliance_evidence(
      name,array['owner','admin','member']::public.member_role[]
    )
    or public.can_access_expense_evidence(
      name,array['owner','admin','member']::public.member_role[]
    )
    or public.can_access_maintenance_evidence(
      name,array['owner','admin','member']::public.member_role[]
    )
  )
);

drop policy if exists storage_documents_delete on storage.objects;
create policy storage_documents_delete on storage.objects
for delete to authenticated using (
  bucket_id = 'property-documents' and (
    public.can_access_compliance_evidence(
      name,array['owner','admin']::public.member_role[]
    )
    or public.can_access_expense_evidence(
      name,array['owner','admin']::public.member_role[]
    )
    or public.can_access_maintenance_evidence(
      name,array['owner','admin']::public.member_role[]
    )
  )
);

drop policy if exists storage_documents_rollback on storage.objects;
create policy storage_documents_rollback on storage.objects
for delete to authenticated using (
  bucket_id = 'property-documents'
  and owner_id = (select auth.uid()::text)
  and (
    public.can_access_compliance_evidence(
      name,array['owner','admin','member']::public.member_role[]
    )
    or public.can_access_expense_evidence(
      name,array['owner','admin','member']::public.member_role[]
    )
    or public.can_access_maintenance_evidence(
      name,array['owner','admin','member']::public.member_role[]
    )
  )
  and not exists (
    select 1 from public.documents document
    where document.storage_bucket = bucket_id and document.storage_path = name
  )
);
