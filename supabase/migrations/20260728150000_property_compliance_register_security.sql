-- Milestone 3: activate and harden the property compliance register.

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

drop policy if exists compliance_write
  on public.property_compliance_records;

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
        or requirement.organisation_id = organisation_id
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
        or requirement.organisation_id = organisation_id
      )
  )
);

create policy compliance_delete
on public.property_compliance_records
for delete
to authenticated
using (
  public.has_organisation_role(
    organisation_id,
    array['owner','admin','member']::public.member_role[]
  )
);

revoke all on public.compliance_requirement_types from anon;
revoke all on public.property_compliance_records from anon;
grant select on public.compliance_requirement_types to authenticated;
grant select, insert, update, delete
  on public.property_compliance_records to authenticated;

commit;
