begin;

select plan(14);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('00000000-0000-0000-0000-000000000000', '81000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'saas-multi@example.test', crypt('test', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '82000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'saas-owner-b@example.test', crypt('test', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '83000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'saas-foreign@example.test', crypt('test', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now());

insert into public.organisations (id, name, slug, created_by) values
  ('fa000000-0000-4000-8000-000000000001', 'SaaS Workspace A', 'saas-workspace-a', '81000000-0000-4000-8000-000000000001'),
  ('fb000000-0000-4000-8000-000000000001', 'SaaS Workspace B', 'saas-workspace-b', '82000000-0000-4000-8000-000000000001'),
  ('fc000000-0000-4000-8000-000000000001', 'Foreign Workspace', 'saas-foreign', '83000000-0000-4000-8000-000000000001');

insert into public.organisation_members (organisation_id, user_id, role) values
  ('fa000000-0000-4000-8000-000000000001', '81000000-0000-4000-8000-000000000001', 'owner'),
  ('fb000000-0000-4000-8000-000000000001', '81000000-0000-4000-8000-000000000001', 'owner'),
  ('fb000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000001', 'owner'),
  ('fc000000-0000-4000-8000-000000000001', '83000000-0000-4000-8000-000000000001', 'owner');

select is(
  (select count(*) from public.list_my_organisations()),
  0::bigint,
  'signed-out users cannot list organisations'
);
select is(
  has_function_privilege('anon', 'public.list_my_organisations()', 'execute'),
  false,
  'anonymous role cannot execute organisation listing'
);
select is(
  has_function_privilege('anon', 'public.set_active_organisation(uuid)', 'execute'),
  false,
  'anonymous role cannot set active organisation'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '81000000-0000-4000-8000-000000000001', true);

select is(
  (select count(*) from public.list_my_organisations()),
  2::bigint,
  'a user can list both authorised organisations'
);
select is(
  (select count(*) from public.list_my_organisations() where id = 'fc000000-0000-4000-8000-000000000001'),
  0::bigint,
  'organisation listing excludes foreign memberships'
);
select lives_ok(
  $$select public.set_active_organisation('fb000000-0000-4000-8000-000000000001')$$,
  'user can select an authorised organisation'
);
select is(
  (select active_organisation_id from public.profiles where user_id = auth.uid()),
  'fb000000-0000-4000-8000-000000000001'::uuid,
  'active organisation is persisted in the protected profile'
);
select is(
  (select count(*) from public.list_my_organisations() where is_active),
  1::bigint,
  'exactly one authorised organisation is active'
);
select throws_ok(
  $$select public.set_active_organisation('fc000000-0000-4000-8000-000000000001')$$,
  '42501', 'organisation_access_denied',
  'user cannot select a foreign organisation'
);
select throws_ok(
  $$select public.create_organisation('Extra Workspace', 'extra-workspace')$$,
  '42501', 'workspace_creation_controlled',
  'an existing member cannot self-create another workspace'
);

reset role;

select throws_ok(
  $$delete from public.organisation_members
    where organisation_id = 'fa000000-0000-4000-8000-000000000001'
      and user_id = '81000000-0000-4000-8000-000000000001'$$,
  '23514', 'organisation_requires_owner',
  'the final owner cannot be removed'
);
select throws_ok(
  $$update public.organisation_members set role = 'admin'
    where organisation_id = 'fa000000-0000-4000-8000-000000000001'
      and user_id = '81000000-0000-4000-8000-000000000001'$$,
  '23514', 'organisation_requires_owner',
  'the final owner cannot be demoted'
);
select lives_ok(
  $$update public.organisation_members set role = 'admin'
    where organisation_id = 'fb000000-0000-4000-8000-000000000001'
      and user_id = '82000000-0000-4000-8000-000000000001'$$,
  'an owner can be demoted when another owner remains'
);
select is(
  (select count(*) from public.organisation_members
    where organisation_id = 'fb000000-0000-4000-8000-000000000001'
      and role = 'owner'),
  1::bigint,
  'the organisation retains its other owner'
);

select * from finish();
rollback;
