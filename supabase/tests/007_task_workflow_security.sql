begin;

select plan(13);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('00000000-0000-0000-0000-000000000000', '71000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'tasks-owner-a@example.test', crypt('test', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '71000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'tasks-viewer-a@example.test', crypt('test', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '72000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'tasks-owner-b@example.test', crypt('test', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now());

insert into public.organisations (id, name, slug, created_by) values
  ('ea000000-0000-4000-8000-000000000001', 'Tasks A', 'tasks-a', '71000000-0000-4000-8000-000000000001'),
  ('eb000000-0000-4000-8000-000000000001', 'Tasks B', 'tasks-b', '72000000-0000-4000-8000-000000000001');
insert into public.organisation_members (organisation_id, user_id, role) values
  ('ea000000-0000-4000-8000-000000000001', '71000000-0000-4000-8000-000000000001', 'owner'),
  ('ea000000-0000-4000-8000-000000000001', '71000000-0000-4000-8000-000000000002', 'viewer'),
  ('eb000000-0000-4000-8000-000000000001', '72000000-0000-4000-8000-000000000001', 'owner');
insert into public.properties (
  id, organisation_id, display_name, address_line_1, town_or_city, postcode,
  created_by
) values
  ('ea100000-0000-4000-8000-000000000001', 'ea000000-0000-4000-8000-000000000001', 'Tasks House', '1 Task Road', 'Walsall', 'WS1 1AA', '71000000-0000-4000-8000-000000000001'),
  ('eb100000-0000-4000-8000-000000000001', 'eb000000-0000-4000-8000-000000000001', 'Foreign House', '2 Task Road', 'Walsall', 'WS1 1BB', '72000000-0000-4000-8000-000000000001');

set local role authenticated;
select set_config('request.jwt.claim.sub', '71000000-0000-4000-8000-000000000001', true);

select lives_ok(
  $$select public.create_manual_task(
    'ea000000-0000-4000-8000-000000000001',
    'ea100000-0000-4000-8000-000000000001',
    'Arrange annual inspection', 'Call the contractor', 'high', current_date + 7
  )$$,
  'owner can create a manual task'
);
select is(
  (select count(*) from public.tasks where title = 'Arrange annual inspection'),
  1::bigint,
  'manual task is stored once'
);
select is(
  (select count(*) from public.timeline_events where event_type = 'task_created'),
  1::bigint,
  'task creation writes a timeline event'
);
select is(
  (select count(*) from public.today_actions where title = 'Arrange annual inspection'),
  1::bigint,
  'dated open task appears on Today'
);
select lives_ok(
  $$select public.transition_task(
    (select id from public.tasks where title = 'Arrange annual inspection'),
    'completed'
  )$$,
  'owner can complete a task'
);
select is(
  (select state::text from public.tasks where title = 'Arrange annual inspection'),
  'completed',
  'task is completed'
);
select is(
  (select count(*) from public.timeline_events where event_type = 'task_completed'),
  1::bigint,
  'completion writes a timeline event'
);
select is(
  (select count(*) from public.today_actions where title = 'Arrange annual inspection'),
  0::bigint,
  'completed task is removed from Today'
);
select lives_ok(
  $$select public.transition_task(
    (select id from public.tasks where title = 'Arrange annual inspection'),
    'open'
  )$$,
  'owner can reopen a completed task'
);
select is(
  (select count(*) from public.timeline_events where event_type = 'task_reopened'),
  1::bigint,
  'reopening writes a timeline event'
);

select set_config('request.jwt.claim.sub', '71000000-0000-4000-8000-000000000002', true);
select throws_ok(
  $$select public.create_manual_task(
    'ea000000-0000-4000-8000-000000000001',
    'ea100000-0000-4000-8000-000000000001',
    'Viewer task'
  )$$,
  '42501', 'task_create_forbidden',
  'viewer cannot create tasks'
);

select set_config('request.jwt.claim.sub', '72000000-0000-4000-8000-000000000001', true);
select is(
  (select count(*) from public.tasks where title = 'Arrange annual inspection'),
  0::bigint,
  'another organisation cannot read the task'
);
select throws_ok(
  $$select public.transition_task(
    (select id from public.tasks where organisation_id = 'ea000000-0000-4000-8000-000000000001' limit 1),
    'cancelled'
  )$$,
  'P0002', 'task_missing',
  'another organisation cannot transition the task'
);

reset role;
select * from finish();
rollback;
