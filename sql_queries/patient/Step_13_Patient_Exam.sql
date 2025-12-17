create temporary table if not exists view_results (test text, status text, details text);
grant all on table view_results to authenticated;
truncate table view_results;

do $$
declare
  -- Actors
  pat1_uid uuid;
  pat1_pid uuid;
  pat2_uid uuid;
  pat2_pid uuid;

  -- Targets
  own_exam_id uuid;
  own_appt_id uuid;
  other_exam_id uuid;

  -- Vars
  count_res int;
  rows_affected int;
begin
  ----------------------------------------------------------------
  -- 1. SETUP & DISCOVERY (As Admin)
  ----------------------------------------------------------------
  -- Get Patient 1 (Active User)
  select id into pat1_uid from auth.users where email = 'patient1@gmail.com';
  select id into pat1_pid from public.patient where user_id = pat1_uid;

  -- Get Patient 2 (The Victim)
  select id into pat2_uid from auth.users where email = 'patient2@gmail.com';
  select id into pat2_pid from public.patient where user_id = pat2_uid;

  -- A. Find EXISTING Exam for Patient 1
  select e.id, a.id into own_exam_id, own_appt_id
  from public.examination e
  join public.appointment a on e.appointment_id = a.id
  where a.patient_id = pat1_pid
  limit 1;

  -- Fallback: Create if missing
  if own_exam_id is null then
     -- Need an appt first
     insert into public.appointment (patient_id, doctor_id, scheduled_at, end_time, status)
     values (pat1_pid, (select id from public.doctor limit 1), now(), now()+'30m', 'scheduled')
     returning id into own_appt_id;

     insert into public.examination (appointment_id, diagnosis, notes)
     values (own_appt_id, 'Pat 1 Diagnosis', 'My Notes') returning id into own_exam_id;
  end if;

  -- B. Find EXISTING Exam for Patient 2
  select e.id into other_exam_id
  from public.examination e
  join public.appointment a on e.appointment_id = a.id
  where a.patient_id = pat2_pid
  limit 1;

  -- Fallback: Create if missing
  if other_exam_id is null then
     insert into public.appointment (patient_id, doctor_id, scheduled_at, end_time, status)
     values (pat2_pid, (select id from public.doctor limit 1), now(), now()+'30m', 'scheduled')
     returning id into own_appt_id; -- reusing var, value doesn't matter for this part

     insert into public.examination (appointment_id, diagnosis, notes)
     values (own_appt_id, 'Pat 2 Diagnosis', 'Secret Notes') returning id into other_exam_id;
  end if;


  ----------------------------------------------------------------
  -- 2. IMPERSONATE PATIENT 1
  ----------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', pat1_uid::text, true);
  set role authenticated;


  ----------------------------------------------------------------
  -- 3. TEST A: READ OWN EXAM (Should PASS)
  ----------------------------------------------------------------
  select count(*) into count_res from public.examination where id = own_exam_id;

  if count_res > 0 then
    insert into view_results values ('Read Own Exam', 'PASSED ✅', 'Patient found their exam.');
  else
    insert into view_results values ('Read Own Exam', 'FAILED ❌', 'Patient could not see own exam (Check RLS).');
  end if;


  ----------------------------------------------------------------
  -- 4. TEST B: READ OTHER EXAM (Should FAIL / Be Hidden)
  ----------------------------------------------------------------
  select count(*) into count_res from public.examination where id = other_exam_id;

  if count_res = 0 then
    insert into view_results values ('Read Other Exam', 'PASSED ✅', 'Privacy Working: Patient 1 saw 0 rows.');
  else
    insert into view_results values ('Read Other Exam', 'FAILED ❌', 'Security Breach! Patient 1 read Patient 2s exam.');
  end if;


  ----------------------------------------------------------------
  -- 5. TEST C: CREATE EXAM (Should FAIL)
  ----------------------------------------------------------------
  begin
    insert into public.examination (appointment_id, diagnosis, notes)
    values (own_appt_id, 'Hacked Diagnosis', 'I am creating my own medical records');
    
    insert into view_results values ('Create Exam', 'FAILED ❌', 'Patient was able to create an exam!');
  exception when others then
    insert into view_results values ('Create Exam', 'PASSED ✅', 'Blocked correctly: ' || SQLERRM);
  end;


  ----------------------------------------------------------------
  -- 6. TEST D: UPDATE EXAM (Should FAIL)
  ----------------------------------------------------------------
  begin
    update public.examination 
    set notes = 'Patient Hacked Notes'
    where id = own_exam_id;
    
    get diagnostics rows_affected = row_count;
    
    -- Two ways to pass: 1. Error raised. 2. 0 rows updated (RLS prevents write access)
    if rows_affected = 0 then
        insert into view_results values ('Update Exam', 'PASSED ✅', 'Blocked (0 rows affected).');
    else
        insert into view_results values ('Update Exam', 'FAILED ❌', 'Patient updated their exam!');
    end if;
  exception when others then
    insert into view_results values ('Update Exam', 'PASSED ✅', 'Blocked with Error: ' || SQLERRM);
  end;


  ----------------------------------------------------------------
  -- 7. TEST E: DELETE EXAM (Should FAIL)
  ----------------------------------------------------------------
  begin
    delete from public.examination where id = own_exam_id;
    
    get diagnostics rows_affected = row_count;

    if rows_affected = 0 then
        insert into view_results values ('Delete Exam', 'PASSED ✅', 'Blocked (0 rows affected).');
    else
        insert into view_results values ('Delete Exam', 'FAILED ❌', 'Patient deleted their exam!');
    end if;
  exception when others then
    insert into view_results values ('Delete Exam', 'PASSED ✅', 'Blocked with Error: ' || SQLERRM);
  end;

end $$;

-- Show Results
select * from view_results;