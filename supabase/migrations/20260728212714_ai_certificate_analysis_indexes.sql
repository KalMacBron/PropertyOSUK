create index certificate_analyses_property_organisation_idx
  on public.certificate_analyses (property_id, organisation_id);
create index certificate_analyses_compliance_organisation_idx
  on public.certificate_analyses (compliance_record_id, organisation_id);
create index certificate_analyses_document_organisation_idx
  on public.certificate_analyses (document_id, organisation_id);
create index certificate_analyses_confirmed_by_idx
  on public.certificate_analyses (confirmed_by);
