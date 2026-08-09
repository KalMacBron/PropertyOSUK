begin;

select plan(21);

select ok(
  has_table_privilege('authenticated', 'public.organisations', 'select'),
  'authenticated can read its RLS-visible organisation'
);
select ok(
  has_table_privilege('authenticated', 'public.organisation_members', 'select'),
  'authenticated can read its RLS-visible membership'
);
select ok(
  has_table_privilege('authenticated', 'public.properties', 'select,insert'),
  'authenticated can create and read properties through RLS'
);
select ok(
  has_table_privilege('authenticated', 'public.ownership_entities', 'select,insert'),
  'authenticated can create and read ownership entities through RLS'
);
select ok(
  has_table_privilege('authenticated', 'public.property_ownerships', 'select,insert'),
  'authenticated can create and read property ownership through RLS'
);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('00000000-0000-0000-0000-000000000000', '61000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'tc000-owner-a@example.test', crypt('test', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '61000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'tc000-viewer-a@example.test', crypt('test', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '62000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'tc000-owner-b@example.test', crypt('test', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now());

insert into public.organisations (id, name, slug, created_by) values
  ('da000000-0000-4000-8000-000000000001', 'TC000 A', 'tc000-a', '61000000-0000-4000-8000-000000000001'),
  ('db000000-0000-4000-8000-000000000001', 'TC000 B', 'tc000-b', '62000000-0000-4000-8000-000000000001');
insert into public.organisation_members (organisation_id, user_id, role) values
  ('da000000-0000-4000-8000-000000000001', '61000000-0000-4000-8000-000000000001', 'owner'),
  ('da000000-0000-4000-8000-000000000001', '61000000-0000-4000-8000-000000000002', 'viewer'),
  ('db000000-0000-4000-8000-000000000001', '62000000-0000-4000-8000-000000000001', 'owner');
insert into public.properties (
  id, organisation_id, display_name, address_line_1, town_or_city, postcode,
  created_by
) values
  ('da100000-0000-4000-8000-000000000001', 'da000000-0000-4000-8000-000000000001', 'TC000 House', '1 Test Road', 'Walsall', 'WS1 1AA', '61000000-0000-4000-8000-000000000001'),
  ('db100000-0000-4000-8000-000000000001', 'db000000-0000-4000-8000-000000000001', 'Foreign House', '2 Test Road', 'Walsall', 'WS1 1BB', '62000000-0000-4000-8000-000000000001');

insert into public.property_compliance_records (
  id, organisation_id, property_id, requirement_type_id, issue_date,
  expiry_date, confirmed_at, confirmed_by, created_by
) values (
  'da200000-0000-4000-8000-000000000001',
  'da000000-0000-4000-8000-000000000001',
  'da100000-0000-4000-8000-000000000001',
  (select id from public.compliance_requirement_types where code = 'gas_safety' and organisation_id is null),
  current_date,
  current_date + 31,
  now(),
  '61000000-0000-4000-8000-000000000001',
  '61000000-0000-4000-8000-000000000001'
);
insert into public.documents (
  id, organisation_id, property_id, compliance_record_id, scope,
  document_type, original_filename, storage_path, mime_type, size_bytes,
  created_by
) values (
  'da300000-0000-4000-8000-000000000001',
  'da000000-0000-4000-8000-000000000001',
  'da100000-0000-4000-8000-000000000001',
  'da200000-0000-4000-8000-000000000001',
  'compliance', 'compliance_evidence', 'gas-safety.pdf',
  'da000000-0000-4000-8000-000000000001/da100000-0000-4000-8000-000000000001/da200000-0000-4000-8000-000000000001/da300000-0000-4000-8000-000000000001/gas-safety.pdf',
  'application/pdf', 100,
  '61000000-0000-4000-8000-000000000001'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '61000000-0000-4000-8000-000000000001', true);

select is(
  (select calculated_state::text from public.property_compliance_status
   where id = 'da200000-0000-4000-8000-000000000001'),
  'due_soon',
  '31-day Gas Safety record calculates due_soon'
);
select is(
  (select count(*) from public.today_actions
   where source_id = 'da200000-0000-4000-8000-000000000001'),
  1::bigint,
  'Today contains the compliance action'
);
select is(
  (select requirement_type_id from public.today_actions
   where source_id = 'da200000-0000-4000-8000-000000000001'),
  (select id from public.compliance_requirement_types where code = 'gas_safety' and organisation_id is null),
  'Today action links to the compliance requirement'
);
select is(
  (select evidence_document_id from public.today_actions
   where source_id = 'da200000-0000-4000-8000-000000000001'),
  'da300000-0000-4000-8000-000000000001'::uuid,
  'Today action links to private evidence'
);
select lives_ok(
  $$select public.complete_compliance_today_action(
    'da200000-0000-4000-8000-000000000001', current_date + 31
  )$$,
  'owner can complete the current Today action'
);
select is(
  (select count(*) from public.tasks
   where source_type = 'today_compliance'
     and source_id = 'da200000-0000-4000-8000-000000000001'
     and state = 'completed'),
  1::bigint,
  'completion creates one durable completed task'
);
select is(
  (select count(*) from public.timeline_events
   where property_id = 'da100000-0000-4000-8000-000000000001'
     and event_type = 'today_action_completed'),
  1::bigint,
  'completion creates a property timeline event'
);
select is(
  (select metadata ->> 'evidence_document_id' from public.timeline_events
   where property_id = 'da100000-0000-4000-8000-000000000001'
     and event_type = 'today_action_completed'),
  'da300000-0000-4000-8000-000000000001',
  'timeline event retains the evidence link'
);
select is(
  (select count(*) from public.today_actions
   where source_id = 'da200000-0000-4000-8000-000000000001'),
  0::bigint,
  'completed action is removed from Today'
);
select lives_ok(
  $$select public.complete_compliance_today_action(
    'da200000-0000-4000-8000-000000000001', current_date + 31
  )$$,
  'completion is idempotent'
);
select is(
  (select count(*) from public.tasks
   where source_type = 'today_compliance'
     and source_id = 'da200000-0000-4000-8000-000000000001'),
  1::bigint,
  'idempotent completion does not duplicate the task'
);
select is(
  (select count(*) from public.timeline_events
   where property_id = 'da100000-0000-4000-8000-000000000001'
     and event_type = 'today_action_completed'),
  1::bigint,
  'idempotent completion does not duplicate the timeline event'
);

select set_config('request.jwt.claim.sub', '61000000-0000-4000-8000-000000000002', true);
select throws_ok(
  $$select public.complete_compliance_today_action(
    'da200000-0000-4000-8000-000000000001', current_date + 31
  )$$,
  '42501', 'today_action_forbidden',
  'viewer cannot complete a Today action'
);

select set_config('request.jwt.claim.sub', '62000000-0000-4000-8000-000000000001', true);
select is(
  (select count(*) from public.property_compliance_records
   where id = 'da200000-0000-4000-8000-000000000001'),
  0::bigint,
  'other organisation cannot read the compliance record'
);
select is(
  (select count(*) from public.documents
   where id = 'da300000-0000-4000-8000-000000000001'),
  0::bigint,
  'other organisation cannot read the evidence row'
);
select is(
  (select count(*) from public.timeline_events
   where property_id = 'da100000-0000-4000-8000-000000000001'),
  0::bigint,
  'other organisation cannot read the timeline event'
);

reset role;
select * from finish();
rollback;
