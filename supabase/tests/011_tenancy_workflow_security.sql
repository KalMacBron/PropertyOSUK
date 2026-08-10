begin;
select plan(17);

insert into auth.users (
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values
('00000000-0000-0000-0000-000000000000','b1000000-0000-4000-8000-000000000001','authenticated','authenticated','tenancy-owner@example.test',crypt('test',gen_salt('bf')),now(),'{"provider":"email","providers":["email"]}','{}',now(),now()),
('00000000-0000-0000-0000-000000000000','b1000000-0000-4000-8000-000000000002','authenticated','authenticated','tenancy-viewer@example.test',crypt('test',gen_salt('bf')),now(),'{"provider":"email","providers":["email"]}','{}',now(),now()),
('00000000-0000-0000-0000-000000000000','b1000000-0000-4000-8000-000000000003','authenticated','authenticated','tenancy-outsider@example.test',crypt('test',gen_salt('bf')),now(),'{"provider":"email","providers":["email"]}','{}',now(),now());

insert into public.organisations (id,name,slug,created_by) values
('b2000000-0000-4000-8000-000000000001','Tenancy Alpha','tenancy-alpha','b1000000-0000-4000-8000-000000000001'),
('b2000000-0000-4000-8000-000000000002','Other Portfolio','tenancy-other','b1000000-0000-4000-8000-000000000003');
insert into public.organisation_members (organisation_id,user_id,role) values
('b2000000-0000-4000-8000-000000000001','b1000000-0000-4000-8000-000000000001','owner'),
('b2000000-0000-4000-8000-000000000001','b1000000-0000-4000-8000-000000000002','viewer'),
('b2000000-0000-4000-8000-000000000002','b1000000-0000-4000-8000-000000000003','owner');
insert into public.properties (id,organisation_id,address_line_1,town_or_city,postcode,created_by) values
('b3000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001','1 Tenancy Street','London','SW1A 1AA','b1000000-0000-4000-8000-000000000001'),
('b3000000-0000-4000-8000-000000000002','b2000000-0000-4000-8000-000000000002','2 Other Street','London','SW1A 1AB','b1000000-0000-4000-8000-000000000003');

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','b1000000-0000-4000-8000-000000000001',true);

select lives_ok(
  $$select public.create_tenancy(
    'b2000000-0000-4000-8000-000000000001',
    'b3000000-0000-4000-8000-000000000001',
    'A. Tenant', current_date - 30, current_date + 45, 125000, 5::smallint
  )$$,
  'owner creates tenancy atomically'
);
select is((select count(*) from public.tenancies),1::bigint,'tenancy is created');
select is((select count(*) from public.tenants),1::bigint,'privacy-minimised tenant is created');
select is((select count(*) from public.tenancy_tenants where is_lead),1::bigint,'lead tenant link is created');
select is((select count(*) from public.timeline_events where event_type='tenancy_created'),1::bigint,'create timeline event is written');
select is((select count(*) from public.today_actions where source_type='tenancy'),1::bigint,'ending tenancy appears on Today');
select set_config('test.tenancy_id',(select id::text from public.tenancies limit 1),true);
select throws_ok(
  $$select public.create_tenancy(
    'b2000000-0000-4000-8000-000000000001',
    'b3000000-0000-4000-8000-000000000002',
    'Cross organisation', current_date, null, null, null
  )$$,
  '23503','tenancy_property_missing','cross-organisation property is rejected'
);

select lives_ok(
  $$select public.update_tenancy(
    (select id from public.tenancies limit 1),
    'b3000000-0000-4000-8000-000000000001',
    'A. Tenant', current_date - 30, current_date + 50, 130000, 7::smallint
  )$$,
  'owner updates tenancy atomically'
);
select is((select monthly_rent_pence from public.tenancies limit 1),130000,'monthly rent is stored as pence');
select is((select count(*) from public.timeline_events where event_type='tenancy_updated'),1::bigint,'update timeline event is written');

select set_config('request.jwt.claim.sub','b1000000-0000-4000-8000-000000000002',true);
select is((select count(*) from public.tenancies),1::bigint,'viewer can read organisation tenancy');
select throws_ok(
  $$select public.create_tenancy(
    'b2000000-0000-4000-8000-000000000001',
    'b3000000-0000-4000-8000-000000000001',
    'Blocked', current_date, null, null, null
  )$$,
  '42501','tenancy_create_forbidden','viewer cannot create tenancy'
);
select throws_ok(
  $$select public.end_tenancy(current_setting('test.tenancy_id')::uuid,current_date)$$,
  'P0002','tenancy_missing','viewer cannot lock or end tenancy'
);

select set_config('request.jwt.claim.sub','b1000000-0000-4000-8000-000000000003',true);
select is((select count(*) from public.tenancies),0::bigint,'other organisation cannot read tenancy');

select set_config('request.jwt.claim.sub','b1000000-0000-4000-8000-000000000001',true);
select lives_ok(
  $$select public.end_tenancy(current_setting('test.tenancy_id')::uuid,current_date)$$,
  'owner ends tenancy'
);
select is((select count(*) from public.timeline_events where event_type='tenancy_ended'),1::bigint,'end timeline event is written');
select is((select count(*) from public.today_actions where source_type='tenancy'),0::bigint,'ended tenancy leaves Today');

select * from finish();
rollback;
