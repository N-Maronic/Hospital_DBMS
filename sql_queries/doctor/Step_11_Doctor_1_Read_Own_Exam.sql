create temporary table if not exists view_results (test text, status text, details text);
grant all on table view_results to authenticated;
truncate table view_results;

do $$
declare
  -- Actors
  doc1_uid uuid;
  doc1_profile_id uuid;
  doc2_uid uuid;
  doc2_profile_id uuid;

  -- Target IDs to find
  own_exam_id uuid;
  other_exam_id uuid;
  
  -- Temp vars for fallback creation
  temp_appt_id uuid; 
  
  -- Results
  count_own int;
  count_other int;
begin
  ----------------------------------------------------------------
  -- 1. SETUP & DISCOVERY (As Admin)
  ----------------------------------------------------------------
  -- Identify Doctor 1
  select id into doc1_uid from auth.users where email = 'doctor1@hospital.com';
  select id into doc1_profile_id from public.doctor where user_id = doc1_uid;

  -- Identify Doctor 2
  select id into doc2_uid from auth.users where email = 'doctor2@hospital.com';
  select id into doc2_profile_id from public.doctor where user_id = doc2_uid;

  -- A. Find EXISTING Exam for Doctor 1
  select e.id into own_exam_id
  from public.examination e
  join public.appointment a on e.appointment_id = a.id
  where a.doctor_id = doc1_profile_id
  limit 1;

  -- Fallback: If Doc 1 has NO exams, create one so the test can run
  if own_exam_id is null then
     insert into public.appointment (patient_id, doctor_id, scheduled_at, end_time, status)
     values ((select id from public.patient limit 1), doc1_profile_id, now(), now()+'30m', 'scheduled')
     returning id into temp_appt_id;

     insert into public.examination (appointment_id, diagnosis, notes)
     values (temp_appt_id, 'My Patient', 'Notes') returning id into own_exam_id;
  end if;

  -- B. Find EXISTING Exam for Doctor 2
  select e.id into other_exam_id
  from public.examination e
  join public.appointment a on e.appointment_id = a.id
  where a.doctor_id = doc2_profile_id
  limit 1;

  -- Fallback: If Doc 2 has NO exams, create one so we have something to "hide"
  if other_exam_id is null then
     insert into public.appointment (patient_id, doctor_id, scheduled_at, end_time, status)
     values ((select id from public.patient limit 1), doc2_profile_id, now(), now()+'30m', 'scheduled')
     returning id into temp_appt_id;

     insert into public.examination (appointment_id, diagnosis, notes)
     values (temp_appt_id, 'Secret Patient', 'Secret Notes') returning id into other_exam_id;
  end if;


  ----------------------------------------------------------------
  -- 2. IMPERSONATE DOCTOR 1
  ----------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', doc1_uid::text, true);
  set role authenticated;


  ----------------------------------------------------------------
  -- 3. TEST A: READ OWN EXAM (Should be Visible)
  ----------------------------------------------------------------
  select count(*) into count_own 
  from public.examination 
  where id = own_exam_id;

  if count_own > 0 then
    insert into view_results values ('Read Own Exam', 'PASSED ✅', 'Successfully saw own exam.');
  else
    insert into view_results values ('Read Own Exam', 'FAILED ❌', 'Could not see own exam (Check RLS).');
  end if;


  ----------------------------------------------------------------
  -- 4. TEST B: READ DOCTOR 2 EXAM (Should be Hidden)
  ----------------------------------------------------------------
  select count(*) into count_other 
  from public.examination 
  where id = other_exam_id;

  if count_other = 0 then
    insert into view_results values ('Read Other Exam', 'PASSED ✅', 'Data hidden correctly. Saw 0 rows.');
  else
    insert into view_results values ('Read Other Exam', 'FAILED ❌', 'Security Breach! Saw Doc 2s exam.');
  end if;

end $$;

-- Show Results
select * from view_results;