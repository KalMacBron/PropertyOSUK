-- Certificate renewal defaults and per-record reminders.
--
-- * Each requirement type can carry a default validity period. The interface
--   uses it to suggest an expiry date from the issue date; the user can always
--   override the suggested date before saving.
-- * Each compliance record can override its requirement type's reminder lead
--   time. A null value keeps the type default.
-- * Adds the England private rented sector landlord database registration as a
--   tracked, annually renewed requirement.
-- * Sets a one month reminder for the certificate types. One month is 31
--   days so that it covers every calendar month and keeps the Alpha
--   acceptance case (a Gas Safety record expiring in 31 days is due soon).

begin;

alter table public.compliance_requirement_types
  add column default_validity_months integer
    check (default_validity_months is null or default_validity_months > 0);

alter table public.property_compliance_records
  add column reminder_days integer
    check (reminder_days is null or reminder_days between 0 and 365);

update public.compliance_requirement_types
set default_validity_months = case code
      when 'gas_safety' then 12
      when 'eicr' then 60
      when 'epc' then 120
    end,
    default_warning_days = 31
where organisation_id is null
  and code in ('gas_safety', 'eicr', 'epc');

update public.compliance_requirement_types
set description = 'Energy Performance Certificate, valid for 10 years. Once it '
  || 'has expired, a new certificate is needed before a new tenancy starts.'
where organisation_id is null
  and code = 'epc';

insert into public.compliance_requirement_types
  (organisation_id, code, name, description, default_warning_days,
   default_validity_months, is_system)
values
  (null, 'landlord_registration', 'Landlord Registration',
   'Private rented sector landlord database registration (England), phased in '
   || 'from 15/12/2026. Renewed every year; the published fee is £65 per '
   || 'property per year.',
   31, 12, true)
on conflict (organisation_id, code) do update
set name = excluded.name,
    description = excluded.description,
    default_warning_days = excluded.default_warning_days,
    default_validity_months = excluded.default_validity_months,
    is_system = true;

-- Recreate the derived views so the record-level reminder takes precedence.
-- today_actions is reproduced unchanged from 20260807145912.
drop view public.today_actions;
drop view public.property_compliance_status;

create view public.property_compliance_status
with (security_invoker = true)
as
select
  r.*,
  t.code as requirement_code,
  t.name as requirement_name,
  t.default_warning_days,
  coalesce(r.reminder_days, t.default_warning_days) as effective_warning_days,
  public.compliance_state_for(
    r.expiry_date,
    r.review_date,
    r.confirmed_at,
    r.state_override,
    coalesce(r.reminder_days, t.default_warning_days)
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
grant select on public.property_compliance_status to authenticated;
grant select on public.today_actions to authenticated;

commit;
