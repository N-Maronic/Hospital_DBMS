create temporary table if not exists view_results (test text, status text, details text);
grant all on table view_results to authenticated;
truncate table view_results;

do $$
declare
  -- Actors
  doc1_uid uuid;
  doc1_pid uuid;
  doc2_uid uuid;
  doc2_pid uuid;

  -- Target IDs
  exam_own uuid;   -- Valid target
  exam_other uuid; -- Illegal target
  
  -- Fallback var
  temp_appt uuid;
  
  -- Result var
  rows_affected int;
begin
  ----------------------------------------------------------------
  -- 1. SETUP & DISCOVERY (As Admin)
  ----------------------------------------------------------------
  -- Identify Doctor 1
  select id into doc1_uid from auth.users where email = 'doctor1@hospital.com';
  select id into doc1_pid from public.doctor where user_id = doc1_uid;

  -- Identify Doctor 2
  select id into doc2_uid from auth.users where email = 'doctor2@hospital.com';
  select id into doc2_pid from public.doctor where user_id = doc2_uid;

  -- A. Find EXISTING Exam for Doctor 1 (Own)
  select e.id into exam_own
  from public.examination e
  join public.appointment a on e.appointment_id = a.id
  where a.doctor_id = doc1_pid
  limit 1;

  -- Fallback: Only create if Doc 1 has ZERO exams
  if exam_own is null then
     insert into public.appointment (patient_id, doctor_id, scheduled_at, end_time, status)
     values ((select id from public.patient limit 1), doc1_pid, now(), now()+'30m', 'scheduled')
     returning id into temp_appt;

     insert into public.examination (appointment_id, diagnosis, notes)
     values (temp_appt, 'Own Patient', 'Original Note') returning id into exam_own;
  end if;

  -- B. Find EXISTING Exam for Doctor 2 (Other)
  select e.id into exam_other
  from public.examination e
  join public.appointment a on e.appointment_id = a.id
  where a.doctor_id = doc2_pid
  limit 1;

  -- Fallback: Only create if Doc 2 has ZERO exams
  if exam_other is null then
     insert into public.appointment (patient_id, doctor_id, scheduled_at, end_time, status)
     values ((select id from public.patient limit 1), doc2_pid, now(), now()+'30m', 'scheduled')
     returning id into temp_appt;

     insert into public.examination (appointment_id, diagnosis, notes)
     values (temp_appt, 'Other Patient', 'Original Note') returning id into exam_other;
  end if;


  ----------------------------------------------------------------
  -- 2. IMPERSONATE DOCTOR 1
  ----------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', doc1_uid::text, true);
  set role authenticated;


  ----------------------------------------------------------------
  -- 3. TEST A: Update OWN Exam (Should PASS)
  ----------------------------------------------------------------
  update public.examination 
  set notes = 'Updated by Doc 1 (Authorized)'
  where id = exam_own;

  get diagnostics rows_affected = row_count;

  if rows_affected > 0 then
    insert into view_results values ('Update Own Exam', 'PASSED ✅', 'Success: Updated ' || rows_affected || ' row(s).');
  else
    insert into view_results values ('Update Own Exam', 'FAILED ❌', 'Update touched 0 rows (RLS might be too strict).');
  end if;


  ----------------------------------------------------------------
  -- 4. TEST B: Update OTHER Exam (Should FAIL/BLOCK)
  ----------------------------------------------------------------
  update public.examination 
  set notes = 'HACKED BY DOC 1'
  where id = exam_other;

  get diagnostics rows_affected = row_count;

  if rows_affected = 0 then
    insert into view_results values ('Update Other Exam', 'PASSED ✅', 'Blocked correctly (0 rows affected).');
  else
    insert into view_results values ('Update Other Exam', 'FAILED ❌', 'Security Breach! Doc 1 updated Doc 2s exam.');
  end if;

end $$;

-- Show Results
select * from view_results;