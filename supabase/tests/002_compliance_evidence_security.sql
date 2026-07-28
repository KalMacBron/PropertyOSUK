begin;

select plan(22);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  ('00000000-0000-0000-0000-000000000000', '10000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'owner-a@example.test', crypt('test', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '10000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'member-a@example.test', crypt('test', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '10000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'viewer-a@example.test', crypt('test', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '10000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated', 'admin-a@example.test', crypt('test', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '20000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'owner-b@example.test', crypt('test', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now());

insert into public.organisations (id, name, slug, created_by)
values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'Test organisation A', 'test-organisation-a', '10000000-0000-0000-0000-000000000001'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'Test organisation B', 'test-organisation-b', '20000000-0000-0000-0000-000000000001');

insert into public.organisation_members (organisation_id, user_id, role)
values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '10000000-0000-0000-0000-000000000001', 'owner'),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '10000000-0000-0000-0000-000000000002', 'member'),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '10000000-0000-0000-0000-000000000003', 'viewer'),
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '10000000-0000-0000-0000-000000000004', 'admin'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '20000000-0000-0000-0000-000000000001', 'owner');

insert into public.properties (
  id, organisation_id, address_line_1, town_or_city, postcode, created_by
)
values
  ('a1000000-0000-4000-8000-000000000001', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '1 Alpha Road', 'Walsall', 'WS1 1AA', '10000000-0000-0000-0000-000000000001'),
  ('b1000000-0000-4000-8000-000000000001', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '2 Beta Road', 'Walsall', 'WS1 1BB', '20000000-0000-0000-0000-000000000001');

insert into public.compliance_requirement_types (
  id, organisation_id, code, name, default_warning_days
)
values
  ('a2000000-0000-4000-8000-000000000001', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'test-a', 'Test A', 30),
  ('b2000000-0000-4000-8000-000000000001', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'test-b', 'Test B', 30);

