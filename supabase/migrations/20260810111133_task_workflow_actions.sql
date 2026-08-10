-- Portfolio task workflow: organisation-authorised creation and atomic state
-- transitions that always write the matching property timeline event.

grant select, insert, update on public.tasks to authenticated;

-- Replace the original FOR ALL policy so SELECT evaluates only the dedicated
-- membership policy, while writes retain the same role boundary.
drop policy tasks_write on public.tasks;
create policy tasks_insert on public.tasks for insert to authenticated
with check (public.has_organisation_role(
  organisation_id,
  array['owner','admin','member']::public.member_role[]
));
create policy tasks_update on public.tasks for update to authenticated
using (public.has_organisation_role(
  organisation_id,
  array['owner','admin','member']::public.member_role[]
))
with check (public.has_organisation_role(
  organisation_id,
  array['owner','admin','member']::public.member_role[]
));
create policy tasks_delete on public.tasks for delete to authenticated
using (public.has_organisation_role(
  organisation_id,
  array['owner','admin','member']::public.member_role[]
));

create or replace function public.create_manual_task(
  target_organisation_id uuid,
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
  created_task_id uuid;
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'authentication_required';
  end if;

  if nullif(btrim(task_title), '') is null then
    raise exception using errcode = '22023', message = 'task_title_required';
  end if;

  if not public.has_organisation_role(
    target_organisation_id,
    array['owner','admin','member']::public.member_role[]
  ) then
    raise exception using errcode = '42501', message = 'task_create_forbidden';
  end if;

  if not exists (
    select 1
    from public.properties property
    where property.id = target_property_id
      and property.organisation_id = target_organisation_id
  ) then
    raise exception using errcode = '23503', message = 'task_property_missing';
  end if;

  insert into public.tasks (
    organisation_id,
    property_id,
    title,
    description,
    priority,
    state,
    due_date,
    source_type,
    created_by
  ) values (
    target_organisation_id,
    target_property_id,
    btrim(task_title),
    nullif(btrim(task_description), ''),
    task_priority,
    'open',
    task_due_date,
    'manual',
    actor_id
  )
  returning id into created_task_id;

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
    target_organisation_id,
    target_property_id,
    'task_created',
    btrim(task_title) || ' created',
    nullif(btrim(task_description), ''),
    'task',
    created_task_id,
    jsonb_build_object('priority', task_priority, 'due_date', task_due_date),
    actor_id
  );

  return created_task_id;
end;
$$;

create or replace function public.transition_task(
  target_task_id uuid,
  target_state public.task_state
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  task_record record;
  event_verb text;
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'authentication_required';
  end if;

  if target_state not in ('completed', 'cancelled', 'open') then
    raise exception using errcode = '22023', message = 'task_transition_invalid';
  end if;

  select task.id, task.organisation_id, task.property_id, task.title, task.state
  into task_record
  from public.tasks task
  where task.id = target_task_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'task_missing';
  end if;

  if task_record.property_id is null then
    raise exception using errcode = '22023', message = 'task_property_required';
  end if;

  if not public.has_organisation_role(
    task_record.organisation_id,
    array['owner','admin','member']::public.member_role[]
  ) then
    raise exception using errcode = '42501', message = 'task_transition_forbidden';
  end if;

  if task_record.state = target_state then
    return target_task_id;
  end if;

  if target_state = 'open' and task_record.state not in ('completed', 'cancelled') then
    raise exception using errcode = '22023', message = 'task_reopen_invalid';
  end if;

  update public.tasks
  set state = target_state,
      completed_at = case when target_state = 'completed' then now() else null end,
      completed_by = case when target_state = 'completed' then actor_id else null end
  where id = target_task_id;

  event_verb := case target_state
    when 'completed' then 'completed'
    when 'cancelled' then 'cancelled'
    else 'reopened'
  end;

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
    'task_' || event_verb,
    task_record.title || ' ' || event_verb,
    'Task marked ' || event_verb || ' in the Tasks workspace.',
    'task',
    target_task_id,
    jsonb_build_object('previous_state', task_record.state, 'state', target_state),
    actor_id
  );

  return target_task_id;
end;
$$;

revoke all on function public.create_manual_task(
  uuid, uuid, text, text, public.task_priority, date
) from public, anon;
grant execute on function public.create_manual_task(
  uuid, uuid, text, text, public.task_priority, date
) to authenticated;

revoke all on function public.transition_task(uuid, public.task_state)
  from public, anon;
grant execute on function public.transition_task(uuid, public.task_state)
  to authenticated;
