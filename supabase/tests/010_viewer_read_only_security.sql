begin;
select plan(9);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('00000000-0000-0000-0000-000000000000', 'a1000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'viewer-hardening-owner@example.test', crypt('test', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'a1000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'viewer-hardening-viewer@example.test', crypt('test', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now());

insert into public.organisations (id, name, slug, created_by)
values ('a2000000-0000-4000-8000-000000000001', 'Viewer hardening', 'viewer-hardening', 'a1000000-0000-4000-8000-000000000001');
insert into public.organisation_members (organisation_id, user_id, role) values
  ('a2000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', 'owner'),
  ('a2000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000002', 'viewer');
insert into public.ownership_entities (id, organisation_id, entity_type, legal_name, created_by)
values ('a3000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'individual', 'Test Owner', 'a1000000-0000-4000-8000-000000000001');
insert into public.properties (id, organisation_id, address_line_1, town_or_city, postcode, created_by)
values ('a4000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', '1 Test Street', 'London', 'SW1A 1AA', 'a1000000-0000-4000-8000-000000000001');

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', 'a1000000-0000-4000-8000-000000000002', true);

select is(
  (select count(*) from public.properties where organisation_id = 'a2000000-0000-4000-8000-000000000001'),
  1::bigint,
  'viewer can read organisation properties'
);
select is(
  (select count(*) from public.ownership_entities where organisation_id = 'a2000000-0000-4000-8000-000000000001'),
  1::bigint,
  'viewer can read organisation ownership entities'
);
select throws_ok(
  $$insert into public.properties (organisation_id, address_line_1, town_or_city, postcode, created_by)
    values ('a2000000-0000-4000-8000-000000000001', '2 Blocked Street', 'London', 'SW1A 1AB', 'a1000000-0000-4000-8000-000000000002')$$,
  '42501', null, 'viewer cannot create a property'
);
select throws_ok(
  $$update public.properties set display_name = 'Blocked' where id = 'a4000000-0000-4000-8000-000000000001'$$,
  '42501', null, 'viewer update is rejected'
);
select is(
  (select display_name from public.properties where id = 'a4000000-0000-4000-8000-000000000001'),
  null::text, 'viewer cannot update a property'
);
select throws_ok(
  $$delete from public.properties where id = 'a4000000-0000-4000-8000-000000000001'$$,
  '42501', null, 'viewer delete is rejected'
);
select is(
  (select count(*) from public.properties where id = 'a4000000-0000-4000-8000-000000000001'),
  1::bigint, 'viewer cannot delete a property'
);
select throws_ok(
  $$insert into public.ownership_entities (organisation_id, entity_type, legal_name, created_by)
    values ('a2000000-0000-4000-8000-000000000001', 'individual', 'Blocked Owner', 'a1000000-0000-4000-8000-000000000002')$$,
  '42501', null, 'viewer cannot create an ownership entity'
);
select throws_ok(
  $$insert into public.property_compliance_records (
      organisation_id, property_id, requirement_type_id, created_by
    ) values (
      'a2000000-0000-4000-8000-000000000001',
      'a4000000-0000-4000-8000-000000000001',
      (select id from public.compliance_requirement_types where is_system order by code limit 1),
      'a1000000-0000-4000-8000-000000000002'
    )$$,
  '42501', null, 'viewer cannot create a compliance record'
);

select * from finish();
rollback;
