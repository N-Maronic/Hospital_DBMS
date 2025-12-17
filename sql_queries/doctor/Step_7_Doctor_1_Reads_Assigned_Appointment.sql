-- 1. Setup Temp Table
create temporary table if not exists view_results (
    test text, 
    status text, 
    details text, 
    data jsonb
);
grant all on table view_results to authenticated;
truncate table view_results;

do $$
declare
  -- IDs
  doc1_uid uuid;
  doc1_profile_id uuid;
  doc2_uid uuid;
  doc2_profile_id uuid;
  
  -- Data Containers
  own_data jsonb;
  other_data jsonb;
begin
  ----------------------------------------------------------------
  -- A. SETUP (As Admin)
  ----------------------------------------------------------------
  -- Identify Doctor 1
  select id into doc1_uid from auth.users where email = 'doctor1@hospital.com';
  select id into doc1_profile_id from public.doctor where user_id = doc1_uid;

  -- Identify Doctor 2
  select id into doc2_uid from auth.users where email = 'doctor2@hospital.com';
  select id into doc2_profile_id from public.doctor where user_id = doc2_uid;

  -- Ensure Doctor 1 has data (To Read)
  if not exists (select 1 from public.appointment where doctor_id = doc1_profile_id) then
     insert into public.appointment (patient_id, doctor_id, scheduled_at, end_time, status)
     values ((select id from public.patient limit 1), doc1_profile_id, now(), now()+'30m', 'scheduled');
  end if;

  -- Ensure Doctor 2 has data (To NOT Read)
  if not exists (select 1 from public.appointment where doctor_id = doc2_profile_id) then
     insert into public.appointment (patient_id, doctor_id, scheduled_at, end_time, status)
     values ((select id from public.patient limit 1), doc2_profile_id, now(), now()+'30m', 'scheduled');
  end if;

  ----------------------------------------------------------------
  -- B. IMPERSONATE DOCTOR 1
  ----------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', doc1_uid::text, true);
  set role authenticated;

  ----------------------------------------------------------------
  -- C. TEST 1: READ OWN DATA
  ----------------------------------------------------------------
  select jsonb_agg(t) into own_data
  from (
      select * from public.appointment where doctor_id = doc1_profile_id
  ) t;

  if own_data is not null AND jsonb_array_length(own_data) > 0 then
    insert into view_results values (
        'Read Own Data', 
        'PASSED ✅', 
        'Doctor 1 found ' || jsonb_array_length(own_data) || ' own appointments.',
        own_data
    );
  else
    insert into view_results values (
        'Read Own Data', 
        'FAILED ❌', 
        'Doctor 1 cannot see their own data (RLS blocking?).',
        null
    );
  end if;

  ----------------------------------------------------------------
  -- D. TEST 2: READ DOCTOR 2 DATA
  ----------------------------------------------------------------
  select jsonb_agg(t) into other_data
  from (
      select * from public.appointment where doctor_id = doc2_profile_id
  ) t;

  -- For this test, "Success" means finding NOTHING (null)
  if other_data is null OR jsonb_array_length(other_data) = 0 then
    insert into view_results values (
        'Read Other Data', 
        'PASSED ✅', 
        'Security works: Doctor 1 sees 0 appointments for Doctor 2.',
        null
    );
  else
    insert into view_results values (
        'Read Other Data', 
        'FAILED ❌', 
        'Security Breach! Doctor 1 found Doctor 2s data!',
        other_data
    );
  end if;

end $$;

-- Show Final Results
select * from view_results;