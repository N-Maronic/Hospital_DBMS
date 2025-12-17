-- 1. SETUP: Create a temporary table structure to hold the output
create temporary table if not exists view_results as 
select * from public.appointment limit 0;

-- 2. CRITICAL: Grant permission so the "impersonated patient" can write to this table
grant all on table view_results to authenticated;

-- Clear any old data
truncate table view_results;

do $$
declare
  pat_uid uuid;
  pat_profile_id uuid;
  doc_profile_id uuid;
  new_appt_id uuid;
begin
  ----------------------------------------------------------------
  -- A. FETCH IDs (As Admin)
  ----------------------------------------------------------------
  -- Switch to Patient 2 email
  select id into pat_uid from auth.users where email = 'patient2@gmail.com';
  
  -- Get Patient 2's profile ID
  select id into pat_profile_id from public.patient where user_id = pat_uid;
  
  -- Get Doctor 1's profile ID
  select id into doc_profile_id from public.doctor where user_id = (select id from auth.users where email = 'doctor2@hospital.com');

  ----------------------------------------------------------------
  -- B. IMPERSONATE PATIENT 2
  ----------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', pat_uid::text, true);
  set role authenticated;

  ----------------------------------------------------------------
  -- C. CREATE APPOINTMENT
  ----------------------------------------------------------------
  insert into public.appointment (patient_id, doctor_id, scheduled_at, end_time, status, notes)
  values (
    pat_profile_id, 
    doc_profile_id, 
    now() + interval '5 days', 
    now() + interval '5 days 45 minutes', 
    'scheduled', 
    'Checkup for Patient 2'
  ) returning id into new_appt_id;

  ----------------------------------------------------------------
  -- D. READ APPOINTMENTS (Capture results to temp table)
  ----------------------------------------------------------------
  -- We query the real table, but insert the result into our temp view_results
  insert into view_results
  select * from public.appointment 
  where patient_id = pat_profile_id;

end $$;

-- 3. SHOW FINAL RESULTS
select * from view_results;