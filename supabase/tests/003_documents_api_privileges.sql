begin;

select plan(7);

select ok(
  has_table_privilege('authenticated', 'public.documents', 'SELECT'),
  'authenticated can select documents'
);
select ok(
  has_table_privilege('authenticated', 'public.documents', 'INSERT'),
  'authenticated can insert documents'
);
select ok(
  has_table_privilege('authenticated', 'public.documents', 'DELETE'),
  'authenticated can delete documents'
);
select ok(
  not has_table_privilege('authenticated', 'public.documents', 'UPDATE'),
  'authenticated cannot update documents'
);
select ok(
  not has_table_privilege('authenticated', 'public.documents', 'TRUNCATE'),
  'authenticated cannot truncate documents'
);
select ok(
  not has_table_privilege('authenticated', 'public.documents', 'REFERENCES'),
  'authenticated cannot create references on documents'
);
select ok(
  not has_table_privilege('authenticated', 'public.documents', 'TRIGGER'),
  'authenticated cannot create triggers on documents'
);

select * from finish();
rollback;
