begin;

select plan(7);

-- rls_auto_enable() only exists where Supabase created it, so the check is
-- conditional: it passes when the function is absent or not callable.
select ok(
  to_regprocedure('public.rls_auto_enable()') is null
  or not has_function_privilege('anon', 'public.rls_auto_enable()', 'execute'),
  'anon cannot execute rls_auto_enable()'
);
select ok(
  to_regprocedure('public.rls_auto_enable()') is null
  or not has_function_privilege('authenticated', 'public.rls_auto_enable()', 'execute'),
  'authenticated cannot execute rls_auto_enable()'
);

select is(
  (select count(*) from pg_policies
   where schemaname = 'public' and tablename = 'profiles'
     and policyname in ('profiles_select_self', 'profiles_update_self', 'profiles_insert_self')
     and (coalesce(qual, '') || coalesce(with_check, '')) like '%SELECT auth.uid()%'),
  3::bigint,
  'profiles policies wrap auth.uid() in a sub-select'
);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('00000000-0000-0000-0000-000000000000', '73000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'profile-a@example.test', crypt('test', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '73000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'profile-b@example.test', crypt('test', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now());

insert into public.profiles (user_id, display_name)
values ('73000000-0000-4000-8000-000000000002', 'Profile B');

set local role authenticated;
select set_config('request.jwt.claim.sub', '73000000-0000-4000-8000-000000000001', true);

select lives_ok(
  $$insert into public.profiles (user_id, display_name) values ('73000000-0000-4000-8000-000000000001', 'Profile A')$$,
  'a user can create their own profile'
);
select throws_ok(
  $$insert into public.profiles (user_id, display_name) values ('73000000-0000-4000-8000-000000000003', 'Other')$$,
  '42501',
  null,
  'a user cannot create a profile for someone else'
);
select is(
  (select array_agg(user_id::text) from public.profiles),
  array['73000000-0000-4000-8000-000000000001'],
  'a user sees only their own profile'
);

update public.profiles set display_name = 'Changed'
where user_id = '73000000-0000-4000-8000-000000000002';
reset role;
select is(
  (select display_name from public.profiles where user_id = '73000000-0000-4000-8000-000000000002'),
  'Profile B',
  'a user cannot update someone else''s profile'
);

select * from finish();
rollback;
