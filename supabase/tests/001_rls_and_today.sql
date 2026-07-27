begin;
select plan(7);

select has_table('public', 'properties', 'properties table exists');
select has_table('public', 'ownership_entities', 'ownership entities table exists');
select has_table('public', 'property_ownerships', 'property ownership join table exists');
select has_view('public', 'today_actions', 'Today action view exists');
select col_is_fk(
  'public', 'ownership_entities', 'organisation_id',
  'ownership entities are organisation scoped'
);
select col_is_fk(
  'public', 'property_ownerships', 'property_id',
  'property ownership links to a property'
);
select is(
  public.compliance_state_for(
    current_date + 31,
    null,
    now(),
    null,
    45
  )::text,
  'due_soon',
  'confirmed compliance expiring in 31 days is due soon'
);

select * from finish();
rollback;
