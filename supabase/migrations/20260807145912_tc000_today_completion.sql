-- TC-000: durable completion for compliance-derived Today actions.

-- Current Supabase projects do not auto-expose new tables. These grants make
-- portfolio bootstrap explicit while the existing RLS policies remain the
-- authority for every row.
revoke all on public.organisations from anon;
revoke all on public.organisation_members from anon;
revoke all on public.properties from anon;
revoke all on public.ownership_entities from anon;
revoke all on public.property_ownerships from anon;

grant select on public.organisations to authenticated;
grant select on public.organisation_members to authenticated;
grant select, insert on public.properties to authenticated;
grant select, insert, update, delete on public.ownership_entities
  to authenticated;
grant select, insert on public.property_ownerships to authenticated;

update public.compliance_requirement_types
set default_warning_days = 45
where organisation_id is null
  and code = 'gas_safety';

create unique index tasks_today_compliance_completion_key
  on public.tasks (organisation_id, source_type, source_id, due_date)
  nulls not distinct
  where source_type = 'today_compliance';

drop view public.today_actions;

create view public.today_actions
with (security_invoker = true)
as
select
  c.organisation_id,
  c.property_id,
  'compliance'::text as source_type,
  c.id as source_id,
  c.requirement_type_id,
  evidence.id as evidence_document_id,
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
left join lateral (
  select document.id
  from public.documents document
  where document.organisation_id = c.organisation_id
    and document.compliance_record_id = c.id
    and document.scope = 'compliance'
  order by document.created_at desc, document.id
  limit 1
) evidence on true
where c.calculated_state in ('expired', 'missing', 'due_soon')
  and not exists (
    select 1
    from public.tasks completed
    where completed.organisation_id = c.organisation_id
      and completed.compliance_record_id = c.id
      and completed.source_type = 'today_compliance'
      and completed.source_id = c.id
      and completed.due_date is not distinct from c.action_date
      and completed.state = 'completed'
  )

union all

select
  task.organisation_id,
  task.property_id,
  'task'::text,
  task.id,
  null::uuid,
  null::uuid,
  task.priority,
  task.due_date,
  task.title,
  case when task.due_date < current_date then 'overdue' else 'open' end
from public.tasks task
where task.state in ('open', 'in_progress')
  and (task.due_date is null or task.due_date <= current_date + 45)

union all

select
  maintenance.organisation_id,
  maintenance.property_id,
  'maintenance'::text,
  maintenance.id,
  null::uuid,
  null::uuid,
  case when maintenance.priority = 'urgent'
    then 'urgent'::public.task_priority
    else 'high'::public.task_priority
  end,
  maintenance.target_date,
  maintenance.title,
  'open_' || maintenance.state::text
from public.maintenance_issues maintenance
where maintenance.priority in ('high', 'urgent')
  and maintenance.state not in ('resolved', 'cancelled')

union all

select
  tenancy.organisation_id,
  tenancy.property_id,
  'tenancy'::text,
  tenancy.id,
  null::uuid,
  null::uuid,
  case when tenancy.fixed_term_end_date <= current_date + 30
    then 'high'::public.task_priority
    else 'medium'::public.task_priority
  end,
  tenancy.fixed_term_end_date,
  'Review tenancy ending soon',
  'fixed_term_ending'
from public.tenancies tenancy
where tenancy.status = 'active'
  and tenancy.fixed_term_end_date between current_date and current_date + 60;

revoke all privileges on public.property_compliance_status from anon;
revoke all privileges on public.today_actions from anon;
revoke all privileges on public.tasks from anon;
revoke all privileges on public.timeline_events from anon;
revoke all privileges on public.maintenance_issues from anon;
revoke all privileges on public.tenancies from anon;
grant select on public.property_compliance_status to authenticated;
grant select on public.today_actions to authenticated;
grant select, insert on public.tasks to authenticated;
grant select, insert on public.timeline_events to authenticated;
grant select on public.maintenance_issues to authenticated;
grant select on public.tenancies to authenticated;

create or replace function public.complete_compliance_today_action(
  target_source_id uuid,
  target_due_date date
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  action_record record;
  completed_task_id uuid;
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'authentication_required';
  end if;

  select
    compliance.organisation_id,
    compliance.property_id,
    compliance.id as compliance_record_id,
    compliance.requirement_name,
    compliance.calculated_state,
    compliance.action_date,
    evidence.id as evidence_document_id
  into action_record
  from public.property_compliance_status compliance
  left join lateral (
    select document.id
    from public.documents document
    where document.organisation_id = compliance.organisation_id
      and document.compliance_record_id = compliance.id
      and document.scope = 'compliance'
    order by document.created_at desc, document.id
    limit 1
  ) evidence on true
  where compliance.id = target_source_id
    and compliance.action_date is not distinct from target_due_date
    and compliance.calculated_state in ('expired', 'missing', 'due_soon');

  if not found then
    raise exception using errcode = 'P0002', message = 'today_action_missing';
  end if;

  if not public.has_organisation_role(
    action_record.organisation_id,
    array['owner','admin','member']::public.member_role[]
  ) then
    raise exception using errcode = '42501', message = 'today_action_forbidden';
  end if;

  select task.id
  into completed_task_id
  from public.tasks task
  where task.organisation_id = action_record.organisation_id
    and task.source_type = 'today_compliance'
    and task.source_id = action_record.compliance_record_id
    and task.due_date is not distinct from action_record.action_date;

  if completed_task_id is not null then
    return completed_task_id;
  end if;

  insert into public.tasks (
    organisation_id,
    property_id,
    compliance_record_id,
    title,
    description,
    priority,
    state,
    due_date,
    source_type,
    source_id,
    completed_at,
    completed_by,
    created_by
  ) values (
    action_record.organisation_id,
    action_record.property_id,
    action_record.compliance_record_id,
    'Completed: Review ' || action_record.requirement_name,
    'Completed from Today. This records the management action only and does not certify compliance.',
    'medium',
    'completed',
    action_record.action_date,
    'today_compliance',
    action_record.compliance_record_id,
    now(),
    actor_id,
    actor_id
  )
  returning id into completed_task_id;

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
    action_record.organisation_id,
    action_record.property_id,
    'today_action_completed',
    action_record.requirement_name || ' action completed',
    'The recommended Today action was marked complete. This does not certify compliance.',
    'task',
    completed_task_id,
    jsonb_build_object(
      'compliance_record_id', action_record.compliance_record_id,
      'due_date', action_record.action_date,
      'evidence_document_id', action_record.evidence_document_id
    ),
    actor_id
  );

  return completed_task_id;
end;
$$;

revoke all on function public.complete_compliance_today_action(uuid, date)
  from public, anon;
grant execute on function public.complete_compliance_today_action(uuid, date)
  to authenticated;
