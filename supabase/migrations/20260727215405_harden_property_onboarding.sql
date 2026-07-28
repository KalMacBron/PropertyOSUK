-- Prevent anonymous Data API execution of the onboarding RPC.
revoke execute on function public.create_property_with_ownership(
  uuid, uuid, numeric, text, text, text, text, text, smallint
) from anon;
grant execute on function public.create_property_with_ownership(
  uuid, uuid, numeric, text, text, text, text, text, smallint
) to authenticated;
