begin;
select plan(24);

insert into auth.users (
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values
('00000000-0000-0000-0000-000000000000','e1000000-0000-4000-8000-000000000001','authenticated','authenticated','export-owner@example.test',crypt('test',gen_salt('bf')),now(),'{"provider":"email","providers":["email"]}','{}',now(),now()),
('00000000-0000-0000-0000-000000000000','e1000000-0000-4000-8000-000000000002','authenticated','authenticated','export-admin@example.test',crypt('test',gen_salt('bf')),now(),'{"provider":"email","providers":["email"]}','{}',now(),now()),
('00000000-0000-0000-0000-000000000000','e1000000-0000-4000-8000-000000000003','authenticated','authenticated','export-member@example.test',crypt('test',gen_salt('bf')),now(),'{"provider":"email","providers":["email"]}','{}',now(),now()),
('00000000-0000-0000-0000-000000000000','e1000000-0000-4000-8000-000000000004','authenticated','authenticated','export-viewer@example.test',crypt('test',gen_salt('bf')),now(),'{"provider":"email","providers":["email"]}','{}',now(),now()),
('00000000-0000-0000-0000-000000000000','e1000000-0000-4000-8000-000000000005','authenticated','authenticated','export-outsider@example.test',crypt('test',gen_salt('bf')),now(),'{"provider":"email","providers":["email"]}','{}',now(),now());

insert into public.organisations (id,name,slug,created_by) values
('e2000000-0000-4000-8000-000000000001','Export Alpha','export-alpha','e1000000-0000-4000-8000-000000000001'),
('e2000000-0000-4000-8000-000000000002','Other Export','export-other','e1000000-0000-4000-8000-000000000005');
insert into public.organisation_members (organisation_id,user_id,role) values
('e2000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000001','owner'),
('e2000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000002','admin'),
('e2000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000003','member'),
('e2000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000004','viewer'),
('e2000000-0000-4000-8000-000000000002','e1000000-0000-4000-8000-000000000005','owner');
insert into public.properties (
  id,organisation_id,display_name,address_line_1,town_or_city,postcode,created_by
) values
('e3000000-0000-4000-8000-000000000001','e2000000-0000-4000-8000-000000000001','Oak House','1 Oak Road','London','SW1A 1AA','e1000000-0000-4000-8000-000000000001'),
('e3000000-0000-4000-8000-000000000002','e2000000-0000-4000-8000-000000000002','Other House','2 Oak Road','London','SW1A 1AB','e1000000-0000-4000-8000-000000000005');
insert into public.documents (
  id,organisation_id,scope,document_type,original_filename,storage_bucket,
  storage_path,mime_type,size_bytes,state,extracted_data,created_by
) values
('e4000000-0000-4000-8000-000000000001','e2000000-0000-4000-8000-000000000001','organisation','portfolio_record','portfolio.pdf','property-documents','e2000000-0000-4000-8000-000000000001/e4000000-0000-4000-8000-000000000001/portfolio.pdf','application/pdf',512,'uploaded','{"unconfirmed":"private"}','e1000000-0000-4000-8000-000000000001'),
('e4000000-0000-4000-8000-000000000002','e2000000-0000-4000-8000-000000000002','organisation','portfolio_record','other.pdf','property-documents','e2000000-0000-4000-8000-000000000002/e4000000-0000-4000-8000-000000000002/other.pdf','application/pdf',512,'uploaded','{}','e1000000-0000-4000-8000-000000000005');

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000001',true);

select lives_ok(
  $$select public.export_organisation_data('e2000000-0000-4000-8000-000000000001')$$,
  'owner exports structured organisation data'
);
select is(
  public.export_organisation_data('e2000000-0000-4000-8000-000000000001')->>'schema_version',
  'propertyos-alpha-export-v1',
  'export has a versioned schema'
);
select is(
  public.export_organisation_data('e2000000-0000-4000-8000-000000000001')->'organisation'->>'id',
  'e2000000-0000-4000-8000-000000000001',
  'export identifies the requested organisation'
);
select is(
  (public.export_organisation_data('e2000000-0000-4000-8000-000000000001')->'record_counts'->>'properties')::integer,
  1,
  'export counts only the target organisation properties'
);
select is(
  jsonb_array_length(public.export_organisation_data('e2000000-0000-4000-8000-000000000001')->'data'->'properties'),
  1,
  'export contains only target organisation property rows'
);
select is(
  position('storage_path' in public.export_organisation_data('e2000000-0000-4000-8000-000000000001')::text),
  0,
  'structured JSON excludes Storage paths'
);
select is(
  position('unconfirmed' in public.export_organisation_data('e2000000-0000-4000-8000-000000000001')::text),
  0,
  'structured JSON excludes unconfirmed extracted content'
);
select ok(
  (select count(*) from public.organisation_audit_events
   where organisation_id='e2000000-0000-4000-8000-000000000001'
     and event_type='organisation_data_exported') >= 1,
  'structured exports are audited'
);
select is(
  (select count(*) from public.list_organisation_export_documents('e2000000-0000-4000-8000-000000000001')),
  1::bigint,
  'owner receives organisation document manifest'
);
select is(
  (select original_filename from public.list_organisation_export_documents('e2000000-0000-4000-8000-000000000001') limit 1),
  'portfolio.pdf',
  'manifest contains safe document metadata'
);
select lives_ok(
  $$select public.prepare_organisation_document_export(
    'e2000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000001'
  )$$,
  'owner authorises one document export'
);
select is(
  public.prepare_organisation_document_export(
    'e2000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000001'
  )->>'storage_bucket',
  'property-documents',
  'authorised preparation returns the private bucket at runtime'
);
select ok(
  (select count(*) from public.organisation_audit_events
   where organisation_id='e2000000-0000-4000-8000-000000000001'
     and event_type='organisation_document_exported') >= 1,
  'document exports are audited'
);

select set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000002',true);
select lives_ok(
  $$select public.export_organisation_data('e2000000-0000-4000-8000-000000000001')$$,
  'admin can export organisation data'
);

select set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000003',true);
select throws_ok(
  $$select public.export_organisation_data('e2000000-0000-4000-8000-000000000001')$$,
  '42501','organisation_export_forbidden','member cannot export complete organisation data'
);
select throws_ok(
  $$select * from public.list_organisation_export_documents('e2000000-0000-4000-8000-000000000001')$$,
  '42501','organisation_export_forbidden','member cannot list complete document manifest'
);

select set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000004',true);
select throws_ok(
  $$select public.prepare_organisation_document_export(
    'e2000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000001'
  )$$,
  '42501','organisation_export_forbidden','viewer cannot prepare document export'
);

select set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000005',true);
select throws_ok(
  $$select public.export_organisation_data('e2000000-0000-4000-8000-000000000001')$$,
  '42501','organisation_export_forbidden','other organisation cannot export target data'
);

select set_config('request.jwt.claim.sub','e1000000-0000-4000-8000-000000000001',true);
select throws_ok(
  $$select public.prepare_organisation_document_export(
    'e2000000-0000-4000-8000-000000000001','e4000000-0000-4000-8000-000000000002'
  )$$,
  'P0002','document_export_unavailable','cross-organisation document ID is unavailable'
);
select ok(
  not has_function_privilege('anon','public.export_organisation_data(uuid)','execute'),
  'anonymous role cannot execute structured export'
);
select ok(
  not has_function_privilege('anon','public.list_organisation_export_documents(uuid)','execute'),
  'anonymous role cannot list export documents'
);
select ok(
  not has_function_privilege('anon','public.prepare_organisation_document_export(uuid,uuid)','execute'),
  'anonymous role cannot prepare document export'
);
select ok(
  has_function_privilege('authenticated','public.export_organisation_data(uuid)','execute'),
  'authenticated role has explicitly granted export RPC access'
);
select ok(
  has_function_privilege('authenticated','public.list_organisation_export_documents(uuid)','execute'),
  'authenticated role has explicitly granted manifest RPC access'
);

select * from finish();
rollback;
