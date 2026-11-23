begin;

select plan(9);

select ok(
  (select default_validity_months = 12 and default_warning_days = 31
   from public.compliance_requirement_types
   where organisation_id is null and code = 'gas_safety'),
  'gas safety lasts 12 months with a one month (31 day) reminder'
);
select ok(
  (select default_validity_months = 60 and default_warning_days = 31
   from public.compliance_requirement_types
   where organisation_id is null and code = 'eicr'),
  'EICR lasts 60 months with a one month (31 day) reminder'
);
select ok(
  (select default_validity_months = 120
   from public.compliance_requirement_types
   where organisation_id is null and code = 'epc'),
  'EPC lasts 120 months'
);
select ok(
  (select default_validity_months = 12 and default_warning_days = 31 and is_system
   from public.compliance_requirement_types
   where organisation_id is null and code = 'landlord_registration'),
  'landlord registration is a system type renewed every 12 months'
);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('00000000-0000-0000-0000-000000000000', '71000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'renewal-owner@example.test', crypt('test', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now());

insert into public.organisations (id, name, slug, created_by)
values ('72000000-0000-4000-8000-000000000001', 'Renewal Org', 'renewal-org', '71000000-0000-4000-8000-000000000001');
insert into public.organisation_members (organisation_id, user_id, role)
values ('72000000-0000-4000-8000-000000000001', '71000000-0000-4000-8000-000000000001', 'owner');
insert into public.properties (id, organisation_id, address_line_1, town_or_city, postcode, created_by)
values ('73000000-0000-4000-8000-000000000001', '72000000-0000-4000-8000-000000000001', '1 Renewal Road', 'Leeds', 'LS1 1AA', '71000000-0000-4000-8000-000000000001');

-- Expires in 45 days: outside the 31 day default, inside a 60 day override.
insert into public.property_compliance_records (
  id, organisation_id, property_id, requirement_type_id, issue_date,
  expiry_date, reminder_days, confirmed_at, confirmed_by, created_by
) values
  ('74000000-0000-4000-8000-000000000001', '72000000-0000-4000-8000-000000000001', '73000000-0000-4000-8000-000000000001',
   (select id from public.compliance_requirement_types where organisation_id is null and code = 'gas_safety'),
   current_date - 320, current_date + 45, null, now(), '71000000-0000-4000-8000-000000000001', '71000000-0000-4000-8000-000000000001'),
  ('74000000-0000-4000-8000-000000000002', '72000000-0000-4000-8000-000000000001', '73000000-0000-4000-8000-000000000001',
   (select id from public.compliance_requirement_types where organisation_id is null and code = 'eicr'),
   current_date - 1780, current_date + 45, 60, now(), '71000000-0000-4000-8000-000000000001', '71000000-0000-4000-8000-000000000001');

select ok(
  (select calculated_state = 'compliant' and effective_warning_days = 31
   from public.property_compliance_status
   where id = '74000000-0000-4000-8000-000000000001'),
  'a record without an override uses the type reminder'
);
select ok(
  (select calculated_state = 'due_soon' and effective_warning_days = 60
   from public.property_compliance_status
   where id = '74000000-0000-4000-8000-000000000002'),
  'a record-level reminder brings the due soon window forward'
);
select ok(
  exists (
    select 1 from public.today_actions
    where source_id = '74000000-0000-4000-8000-000000000002'
  )
  and not exists (
    select 1 from public.today_actions
    where source_id = '74000000-0000-4000-8000-000000000001'
  ),
  'Today follows the record-level reminder'
);

select throws_ok(
  $$update public.property_compliance_records set reminder_days = 400
    where id = '74000000-0000-4000-8000-000000000001'$$,
  '23514',
  null,
  'reminders longer than 365 days are rejected'
);

select ok(
  has_table_privilege('anon', 'public.property_compliance_status', 'select') = false
  and has_table_privilege('authenticated', 'public.today_actions', 'select'),
  'recreated views keep their grants'
);

select * from finish();
rollback;
