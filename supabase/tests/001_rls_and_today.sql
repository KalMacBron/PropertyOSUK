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
select ok(
  exists (
    select 1
    from pg_constraint constraint_record
    join pg_class child_table
      on child_table.oid = constraint_record.conrelid
    join pg_namespace child_schema
      on child_schema.oid = child_table.relnamespace
    join pg_class parent_table
      on parent_table.oid = constraint_record.confrelid
    where constraint_record.contype = 'f'
      and child_schema.nspname = 'public'
      and child_table.relname = 'property_ownerships'
      and parent_table.relname = 'properties'
      and constraint_record.conkey = array[
        (
          select attribute.attnum
          from pg_attribute attribute
          where attribute.attrelid = child_table.oid
            and attribute.attname = 'property_id'
        ),
        (
          select attribute.attnum
          from pg_attribute attribute
          where attribute.attrelid = child_table.oid
            and attribute.attname = 'organisation_id'
        )
      ]::smallint[]
  ),
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
