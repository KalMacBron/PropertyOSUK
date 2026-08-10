begin;
select plan(18);

insert into auth.users (instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('00000000-0000-0000-0000-000000000000','91000000-0000-4000-8000-000000000001','authenticated','authenticated','owner@admin.test',crypt('test',gen_salt('bf')),now(),'{"provider":"email","providers":["email"]}','{}',now(),now()),
('00000000-0000-0000-0000-000000000000','91000000-0000-4000-8000-000000000002','authenticated','authenticated','admin@admin.test',crypt('test',gen_salt('bf')),now(),'{"provider":"email","providers":["email"]}','{}',now(),now()),
('00000000-0000-0000-0000-000000000000','91000000-0000-4000-8000-000000000003','authenticated','authenticated','member@admin.test',crypt('test',gen_salt('bf')),now(),'{"provider":"email","providers":["email"]}','{}',now(),now()),
('00000000-0000-0000-0000-000000000000','91000000-0000-4000-8000-000000000004','authenticated','authenticated','viewer@admin.test',crypt('test',gen_salt('bf')),now(),'{"provider":"email","providers":["email"]}','{}',now(),now()),
('00000000-0000-0000-0000-000000000000','91000000-0000-4000-8000-000000000005','authenticated','authenticated','invitee@admin.test',crypt('test',gen_salt('bf')),now(),'{"provider":"email","providers":["email"]}','{}',now(),now());
insert into public.organisations(id,name,slug,created_by) values ('f1000000-0000-4000-8000-000000000001','Admin A','admin-a','91000000-0000-4000-8000-000000000001'),('f2000000-0000-4000-8000-000000000001','Admin B','admin-b','91000000-0000-4000-8000-000000000005');
insert into public.organisation_members(organisation_id,user_id,role) values
('f1000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000001','owner'),
('f1000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000002','admin'),
('f1000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000003','member'),
('f1000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000004','viewer'),
('f2000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000005','owner');

select is(has_function_privilege('anon','public.list_organisation_users(uuid)','execute'),false,'anon cannot list users');
set local role authenticated;
select set_config('request.jwt.claim.sub','91000000-0000-4000-8000-000000000001',true);
select is((select count(*) from public.list_organisation_users('f1000000-0000-4000-8000-000000000001')),4::bigint,'owner lists members');
select lives_ok($$select public.create_organisation_invitation('f1000000-0000-4000-8000-000000000001','invitee@admin.test','viewer')$$,'owner creates invitation');
select is((select count(*) from public.list_organisation_users('f1000000-0000-4000-8000-000000000001') where record_type='invitation'),1::bigint,'invitation listed');
select throws_ok($$select public.create_organisation_invitation('f1000000-0000-4000-8000-000000000001','x@admin.test','owner')$$,'42501','invitation_role_forbidden','owner role cannot be invited');

select set_config('request.jwt.claim.sub','91000000-0000-4000-8000-000000000002',true);
select lives_ok($$select public.change_organisation_member_role('f1000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000004','member')$$,'admin promotes viewer to member');
select throws_ok($$select public.change_organisation_member_role('f1000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000001','viewer')$$,'42501','role_change_forbidden','admin cannot change owner');
select throws_ok($$select public.create_organisation_invitation('f1000000-0000-4000-8000-000000000001','admin2@admin.test','admin')$$,'42501','invitation_role_forbidden','admin cannot invite admin');

select set_config('request.jwt.claim.sub','91000000-0000-4000-8000-000000000003',true);
select throws_ok($$select * from public.list_organisation_users('f1000000-0000-4000-8000-000000000001')$$,'42501','user_admin_forbidden','member cannot list user admin');
select throws_ok($$select public.remove_organisation_member('f1000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000004')$$,'42501','member_remove_forbidden','member cannot remove access');

select set_config('request.jwt.claim.sub','91000000-0000-4000-8000-000000000005',true);
select is((select public.accept_my_organisation_invitations()),1,'invitee accepts matching invitation');
select is((select role::text from public.organisation_members where organisation_id='f1000000-0000-4000-8000-000000000001' and user_id=auth.uid()),'viewer','accepted role is assigned');
select throws_ok($$select * from public.list_organisation_users('f1000000-0000-4000-8000-000000000001')$$,'42501','user_admin_forbidden','viewer cannot list user admin');

select set_config('request.jwt.claim.sub','91000000-0000-4000-8000-000000000001',true);
select is((select count(*) from public.organisation_audit_events where event_type='member_joined'),1::bigint,'acceptance audited and visible to owner');
select throws_ok($$select public.remove_organisation_member('f1000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000001')$$,'23514','organisation_requires_owner','final owner remains protected');
select lives_ok($$select public.remove_organisation_member('f1000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000003')$$,'owner removes member');
select is((select count(*) from public.organisation_audit_events where event_type in ('member_invited','member_role_changed','member_removed')),3::bigint,'administration changes audited');
select is((select count(*) from public.organisation_members where organisation_id='f2000000-0000-4000-8000-000000000001'),0::bigint,'foreign organisation remains hidden');

reset role;
select * from finish(); rollback;
