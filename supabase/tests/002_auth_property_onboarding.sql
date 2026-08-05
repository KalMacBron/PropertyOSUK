begin;

select plan(3);

select is(
  (
    select p.prosecdef
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'create_property_with_ownership'
  ),
  false,
  'onboarding RPC is security invoker'
);
select is(
  (
    select has_function_privilege('anon', p.oid, 'execute')
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'create_property_with_ownership'
  ),
  false,
  'anonymous role cannot execute onboarding RPC'
);
select is(
  (
    select has_function_privilege('authenticated', p.oid, 'execute')
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'create_property_with_ownership'
  ),
  true,
  'authenticated role can execute onboarding RPC'
);

select * from finish();

rollback;
