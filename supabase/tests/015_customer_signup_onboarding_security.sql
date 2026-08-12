begin;

select plan(13);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('00000000-0000-0000-0000-000000000000', '15000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'unconfirmed@signup.test', crypt('test', gen_salt('bf')), null, '{"provider":"email","providers":["email"]}', '{"display_name":"Unconfirmed User"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '15000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'customer@signup.test', crypt('test', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"display_name":"Customer Owner"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '15000000-0000-4000-8000-000000000003', 'authenticated', 'authenticated', 'other@signup.test', crypt('test', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now());

select is(
  has_function_privilege('anon', 'public.bootstrap_customer_organisation(text,text,text)', 'execute'),
  false,
  'anonymous users cannot execute customer bootstrap'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '15000000-0000-4000-8000-000000000001', true);
select throws_ok(
  $$select public.bootstrap_customer_organisation('Unconfirmed Portfolio','unconfirmed-portfolio','Unconfirmed User')$$,
  '42501', 'email_confirmation_required',
  'unconfirmed users cannot create an organisation'
);
select throws_ok(
  $$select public.create_organisation('Legacy Bypass','legacy-bypass')$$,
  '42501', 'email_confirmation_required',
  'established organisation RPC cannot bypass email confirmation'
);

select set_config('request.jwt.claim.sub', '15000000-0000-4000-8000-000000000002', true);
select lives_ok(
  $$select public.bootstrap_customer_organisation('Customer Portfolio','customer-portfolio','Customer Owner')$$,
  'confirmed customer can bootstrap an organisation'
);
select is(
  (select count(*) from public.organisation_members
    where user_id = '15000000-0000-4000-8000-000000000002' and role = 'owner'),
  1::bigint,
  'customer becomes the sole organisation owner'
);
select is(
  (select display_name from public.profiles
    where user_id = '15000000-0000-4000-8000-000000000002'),
  'Customer Owner',
  'display name is stored in the protected profile'
);
select ok(
  (select active_organisation_id is not null from public.profiles
    where user_id = '15000000-0000-4000-8000-000000000002'),
  'new organisation is selected as active'
);
select is(
  (select count(*) from public.organisation_audit_events
    where organisation_id = (
      select organisation_id from public.organisation_members
      where user_id = '15000000-0000-4000-8000-000000000002'
    ) and event_type = 'customer_organisation_created'),
  1::bigint,
  'customer bootstrap writes organisation audit evidence'
);
select throws_ok(
  $$select public.bootstrap_customer_organisation('Second Portfolio','second-portfolio','Customer Owner')$$,
  '42501', 'workspace_creation_controlled',
  'customer cannot bootstrap a second organisation'
);
select is(
  (select count(*) from public.organisations where created_by = auth.uid()),
  1::bigint,
  'failed repeat bootstrap creates no partial organisation'
);

select set_config('request.jwt.claim.sub', '15000000-0000-4000-8000-000000000003', true);
select is(
  (select count(*) from public.list_my_organisations()),
  0::bigint,
  'another customer cannot list the created organisation'
);
select is(
  (select count(*) from public.organisation_audit_events),
  0::bigint,
  'another customer cannot read bootstrap audit evidence'
);
select is(
  (select count(*) from public.organisation_members),
  0::bigint,
  'another customer cannot read the owner membership'
);

select * from finish();
rollback;
