begin;

do $$
declare
  function_is_definer boolean;
  anon_can_execute boolean;
  authenticated_can_execute boolean;
begin
  select p.prosecdef,
    has_function_privilege('anon', p.oid, 'execute'),
    has_function_privilege('authenticated', p.oid, 'execute')
  into function_is_definer, anon_can_execute, authenticated_can_execute
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'create_property_with_ownership';

  if function_is_definer then raise exception 'Onboarding RPC must be security invoker'; end if;
  if anon_can_execute then raise exception 'Anonymous role must not execute onboarding RPC'; end if;
  if not authenticated_can_execute then raise exception 'Authenticated role must execute onboarding RPC'; end if;
end
$$;

rollback;
