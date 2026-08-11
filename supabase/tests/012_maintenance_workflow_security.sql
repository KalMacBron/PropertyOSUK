begin;
select plan(35);

insert into auth.users (
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values
('00000000-0000-0000-0000-000000000000','c1000000-0000-4000-8000-000000000001','authenticated','authenticated','maintenance-owner@example.test',crypt('test',gen_salt('bf')),now(),' {"provider":"email","providers":["email"]}','{}',now(),now()),
('00000000-0000-0000-0000-000000000000','c1000000-0000-4000-8000-000000000002','authenticated','authenticated','maintenance-viewer@example.test',crypt('test',gen_salt('bf')),now(),' {"provider":"email","providers":["email"]}','{}',now(),now()),
('00000000-0000-0000-8000-000000000000','c1000000-0000-4000-8000-000000000003','authenticated','authenticated','maintenance-outsider@example.test',crypt('test',gen_salt('bf')),now(),' {"provider":"email","providers":["email"]}','{}',now(),now());

insert into public.organisations (id,name,slug,created_by) values
('c2000000-0000-4000-8000-000000000001','Maintenance Alpha','maintenance-alpha','c1000000-0000-4000-8000-000000000001'),
('c2000000-0000-4000-8000-000000000002','Other Maintenance','maintenance-other','c1000000-0000-4000-8000-000000000003');
insert into public.organisation_members (organisation_id,user_id,role) values
('c2000000-0000-4000-8000-000000000001','c1000000-0000-4000-8000-000000000001','owner'),
('c2000000-0000-4000-8000-000000000001','c1000000-0000-4000-8000-000000000002','viewer'),
('c2000000-0000-4000-8000-000000000002','c1000000-0000-4000-8000-000000000003','owner');
insert into public.properties (id,organisation_id,address_line_1,town_or_city,postcode,created_by) values
('c3000000-0000-4000-8000-000000000001','c2000000-0000-4000-8000-000000000001','1 Repair Street','London','SW1A 1AA','c1000000-0000-4000-8000-000000000001'),
('c3000000-0000-4000-8000-000000000002','c2000000-0000-4000-8000-000000000002','2 Other Street','London','SW1A 1AB','c1000000-0000-4000-8000-000000000003');
insert into public.contractors (id,organisation_id,name,trade,created_by) values
('c4000000-0000-4000-8000-000000000001','c2000000-0000-4000-8000-000000000001','Safe Heating Ltd','Heating','c1000000-0000-4000-8000-000000000001'),
('c4000000-0000-4000-8000-000000000002','c2000000-0000-4000-8000-000000000002','Other Contractor','Other','c1000000-0000-4000-8000-000000000003');

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','c1000000-0000-4000-8000-000000000001',true);

select lives_ok(
  $$select public.create_maintenance_issue(
    'c2000000-0000-4000-8000-000000000001',
    'c3000000-0000-4000-8000-000000000001',
    'Boiler pressure loss','Pressure drops overnight','urgent',current_date,
    current_date + 2,'c4000000-0000-4000-8000-000000000001',25000,'Tenant reported no heat'
  )$$,
  'owner creates maintenance issue atomically'
);
select is((select count(*) from public.maintenance_issues),1::bigint,'issue is created');
select is((select estimated_cost_pence from public.maintenance_issues limit 1),25000,'estimated cost is stored in pence');
select is((select count(*) from public.timeline_events where event_type='maintenance_created'),1::bigint,'create timeline event is written');
select is((select count(*) from public.today_actions where source_type='maintenance'),1::bigint,'urgent open issue appears on Today');
select set_config('test.maintenance_id',(select id::text from public.maintenance_issues limit 1),true);
select ok(
  public.can_access_maintenance_evidence(
    'c2000000-0000-4000-8000-000000000001/' ||
    'c3000000-0000-4000-8000-000000000001/' ||
    current_setting('test.maintenance_id') || '/' ||
    'c5000000-0000-4000-8000-000000000001/evidence.pdf',
    array['owner','admin','member']::public.member_role[]
  ),
  'owner can access a valid maintenance evidence path'
);
select lives_ok(
  $$select public.create_maintenance_task(
    current_setting('test.maintenance_id')::uuid,
    'Arrange engineer visit','Call the assigned contractor','high',current_date + 1
  )$$,
  'owner creates a linked maintenance task atomically'
);
select is((select count(*) from public.tasks where maintenance_issue_id is not null),1::bigint,'linked task retains maintenance issue context');
select is((select count(*) from public.timeline_events where event_type='maintenance_task_created'),1::bigint,'linked task timeline event is written');
select lives_ok(
  $$insert into public.documents (
    id,organisation_id,property_id,maintenance_issue_id,scope,document_type,
    original_filename,storage_bucket,storage_path,mime_type,size_bytes,state,created_by
  ) values (
    'c5000000-0000-4000-8000-000000000001',
    'c2000000-0000-4000-8000-000000000001',
    'c3000000-0000-4000-8000-000000000001',
    current_setting('test.maintenance_id')::uuid,'maintenance','maintenance_evidence',
    'evidence.pdf','property-documents',
    'c2000000-0000-4000-8000-000000000001/' ||
    'c3000000-0000-4000-8000-000000000001/' ||
    current_setting('test.maintenance_id') || '/' ||
    'c5000000-0000-4000-8000-000000000001/evidence.pdf',
    'application/pdf',100,'uploaded','c1000000-0000-4000-8000-000000000001'
  )$$,
  'owner records private maintenance evidence metadata'
);

select throws_ok(
  $$select public.create_maintenance_issue(
    'c2000000-0000-4000-8000-000000000001',
    'c3000000-0000-4000-8000-000000000002','Forged property'
  )$$,
  'P0002','maintenance_context_unavailable','cross-organisation property is rejected'
);
select throws_ok(
  $$select public.update_maintenance_issue(
    current_setting('test.maintenance_id')::uuid,
    'c3000000-0000-4000-8000-000000000001','Boiler pressure loss',null,
    'urgent',current_date,current_date + 2,
    'c4000000-0000-4000-8000-000000000002',25000,null
  )$$,
  'P0002','maintenance_context_unavailable','cross-organisation contractor is rejected'
);
select throws_ok(
  $$select public.create_maintenance_issue(
    'c2000000-0000-4000-8000-000000000001',
    'c3000000-0000-4000-8000-000000000001','Invalid cost',null,
    'medium',current_date,null,null,-1,null
  )$$,
  '22023','maintenance_cost_invalid','negative estimated cost is rejected'
);

select lives_ok(
  $$select public.update_maintenance_issue(
    current_setting('test.maintenance_id')::uuid,
    'c3000000-0000-4000-8000-000000000001','Boiler pressure loss',
    'Engineer visit arranged','high',current_date,current_date + 3,
    'c4000000-0000-4000-8000-000000000001',30000,'Appointment confirmed'
  )$$,
  'owner updates issue atomically'
);
select is((select priority::text from public.maintenance_issues limit 1),'high','updated priority is stored');
select is((select count(*) from public.timeline_events where event_type='maintenance_updated'),1::bigint,'update timeline event is written');
select lives_ok(
  $$select public.transition_maintenance_issue(
    current_setting('test.maintenance_id')::uuid,'in_progress'
  )$$,
  'owner progresses issue'
);
select is((select state::text from public.maintenance_issues limit 1),'in_progress','progressed state is stored');

select set_config('request.jwt.claim.sub','c1000000-0000-4000-8000-000000000002',true);
select is((select count(*) from public.maintenance_issues),1::bigint,'viewer can read organisation maintenance');
select is((select count(*) from public.documents where maintenance_issue_id is not null),1::bigint,'viewer can read maintenance evidence metadata');
select throws_ok(
  $$select public.create_maintenance_issue(
    'c2000000-0000-4000-8000-000000000001',
    'c3000000-0000-4000-8000-000000000001','Blocked'
  )$$,
  '42501','maintenance_write_forbidden','viewer cannot create maintenance'
);
select throws_ok(
  $$select public.transition_maintenance_issue(
    current_setting('test.maintenance_id')::uuid,'resolved',10000,'Blocked'
  )$$,
  'P0002','maintenance_unavailable','viewer cannot resolve maintenance'
);
select throws_ok(
  $$update public.maintenance_issues set title='Bypass' where id=current_setting('test.maintenance_id')::uuid$$,
  '42501',null,'direct maintenance updates are not exposed'
);

select set_config('request.jwt.claim.sub','c1000000-0000-4000-8000-000000000003',true);
select is((select count(*) from public.maintenance_issues),0::bigint,'other organisation cannot read issue');
select is((select count(*) from public.documents where maintenance_issue_id is not null),0::bigint,'other organisation cannot read maintenance evidence metadata');
select throws_ok(
  $$select public.transition_maintenance_issue(
    current_setting('test.maintenance_id')::uuid,'resolved',10000,'Forged'
  )$$,
  'P0002','maintenance_unavailable','other organisation cannot infer or mutate issue'
);

select set_config('request.jwt.claim.sub','c1000000-0000-4000-8000-000000000001',true);
select lives_ok(
  $$select public.transition_maintenance_issue(
    current_setting('test.maintenance_id')::uuid,'resolved',27500,'Pressure vessel replaced'
  )$$,
  'owner resolves issue atomically'
);
select is((select state::text from public.maintenance_issues limit 1),'resolved','resolved state is stored');
select isnt((select resolved_at from public.maintenance_issues limit 1),null::timestamptz,'resolution timestamp is stored');
select is((select actual_cost_pence from public.maintenance_issues limit 1),27500,'actual cost is stored in pence');
select is((select count(*) from public.today_actions where source_type='maintenance'),0::bigint,'resolved issue leaves Today');
select throws_ok(
  $$select public.transition_maintenance_issue(
    current_setting('test.maintenance_id')::uuid,'in_progress'
  )$$,
  '22023','maintenance_reopen_required','terminal issue requires explicit reopen'
);
select lives_ok(
  $$select public.transition_maintenance_issue(
    current_setting('test.maintenance_id')::uuid,'reported'
  )$$,
  'owner explicitly reopens issue'
);
select is((select state::text from public.maintenance_issues limit 1),'reported','reopened issue returns to reported');
select is((select count(*) from public.timeline_events where event_type='maintenance_reopened'),1::bigint,'reopen timeline event is written');

select * from finish();
rollback;
