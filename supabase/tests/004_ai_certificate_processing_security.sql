begin;

select plan(17);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  ('00000000-0000-0000-0000-000000000000', '51000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'm5-owner-a@example.test', crypt('test', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '51000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'm5-member-a@example.test', crypt('test', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '51000000-0000-4000-8000-000000000003', 'authenticated', 'authenticated', 'm5-viewer-a@example.test', crypt('test', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '52000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'm5-owner-b@example.test', crypt('test', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now());

insert into public.organisations (id, name, slug, created_by)
values
  ('a5000000-0000-4000-8000-000000000001', 'M5 organisation A', 'm5-organisation-a', '51000000-0000-4000-8000-000000000001'),
  ('b5000000-0000-4000-8000-000000000001', 'M5 organisation B', 'm5-organisation-b', '52000000-0000-4000-8000-000000000001');

insert into public.organisation_members (organisation_id, user_id, role)
values
  ('a5000000-0000-4000-8000-000000000001', '51000000-0000-4000-8000-000000000001', 'owner'),
  ('a5000000-0000-4000-8000-000000000001', '51000000-0000-4000-8000-000000000002', 'member'),
  ('a5000000-0000-4000-8000-000000000001', '51000000-0000-4000-8000-000000000003', 'viewer'),
  ('b5000000-0000-4000-8000-000000000001', '52000000-0000-4000-8000-000000000001', 'owner');

insert into public.properties (
  id, organisation_id, address_line_1, town_or_city, postcode, created_by
)
values
  ('a5100000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001', '5 Alpha Road', 'Walsall', 'WS1 1AA', '51000000-0000-4000-8000-000000000001'),
  ('b5100000-0000-4000-8000-000000000001', 'b5000000-0000-4000-8000-000000000001', '5 Beta Road', 'Walsall', 'WS1 1BB', '52000000-0000-4000-8000-000000000001');

insert into public.compliance_requirement_types (
  id, organisation_id, code, name, default_warning_days
)
values
  ('a5200000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001', 'm5-gas-a', 'M5 Gas A', 30),
  ('b5200000-0000-4000-8000-000000000001', 'b5000000-0000-4000-8000-000000000001', 'm5-gas-b', 'M5 Gas B', 30);

insert into public.property_compliance_records (
  id, organisation_id, property_id, requirement_type_id, issue_date,
  expiry_date, confirmed_at, created_by
)
values
  ('a5300000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001', 'a5100000-0000-4000-8000-000000000001', 'a5200000-0000-4000-8000-000000000001', current_date, current_date + 365, now(), '51000000-0000-4000-8000-000000000001'),
  ('b5300000-0000-4000-8000-000000000001', 'b5000000-0000-4000-8000-000000000001', 'b5100000-0000-4000-8000-000000000001', 'b5200000-0000-4000-8000-000000000001', current_date, current_date + 365, now(), '52000000-0000-4000-8000-000000000001');

insert into public.documents (
  id, organisation_id, property_id, compliance_record_id, scope,
  document_type, original_filename, storage_path, mime_type, size_bytes,
  created_by
)
values
  ('a5400000-0000-4000-8000-000000000001', 'a5000000-0000-4000-8000-000000000001', 'a5100000-0000-4000-8000-000000000001', 'a5300000-0000-4000-8000-000000000001', 'compliance', 'compliance_evidence', 'certificate.pdf', 'a5000000-0000-4000-8000-000000000001/a5100000-0000-4000-8000-000000000001/a5300000-0000-4000-8000-000000000001/a5400000-0000-4000-8000-000000000001/certificate.pdf', 'application/pdf', 100, '51000000-0000-4000-8000-000000000001'),
  ('b5400000-0000-4000-8000-000000000001', 'b5000000-0000-4000-8000-000000000001', 'b5100000-0000-4000-8000-000000000001', 'b5300000-0000-4000-8000-000000000001', 'compliance', 'compliance_evidence', 'certificate.pdf', 'b5000000-0000-4000-8000-000000000001/b5100000-0000-4000-8000-000000000001/b5300000-0000-4000-8000-000000000001/b5400000-0000-4000-8000-000000000001/certificate.pdf', 'application/pdf', 100, '52000000-0000-4000-8000-000000000001');

select ok(has_table_privilege('authenticated', 'public.certificate_analyses', 'SELECT'), 'authenticated can read authorised analysis rows');
select ok(not has_table_privilege('authenticated', 'public.certificate_analyses', 'INSERT'), 'authenticated cannot insert analysis rows directly');
select ok(not has_table_privilege('authenticated', 'public.certificate_analyses', 'UPDATE'), 'authenticated cannot update analysis rows directly');
select ok(not has_table_privilege('authenticated', 'public.certificate_analyses', 'DELETE'), 'authenticated cannot delete analysis rows directly');
select ok(not has_table_privilege('authenticated', 'public.certificate_analyses', 'TRUNCATE'), 'authenticated cannot truncate analyses');
select ok(not has_table_privilege('anon', 'public.certificate_analyses', 'SELECT'), 'anon has no analysis access');
select ok(not has_function_privilege('authenticated', 'public.reserve_certificate_analysis(uuid,uuid,uuid,uuid,uuid,uuid)', 'EXECUTE'), 'client cannot reserve quota directly');
select ok(not has_function_privilege('authenticated', 'public.confirm_certificate_analysis(uuid,uuid,jsonb)', 'EXECUTE'), 'client cannot call privileged confirmation directly');

select lives_ok(
  $$select public.reserve_certificate_analysis(
    'a5000000-0000-4000-8000-000000000001',
    'a5100000-0000-4000-8000-000000000001',
    'a5300000-0000-4000-8000-000000000001',
    'a5400000-0000-4000-8000-000000000001',
    '51000000-0000-4000-8000-000000000001',
    'a5500000-0000-4000-8000-000000000001'
  )$$,
  'service path can reserve an authorised analysis'
);

select is(
  (select count(*) from public.certificate_analyses where organisation_id = 'a5000000-0000-4000-8000-000000000001'),
  1::bigint,
  'reservation is stored once'
);

select lives_ok(
  $$select public.reserve_certificate_analysis(
    'a5000000-0000-4000-8000-000000000001',
    'a5100000-0000-4000-8000-000000000001',
    'a5300000-0000-4000-8000-000000000001',
    'a5400000-0000-4000-8000-000000000001',
    '51000000-0000-4000-8000-000000000001',
    'a5500000-0000-4000-8000-000000000001'
  )$$,
  'idempotent reservation succeeds'
);
select is(
  (select count(*) from public.certificate_analyses where organisation_id = 'a5000000-0000-4000-8000-000000000001'),
  1::bigint,
  'idempotent retry does not consume quota twice'
);

update public.certificate_analyses
set status = 'completed',
    suggestions = '{"issue_date":"2026-07-01","expiry_date":"2027-06-30","reference_number":"AI-123","printed_outcome":"Satisfactory","certificate_type":"gas_safety","readable":true}'
where organisation_id = 'a5000000-0000-4000-8000-000000000001';

select lives_ok(
  $$select public.confirm_certificate_analysis(
    (select id from public.certificate_analyses where organisation_id = 'a5000000-0000-4000-8000-000000000001'),
    '51000000-0000-4000-8000-000000000002',
    '{"reference_number":"CHECKED-123"}'
  )$$,
  'member can confirm selected values'
);
select is(
  (select reference_number from public.property_compliance_records where id = 'a5300000-0000-4000-8000-000000000001'),
  'CHECKED-123',
  'selected value updates the compliance record'
);
select is(
  (select expiry_date from public.property_compliance_records where id = 'a5300000-0000-4000-8000-000000000001'),
  current_date + 365,
  'unselected existing value is preserved'
);
select throws_ok(
  $$select public.confirm_certificate_analysis(
    (select id from public.certificate_analyses where organisation_id = 'a5000000-0000-4000-8000-000000000001'),
    '51000000-0000-4000-8000-000000000003',
    '{"reference_number":"VIEWER"}'
  )$$,
  '42501',
  'analysis_forbidden',
  'viewer cannot confirm an analysis'
);

delete from public.documents where id = 'a5400000-0000-4000-8000-000000000001';
select is(
  (select count(*) from public.certificate_analyses where organisation_id = 'a5000000-0000-4000-8000-000000000001'),
  0::bigint,
  'evidence deletion cascades analysis metadata'
);

select * from finish();
rollback;
