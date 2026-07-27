-- Milestone 2: atomically create a property and its initial ownership link.
begin;

create or replace function public.create_property_with_ownership(
  target_organisation_id uuid,
  target_ownership_entity_id uuid,
  target_ownership_percentage numeric,
  property_address_line_1 text,
  property_town_or_city text,
  property_postcode text,
  property_display_name text default null,
  property_type_name text default null,
  property_bedrooms smallint default null
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  new_property_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not public.has_organisation_role(
    target_organisation_id,
    array['owner','admin','member']::public.member_role[]
  ) then
    raise exception 'Organisation write access required';
  end if;

  if not exists (
    select 1 from public.ownership_entities
    where id = target_ownership_entity_id
      and organisation_id = target_organisation_id
      and status = 'active'
  ) then
    raise exception 'Active ownership entity not found in organisation';
  end if;

  insert into public.properties (
    organisation_id, display_name, address_line_1, town_or_city,
    postcode, property_type, bedrooms, created_by
  ) values (
    target_organisation_id, nullif(trim(property_display_name), ''),
    trim(property_address_line_1), trim(property_town_or_city),
    upper(trim(property_postcode)), property_type_name, property_bedrooms, auth.uid()
  )
  returning id into new_property_id;

  insert into public.property_ownerships (
    organisation_id, property_id, ownership_entity_id,
    ownership_percentage, created_by
  ) values (
    target_organisation_id, new_property_id, target_ownership_entity_id,
    target_ownership_percentage, auth.uid()
  );

  insert into public.timeline_events (
    organisation_id, property_id, event_type, title,
    source_type, source_id, actor_user_id
  ) values (
    target_organisation_id, new_property_id, 'property_created',
    'Property added to portfolio', 'property', new_property_id, auth.uid()
  );

  return new_property_id;
end;
$$;

revoke all on function public.create_property_with_ownership(
  uuid, uuid, numeric, text, text, text, text, text, smallint
) from public;
grant execute on function public.create_property_with_ownership(
  uuid, uuid, numeric, text, text, text, text, text, smallint
) to authenticated;

commit;
