-- Milestone 3: activate and harden the property compliance register.

begin;

update public.compliance_requirement_types
set default_warning_days = 30
where organisation_id is null
  and code in ('gas_safety', 'eicr', 'epc', 'smoke_alarms', 'co_alarms');

alter table public.property_compliance_records
  add constraint property_compliance_records_has_action_date
  check (issue_date is not null or expiry_date is not null or review_date is not null);

create index compliance_requirement_type_idx
  on public.property_compliance_records (requirement_type_id);

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
    when coalesce(expiry_date, review_date) is null
      then 'missing'::public.compliance_state
    when coalesce(expiry_date, review_date) < current_date
      then 'expired'::public.compliance_state
    when coalesce(expiry_date, review_date) <= current_date + least(warning_days, 30)
      then 'due_soon'::public.compliance_state
    else 'compliant'::public.compliance_state
  end;
$$;

revoke all on public.compliance_requirement_types from anon;
revoke all on public.property_compliance_records from anon;
grant select on public.compliance_requirement_types to authenticated;
grant select, insert, update, delete
  on public.property_compliance_records to authenticated;

commit;
