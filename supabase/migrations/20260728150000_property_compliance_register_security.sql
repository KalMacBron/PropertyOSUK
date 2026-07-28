-- Milestone 3: deterministic warning window and schema constraints.

begin;

update public.compliance_requirement_types
set default_warning_days = 30
where organisation_id is null
  and code in ('gas_safety', 'eicr', 'epc', 'smoke_alarms', 'co_alarms');

alter table public.property_compliance_records
  add constraint property_compliance_records_has_action_date
  check (
    issue_date is not null
    or expiry_date is not null
    or review_date is not null
  );

create index compliance_requirement_type_idx
  on public.property_compliance_records (requirement_type_id);

revoke all on public.compliance_requirement_types from anon;
revoke all on public.property_compliance_records from anon;

commit;
