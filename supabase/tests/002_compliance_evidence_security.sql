begin;

select plan(9);

select is(
  (select public from storage.buckets where id = 'property-documents'),
  false,
  'document bucket remains private'
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

select ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'documents'
      and policyname = 'documents_insert'
      and cmd = 'INSERT'
  ),
  'documents insert policy exists'
);

select ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'documents'
      and policyname = 'documents_delete'
      and cmd = 'DELETE'
  ),
  'documents delete policy exists'
);

select ok(
  not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'documents'
      and cmd = 'ALL'
  ),
  'documents has no broad ALL policy'
);

select ok(
  not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'storage_documents_update'
  ),
  'Storage overwrite policy is absent'
);

select is(
  public.can_access_compliance_evidence(
    'not/a/valid/path',
    array['owner']::public.member_role[]
  ),
  false,
  'malformed object path is rejected without UUID error'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.documents'::regclass
      and conname = 'documents_compliance_evidence_shape'
  ),
  'compliance evidence shape constraint exists'
);

select * from finish();

rollback;
