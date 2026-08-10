-- Edit user-managed task details atomically with property timeline audit.

create or replace function public.update_task_details(
  target_task_id uuid,
  target_property_id uuid,
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
  task_record record;
  changed_fields text[];
  audit_metadata jsonb;
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'authentication_required';
  end if;

  if nullif(btrim(task_title), '') is null then
    raise exception using errcode = '22023', message = 'task_title_required';
  end if;

  select
    task.id,
    task.organisation_id,
    task.property_id,
    task.title,
    task.description,
    task.priority,
    task.due_date,
    task.source_type,
    task.source_id
  into task_record
  from public.tasks task
  where task.id = target_task_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'task_missing';
  end if;

  if not public.has_organisation_role(
    task_record.organisation_id,
    array['owner','admin','member']::public.member_role[]
  ) then
    raise exception using errcode = '42501', message = 'task_update_forbidden';
  end if;

  if not exists (
    select 1
    from public.properties property
    where property.id = target_property_id
      and property.organisation_id = task_record.organisation_id
  ) then
    raise exception using errcode = '23503', message = 'task_property_missing';
  end if;

  changed_fields := array_remove(array[
    case when task_record.title is distinct from btrim(task_title)
      then 'title' end,
    case when task_record.property_id is distinct from target_property_id
      then 'property' end,
    case when task_record.priority is distinct from task_priority
      then 'priority' end,
    case when task_record.due_date is distinct from task_due_date
      then 'due_date' end,
    case when task_record.description is distinct from nullif(btrim(task_description), '')
      then 'notes' end
  ], null);

  if cardinality(changed_fields) = 0 then
    return target_task_id;
  end if;

  audit_metadata := jsonb_build_object(
    'changed_fields', to_jsonb(changed_fields),
    'old_property_id', task_record.property_id,
    'property_id', target_property_id,
    'old_title', task_record.title,
    'title', btrim(task_title),
    'old_priority', task_record.priority,
    'priority', task_priority,
    'old_due_date', task_record.due_date,
    'due_date', task_due_date
  );

  update public.tasks
  set property_id = target_property_id,
      title = btrim(task_title),
      description = nullif(btrim(task_description), ''),
      priority = task_priority,
      due_date = task_due_date
  where id = target_task_id;

  if task_record.property_id is not null then
    insert into public.timeline_events (
      organisation_id,
      property_id,
      event_type,
      title,
      description,
      source_type,
      source_id,
      metadata,
      actor_user_id
    ) values (
      task_record.organisation_id,
      task_record.property_id,
      'task_updated',
      btrim(task_title) || ' updated',
      'Task details updated in the Tasks workspace.',
      'task',
      target_task_id,
      audit_metadata,
      actor_id
    );
  end if;

  if task_record.property_id is distinct from target_property_id then
    insert into public.timeline_events (
      organisation_id,
      property_id,
      event_type,
      title,
      description,
      source_type,
      source_id,
      metadata,
      actor_user_id
    ) values (
      task_record.organisation_id,
      target_property_id,
      'task_updated',
      btrim(task_title) || ' moved to this property',
      'Task property association updated in the Tasks workspace.',
      'task',
      target_task_id,
      audit_metadata,
      actor_id
    );
  end if;

  return target_task_id;
end;
$$;

revoke all on function public.update_task_details(
  uuid, uuid, text, text, public.task_priority, date
) from public, anon;
grant execute on function public.update_task_details(
  uuid, uuid, text, text, public.task_priority, date
) to authenticated;
