-- Supabase advisor fixes (26/11/2026).
--
-- 1. public.rls_auto_enable() is an event-trigger function that Supabase can
--    create from the dashboard to switch RLS on for new tables. It is not part
--    of the PropertyOS migrations, so it only exists on some projects. It must
--    not be callable through the Data API. Event triggers still fire without
--    EXECUTE being granted to API roles.
do $$
begin
  if to_regprocedure('public.rls_auto_enable()') is not null then
    revoke execute on function public.rls_auto_enable() from public, anon, authenticated;
  end if;
end
$$;

-- 2. Evaluate auth.uid() once per statement instead of once per row in the
--    profiles policies. The access rule itself is unchanged.
alter policy profiles_select_self on public.profiles
  using (user_id = (select auth.uid()));

alter policy profiles_update_self on public.profiles
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

alter policy profiles_insert_self on public.profiles
  with check (user_id = (select auth.uid()));
