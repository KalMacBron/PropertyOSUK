begin;
select plan(18);

insert into auth.users (
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values
('00000000-0000-0000-0000-000000000000','d1000000-0000-4000-8000-000000000001','authenticated','authenticated','contractor-owner@example.test',crypt('test',gen_salt('bf')),now(),'{"provider":"email","providers":["email"]}','{}',now(),now()),
('00000000-0000-0000-0000-000000000000','d1000000-0000-4000-8000-000000000002','authenticated','authenticated','contractor-member@example.test',crypt('test',gen_salt('bf')),now(),'{"provider":"email","providers":["email"]}','{}',now(),now()),
('00000000-0000-0000-0000-000000000000','d1000000-0000-4000-8000-000000000003','authenticated','authenticated','contractor-viewer@example.test',crypt('test',gen_salt('bf')),now(),'{"provider":"email","providers":["email"]}','{}',now(),now()),
('00000000-0000-0000-0000-000000000000','d1000000-0000-4000-8000-000000000004','authenticated','authenticated','contractor-outsider@example.test',crypt('test',gen_salt('bf')),now(),'{"provider":"email","providers":["email"]}','{}',now(),now());

insert into public.organisations (id,name,slug,created_by) values
('d2000000-0000-4000-8000-000000000001','Contractor Alpha','contractor-alpha','d1000000-0000-4000-8000-000000000001'),
('d2000000-0000-4000-8000-000000000002','Other Contractors','contractor-other','d1000000-0000-4000-8000-000000000004');
insert into public.organisation_members (organisation_id,user_id,role) values
('d2000000-0000-4000-8000-000000000001','d1000000-0000-4000-8000-000000000001','owner'),
('d2000000-0000-4000-8000-000000000001','d1000000-0000-4000-8000-000000000002','member'),
('d2000000-0000-4000-8000-000000000001','d1000000-0000-4000-8000-000000000003','viewer'),
('d2000000-0000-4000-8000-000000000002','d1000000-0000-4000-8000-000000000004','owner');

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','d1000000-0000-4000-8000-000000000001',true);

select lives_ok(
  $$select public.create_contractor(
    'd2000000-0000-4000-8000-000000000001','Safe Heating Ltd','Heating',
    ' ENGINEER@EXAMPLE.TEST ',' 020 7000 0000 ','Gas Safe details checked'
  )$$,
  'owner creates contractor'
);
select is((select count(*) from public.contractors),1::bigint,'contractor is created');
select is(
  (select created_by from public.contractors limit 1),
  'd1000000-0000-4000-8000-000000000001'::uuid,
  'RPC attributes creation to authenticated actor'
);
select is(
  (select email from public.contractors limit 1),
  'engineer@example.test',
  'email is trimmed and normalised'
);
select set_config('test.contractor_id',(select id::text from public.contractors limit 1),true);
select lives_ok(
  $$select public.update_contractor(
    current_setting('test.contractor_id')::uuid,'Safe Heating Ltd','Heating',
    'engineer@example.test','020 7000 0000','Temporarily unavailable','archived'
  )$$,
  'owner archives contractor without deleting it'
);
select is(
  (select status::text from public.contractors where id=current_setting('test.contractor_id')::uuid),
  'archived',
  'archived status persists'
);

select set_config('request.jwt.claim.sub','d1000000-0000-4000-8000-000000000002',true);
select lives_ok(
  $$select public.create_contractor(
    'd2000000-0000-4000-8000-000000000001','Clear Drains','Drainage'
  )$$,
  'member can create contractor'
);
select is((select count(*) from public.contractors),2::bigint,'member contractor is visible');

select set_config('request.jwt.claim.sub','d1000000-0000-4000-8000-000000000003',true);
select is((select count(*) from public.contractors),2::bigint,'viewer can read organisation contractors');
select throws_ok(
  $$select public.create_contractor(
    'd2000000-0000-4000-8000-000000000001','Blocked Contractor'
  )$$,
  '42501','contractor_write_forbidden','viewer cannot create contractor'
);
select throws_ok(
  $$select public.update_contractor(
    current_setting('test.contractor_id')::uuid,'Forged Update'
  )$$,
  'P0002','contractor_unavailable','viewer cannot update contractor'
);
select throws_ok(
  $$insert into public.contractors (organisation_id,name,created_by) values (
    'd2000000-0000-4000-8000-000000000001','Direct Insert',
    'd1000000-0000-4000-8000-000000000003'
  )$$,
  '42501',null,'viewer cannot bypass RPC with a direct insert'
);

select set_config('request.jwt.claim.sub','d1000000-0000-4000-8000-000000000004',true);
select is((select count(*) from public.contractors),0::bigint,'other organisation cannot read contractors');
select throws_ok(
  $$select public.update_contractor(
    current_setting('test.contractor_id')::uuid,'Cross organisation update'
  )$$,
  'P0002','contractor_unavailable','other organisation cannot infer or update contractor'
);

select ok(
  not has_function_privilege('anon','public.create_contractor(uuid,text,text,text,text,text)','execute'),
  'anonymous role cannot execute contractor creation'
);
select ok(
  has_function_privilege('authenticated','public.create_contractor(uuid,text,text,text,text,text)','execute'),
  'authenticated role has the explicitly granted RPC'
);

select set_config('request.jwt.claim.sub','d1000000-0000-4000-8000-000000000001',true);
select throws_ok(
  $$update public.contractors set name='Direct update' where id=current_setting('test.contractor_id')::uuid$$,
  '42501',null,'authorised users also cannot bypass RPC with direct updates'
);
select throws_ok(
  $$select public.create_contractor(
    'd2000000-0000-4000-8000-000000000001','   '
  )$$,
  '22023','contractor_name_required','blank contractor name is rejected'
);

select * from finish();
rollback;