insert into public.property_compliance_records (
  id, organisation_id, property_id, requirement_type_id, issue_date,
  expiry_date, confirmed_at, created_by
)
values
  ('a3000000-0000-4000-8000-000000000001', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', current_date, current_date + 365, now(), '10000000-0000-0000-0000-000000000001'),
  ('b3000000-0000-4000-8000-000000000001', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'b1000000-0000-4000-8000-000000000001', 'b2000000-0000-4000-8000-000000000001', current_date, current_date + 365, now(), '20000000-0000-0000-0000-000000000001');

insert into public.documents (
  id, organisation_id, property_id, compliance_record_id, scope,
  document_type, original_filename, storage_path, mime_type, size_bytes,
  created_by
)
values (
  'b4000000-0000-4000-8000-000000000001',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  'b1000000-0000-4000-8000-000000000001',
  'b3000000-0000-4000-8000-000000000001',
  'compliance', 'compliance_evidence', 'foreign.pdf',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb/b1000000-0000-4000-8000-000000000001/b3000000-0000-4000-8000-000000000001/b4000000-0000-4000-8000-000000000001/foreign.pdf',
  'application/pdf', 100, '20000000-0000-0000-0000-000000000001'
);

select is(
  (select public from storage.buckets where id = 'property-documents'),
  false,
  'document bucket is private'
);
select is(
  (select file_size_limit from storage.buckets where id = 'property-documents'),
  10485760::bigint,
  'bucket limit is 10 MB'
);
select is(
  (select allowed_mime_types from storage.buckets where id = 'property-documents'),
  array['application/pdf', 'image/jpeg', 'image/png']::text[],
  'bucket MIME allowlist is exact'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select lives_ok(
  $$insert into public.documents (
    id, organisation_id, property_id, compliance_record_id, scope,
    document_type, original_filename, storage_path, mime_type, size_bytes,
    created_by
  ) values (
    'a4000000-0000-4000-8000-000000000001',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    'a1000000-0000-4000-8000-000000000001',
    'a3000000-0000-4000-8000-000000000001',
    'compliance', 'compliance_evidence', 'owner.pdf',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/a1000000-0000-4000-8000-000000000001/a3000000-0000-4000-8000-000000000001/a4000000-0000-4000-8000-000000000001/owner.pdf',
    'application/pdf', 100,
    '10000000-0000-0000-0000-000000000001'
  )$$,
  'owner can insert evidence metadata'
);

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000002', true);
select lives_ok(
  $$insert into public.documents (
    id, organisation_id, property_id, compliance_record_id, scope,
    document_type, original_filename, storage_path, mime_type, size_bytes,
    created_by
  ) values (
    'a4000000-0000-4000-8000-000000000002',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    'a1000000-0000-4000-8000-000000000001',
    'a3000000-0000-4000-8000-000000000001',
    'compliance', 'compliance_evidence', 'member.png',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/a1000000-0000-4000-8000-000000000001/a3000000-0000-4000-8000-000000000001/a4000000-0000-4000-8000-000000000002/member.png',
    'image/png', 100,
    '10000000-0000-0000-0000-000000000002'
  )$$,
  'member can insert evidence metadata'
);

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000003', true);
select throws_ok(
  $$insert into public.documents (
    id, organisation_id, property_id, compliance_record_id, scope,
    document_type, original_filename, storage_path, mime_type, size_bytes,
    created_by
  ) values (
    'a4000000-0000-4000-8000-000000000003',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    'a1000000-0000-4000-8000-000000000001',
    'a3000000-0000-4000-8000-000000000001',
    'compliance', 'compliance_evidence', 'viewer.jpg',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/a1000000-0000-4000-8000-000000000001/a3000000-0000-4000-8000-000000000001/a4000000-0000-4000-8000-000000000003/viewer.jpg',
    'image/jpeg', 100,
    '10000000-0000-0000-0000-000000000003'
  )$$,
  '42501',
  null,
  'viewer cannot insert evidence metadata'
);
select is(
  (select count(*) from public.documents where organisation_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  2::bigint,
  'viewer can read own organisation evidence'
);
select is(
  (select count(*) from public.documents where organisation_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),
  0::bigint,
  'viewer cannot read another organisation evidence'
);

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000002', true);
delete from public.documents where id = 'a4000000-0000-4000-8000-000000000002';
select is(
  (select count(*) from public.documents where id = 'a4000000-0000-4000-8000-000000000002'),
  1::bigint,
  'member cannot delete attached evidence metadata'
);

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
delete from public.documents where id = 'a4000000-0000-4000-8000-000000000001';
select is(
  (select count(*) from public.documents where id = 'a4000000-0000-4000-8000-000000000001'),
  0::bigint,
  'owner can delete evidence metadata'
);

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000003', true);
select is(
  public.can_access_compliance_evidence(
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/a1000000-0000-4000-8000-000000000001/a3000000-0000-4000-8000-000000000001/a4000000-0000-4000-8000-000000000004/view.pdf',
    array['owner','admin','member','viewer']::public.member_role[]
  ),
  true,
  'viewer can access own organisation Storage object'
);
select is(
  public.can_access_compliance_evidence(
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/a1000000-0000-4000-8000-000000000001/a3000000-0000-4000-8000-000000000001/a4000000-0000-4000-8000-000000000004/view.pdf',
    array['owner','admin','member']::public.member_role[]
  ),
  false,
  'viewer cannot upload Storage object'
);

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000002', true);
select is(
  public.can_access_compliance_evidence(
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/a1000000-0000-4000-8000-000000000001/a3000000-0000-4000-8000-000000000001/a4000000-0000-4000-8000-000000000004/member.pdf',
    array['owner','admin','member']::public.member_role[]
  ),
  true,
  'member can upload Storage object'
);
select is(
  public.can_access_compliance_evidence(
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb/b1000000-0000-4000-8000-000000000001/b3000000-0000-4000-8000-000000000001/b4000000-0000-4000-8000-000000000002/foreign.pdf',
    array['owner','admin','member','viewer']::public.member_role[]
  ),
  false,
  'member cannot access another organisation Storage path'
);
select is(
  public.can_access_compliance_evidence(
    'not/a/valid/path',
    array['owner']::public.member_role[]
  ),
  false,
  'malformed Storage path is rejected safely'
);

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000003', true);
select throws_ok(
  $$insert into storage.objects (bucket_id, name, owner_id)
    values (
      'property-documents',
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/a1000000-0000-4000-8000-000000000001/a3000000-0000-4000-8000-000000000001/a4000000-0000-4000-8000-000000000005/viewer.pdf',
      '10000000-0000-0000-0000-000000000003'
    )$$,
  '42501',
  null,
  'viewer cannot insert Storage object'
);

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000002', true);
select lives_ok(
  $$insert into storage.objects (bucket_id, name, owner_id)
    values (
      'property-documents',
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/a1000000-0000-4000-8000-000000000001/a3000000-0000-4000-8000-000000000001/a4000000-0000-4000-8000-000000000006/member.pdf',
      '10000000-0000-0000-0000-000000000002'
    )$$,
  'member can insert Storage object'
);
select ok(
  exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'storage_documents_rollback'
      and cmd = 'DELETE'
  ),
  'member orphan rollback policy is installed'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select throws_ok(
  $$delete from public.property_compliance_records
    where id = 'a3000000-0000-4000-8000-000000000001'$$,
  '23503',
  null,
  'compliance record cannot be deleted while evidence remains'
);

select throws_ok(
  $$insert into public.property_compliance_records (
    id, organisation_id, property_id, requirement_type_id, issue_date,
    expiry_date, confirmed_at, created_by
  ) values (
    'a3000000-0000-4000-8000-000000000002',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    'a1000000-0000-4000-8000-000000000001',
    'b2000000-0000-4000-8000-000000000001',
    current_date, current_date + 30, now(),
    '10000000-0000-0000-0000-000000000001'
  )$$,
  '42501',
  null,
  'cross-organisation requirement type is rejected'
);

select throws_ok(
  $$insert into public.documents (
    id, organisation_id, property_id, compliance_record_id, scope,
    document_type, original_filename, storage_path, mime_type, size_bytes,
    created_by
  ) values (
    'a4000000-0000-4000-8000-000000000007',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    'a1000000-0000-4000-8000-000000000001',
    'b3000000-0000-4000-8000-000000000001',
    'compliance', 'compliance_evidence', 'mismatch.pdf',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/a1000000-0000-4000-8000-000000000001/b3000000-0000-4000-8000-000000000001/a4000000-0000-4000-8000-000000000007/mismatch.pdf',
    'application/pdf', 100,
    '10000000-0000-0000-0000-000000000001'
  )$$,
  '42501',
  null,
  'cross-organisation compliance link is rejected'
);

select ok(
  not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'storage_documents_update'
  ),
  'no policy permits Storage object overwrite'
);

reset role;
select * from finish();
rollback;
