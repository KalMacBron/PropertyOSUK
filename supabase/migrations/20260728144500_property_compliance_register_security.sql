-- Milestone 3: make compliance writes explicit and organisation-safe.
drop policy if exists compliance_write on public.property_compliance_records;

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

grant select on public.compliance_requirement_types to authenticated;
grant select, insert, update, delete
on public.property_compliance_records to authenticated;
