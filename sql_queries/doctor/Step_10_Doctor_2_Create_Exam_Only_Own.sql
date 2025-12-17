create temporary table if not exists view_results (test text, status text, details text);
grant all on table view_results to authenticated;
truncate table view_results;

do $$
declare
  -- IDs
  doc1_uid uuid;
  doc1_profile_id uuid;
  
  doc2_uid uuid;
  doc2_profile_id uuid;
  
  appt_id_own uuid;   -- Doctor 2's appointment (The valid one)
  appt_id_other uuid; -- Doctor 1's appointment (The target/illegal one)
  
  my_exam_id uuid;
  rows_affected int;
begin
  ----------------------------------------------------------------
  -- 1. SETUP DATA (As Admin)
  ----------------------------------------------------------------
  -- Get IDs for Doctor 1 (The Victim this time)
  select id into doc1_uid from auth.users where email = 'doctor1@hospital.com';
  select id into doc1_profile_id from public.doctor where user_id = doc1_uid;

  -- Get IDs for Doctor 2 (The Active User)
  select id into doc2_uid from auth.users where email = 'doctor2@hospital.com';
  select id into doc2_profile_id from public.doctor where user_id = doc2_uid;

  -- A. Fetch EXISTING appointment for Doctor 2 (Own)
  select id into appt_id_own from public.appointment where doctor_id = doc2_profile_id limit 1;
  
  -- Fallback: Ensure Doc 2 has an appointment
  if appt_id_own is null then
     insert into public.appointment (patient_id, doctor_id, scheduled_at, end_time, status)
     values ((select id from public.patient limit 1), doc2_profile_id, now(), now()+'30m', 'scheduled')
     returning id into appt_id_own;
  end if;

  -- B. Fetch EXISTING appointment for Doctor 1 (The Other)
  select id into appt_id_other from public.appointment where doctor_id = doc1_profile_id limit 1;
  
  -- Fallback: Ensure Doc 1 has an appointment
  if appt_id_other is null then
     insert into public.appointment (patient_id, doctor_id, scheduled_at, end_time, status)
     values ((select id from public.patient limit 1), doc1_profile_id, now(), now()+'30m', 'scheduled')
     returning id into appt_id_other;
  end if;


  ----------------------------------------------------------------
  -- 2. IMPERSONATE DOCTOR 2
  ----------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', doc2_uid::text, true);
  set role authenticated;


  ----------------------------------------------------------------
  -- 3. TEST A: Create Exam for OWN Appointment (Should PASS)
  ----------------------------------------------------------------
  begin
    insert into public.examination (appointment_id, diagnosis, notes)
    values (appt_id_own, 'Doc 2 Diagnosis', 'Notes by Doctor 2')
    returning id into my_exam_id;
    
    insert into view_results values ('Create Own Exam', 'PASSED ✅', 'Success. Exam ID: ' || my_exam_id);
  exception when others then
    insert into view_results values ('Create Own Exam', 'FAILED ❌', 'Error: ' || SQLERRM);
  end;


  ----------------------------------------------------------------
  -- 4. TEST B: Create Exam for DOCTOR 1 Appointment (Should FAIL)
  ----------------------------------------------------------------
  begin
    -- Doctor 2 tries to insert using Doctor 1's appointment ID
    insert into public.examination (appointment_id, diagnosis, notes)
    values (appt_id_other, 'Hacked Diagnosis', 'I am hacking Doctor 1');

    -- If we reach here, the DB allowed the insert (BAD)
    insert into view_results values ('Create Other Exam', 'FAILED ❌', 'Security Breach! Doc 2 created exam for Doc 1.');
  
  exception when others then
    -- If we catch an error, the DB blocked it (GOOD)
    insert into view_results values ('Create Other Exam', 'PASSED ✅', 'Blocked correctly: ' || SQLERRM);
  end;

end $$;

-- Show Results
select * from view_results;