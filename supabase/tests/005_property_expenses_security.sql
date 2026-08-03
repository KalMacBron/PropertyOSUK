begin;

select plan(15);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('00000000-0000-0000-0000-000000000000', '51000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'expense-owner-a@example.test', crypt('test', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '51000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'expense-member-a@example.test', crypt('test', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '51000000-0000-4000-8000-000000000003', 'authenticated', 'authenticated', 'expense-viewer-a@example.test', crypt('test', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '52000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'expense-owner-b@example.test', crypt('test', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now());

insert into public.organisations (id, name, slug, created_by) values
  ('ca000000-0000-4000-8000-000000000001', 'Expense A', 'expense-a', '51000000-0000-4000-8000-000000000001'),
  ('cb000000-0000-4000-8000-000000000001', 'Expense B', 'expense-b', '52000000-0000-4000-8000-000000000001');
insert into public.organisation_members (organisation_id, user_id, role) values
  ('ca000000-0000-4000-8000-000000000001', '51000000-0000-4000-8000-000000000001', 'owner'),
  ('ca000000-0000-4000-8000-000000000001', '51000000-0000-4000-8000-000000000002', 'member'),
  ('ca000000-0000-4000-8000-000000000001', '51000000-0000-4000-8000-000000000003', 'viewer'),
  ('cb000000-0000-4000-8000-000000000001', '52000000-0000-4000-8000-000000000001', 'owner');
insert into public.ownership_entities (
  id, organisation_id, entity_type, legal_name, created_by
) values
  ('ca100000-0000-4000-8000-000000000001', 'ca000000-0000-4000-8000-000000000001', 'individual', 'Owner A', '51000000-0000-4000-8000-000000000001'),
  ('cb100000-0000-4000-8000-000000000001', 'cb000000-0000-4000-8000-000000000001', 'individual', 'Owner B', '52000000-0000-4000-8000-000000000001');
insert into public.properties (
  id, organisation_id, address_line_1, town_or_city, postcode, created_by
) values
  ('ca200000-0000-4000-8000-000000000001', 'ca000000-0000-4000-8000-000000000001', '1 Expense Road', 'Walsall', 'WS1 1AA', '51000000-0000-4000-8000-000000000001'),
  ('cb200000-0000-4000-8000-000000000001', 'cb000000-0000-4000-8000-000000000001', '2 Expense Road', 'Walsall', 'WS1 1BB', '52000000-0000-4000-8000-000000000001');
insert into public.property_ownerships (
  organisation_id, property_id, ownership_entity_id, ownership_percentage,
  created_by
) values
  ('ca000000-0000-4000-8000-000000000001', 'ca200000-0000-4000-8000-000000000001', 'ca100000-0000-4000-8000-000000000001', 100, '51000000-0000-4000-8000-000000000001'),
  ('cb000000-0000-4000-8000-000000000001', 'cb200000-0000-4000-8000-000000000001', 'cb100000-0000-4000-8000-000000000001', 100, '52000000-0000-4000-8000-000000000001');

set local role authenticated;
select set_config('request.jwt.claim.sub', '51000000-0000-4000-8000-000000000001', true);
select lives_ok(
  $$insert into public.property_expenses (
    id, organisation_id, property_id, ownership_entity_id, expense_date,
    description, category, amount_pence, created_by
  ) values (
    'ca300000-0000-4000-8000-000000000001',
    'ca000000-0000-4000-8000-000000000001',
    'ca200000-0000-4000-8000-000000000001',
    'ca100000-0000-4000-8000-000000000001',
    current_date, 'Gas certificate', 'compliance_certificates', 9500,
    '51000000-0000-4000-8000-000000000001'
  )$$,
  'owner can create an expense'
);
select is(
  (select amount_pence from public.property_expenses
   where id = 'ca300000-0000-4000-8000-000000000001'),
  9500::bigint,
  'amount is stored in exact pence'
);

select set_config('request.jwt.claim.sub', '51000000-0000-4000-8000-000000000002', true);
select lives_ok(
  $$update public.property_expenses set amount_pence = 10000
    where id = 'ca300000-0000-4000-8000-000000000001'$$,
  'member can edit an expense'
);
delete from public.property_expenses
where id = 'ca300000-0000-4000-8000-000000000001';
select is(
  (select count(*) from public.property_expenses
   where id = 'ca300000-0000-4000-8000-000000000001'),
  1::bigint,
  'member cannot delete an expense'
);

select set_config('request.jwt.claim.sub', '51000000-0000-4000-8000-000000000003', true);
select is(
  (select count(*) from public.property_expenses),
  1::bigint,
  'viewer can read own organisation expenses'
);
select throws_ok(
  $$insert into public.property_expenses (
    organisation_id, property_id, ownership_entity_id, expense_date,
    description, category, amount_pence, created_by
  ) values (
    'ca000000-0000-4000-8000-000000000001',
    'ca200000-0000-4000-8000-000000000001',
    'ca100000-0000-4000-8000-000000000001',
    current_date, 'Blocked', 'other', 100,
    '51000000-0000-4000-8000-000000000003'
  )$$,
  '42501',
  null,
  'viewer cannot create an expense'
);
select is(
  (select count(*) from public.property_expenses
   where organisation_id = 'cb000000-0000-4000-8000-000000000001'),
  0::bigint,
  'viewer cannot see another organisation expenses'
);

select set_config('request.jwt.claim.sub', '51000000-0000-4000-8000-000000000001', true);
select throws_ok(
  $$insert into public.property_expenses (
    organisation_id, property_id, ownership_entity_id, expense_date,
    description, category, amount_pence, created_by
  ) values (
    'ca000000-0000-4000-8000-000000000001',
    'ca200000-0000-4000-8000-000000000001',
    'cb100000-0000-4000-8000-000000000001',
    current_date, 'Cross tenant', 'other', 100,
    '51000000-0000-4000-8000-000000000001'
  )$$,
  '23503',
  null,
  'cross-organisation ownership link is rejected'
);
select throws_ok(
  $$insert into public.property_expenses (
    organisation_id, property_id, ownership_entity_id, expense_date,
    description, category, amount_pence, created_by
  ) values (
    'ca000000-0000-4000-8000-000000000001',
    'ca200000-0000-4000-8000-000000000001',
    'ca100000-0000-4000-8000-000000000001',
    current_date, 'Zero', 'other', 0,
    '51000000-0000-4000-8000-000000000001'
  )$$,
  '23514',
  null,
  'zero value expense is rejected'
);
select is(
  public.can_access_expense_evidence(
    'ca000000-0000-4000-8000-000000000001/ca200000-0000-4000-8000-000000000001/ca300000-0000-4000-8000-000000000001/ca400000-0000-4000-8000-000000000001/receipt.pdf',
    array['owner','admin','member','viewer']::public.member_role[]
  ),
  true,
  'owner can access own expense evidence path'
);
select is(
  public.can_access_expense_evidence(
    'cb000000-0000-4000-8000-000000000001/cb200000-0000-4000-8000-000000000001/cb300000-0000-4000-8000-000000000001/cb400000-0000-4000-8000-000000000001/receipt.pdf',
    array['owner','admin','member','viewer']::public.member_role[]
  ),
  false,
  'owner cannot access another organisation evidence path'
);
select is(
  public.can_access_expense_evidence(
    'malformed/path',
    array['owner']::public.member_role[]
  ),
  false,
  'malformed expense evidence path is rejected'
);
select ok(
  has_table_privilege('authenticated', 'public.property_expenses', 'SELECT'),
  'authenticated has expense read privilege'
);
select ok(
  not has_table_privilege('anon', 'public.property_expenses', 'SELECT'),
  'anonymous users have no expense read privilege'
);

select set_config('request.jwt.claim.sub', '51000000-0000-4000-8000-000000000001', true);
delete from public.property_expenses
where id = 'ca300000-0000-4000-8000-000000000001';
select is(
  (select count(*) from public.property_expenses
   where id = 'ca300000-0000-4000-8000-000000000001'),
  0::bigint,
  'owner can delete an expense'
);

reset role;
select * from finish();
rollback;
