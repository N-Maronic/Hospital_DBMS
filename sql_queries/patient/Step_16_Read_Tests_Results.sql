create temporary table if not exists view_results (test text, status text, details text);
grant all on table view_results to authenticated;
truncate table view_results;

do $$
declare
  -- Actors
  pat1_uid uuid; pat1_pid uuid;
  pat2_uid uuid; pat2_pid uuid;
  staff_uid uuid; staff_pid uuid;

  -- Data IDs
  appt_p1 uuid; exam_p1 uuid; test_p1 uuid; res_p1 uuid;
  appt_p2 uuid; exam_p2 uuid; test_p2 uuid; res_p2 uuid;
  
  -- Vars
  count_res int;
  rows_affected int;
begin
  ----------------------------------------------------------------
  -- 1. DISCOVERY & SETUP (As Admin)
  ----------------------------------------------------------------
  select id into pat1_uid from auth.users where email = 'patient1@gmail.com';
  select id into pat1_pid from public.patient where user_id = pat1_uid;
  
  select id into pat2_uid from auth.users where email = 'patient2@gmail.com';
  select id into pat2_pid from public.patient where user_id = pat2_uid;
  
  select id into staff_uid from auth.users where email = 'lab1@hospital.com';
  select id into staff_pid from public.lab_staff where user_id = staff_uid;

  -- A. PREPARE DATA FOR PATIENT 1 (Own)
  -- 1. Find Existing Appointment
  select id into appt_p1 from public.appointment where patient_id = pat1_pid limit 1;
  -- (Fallback only if DB is empty: create appt)
  if appt_p1 is null then insert into public.appointment (patient_id, doctor_id, scheduled_at, end_time, status) values (pat1_pid, (select id from public.doctor limit 1), now(), now()+'30m', 'scheduled') returning id into appt_p1; end if;

  -- 2. Find/Attach Exam
  select id into exam_p1 from public.examination where appointment_id = appt_p1 limit 1;
  if exam_p1 is null then insert into public.examination (appointment_id, diagnosis) values (appt_p1, 'P1 Existing Dx') returning id into exam_p1; end if;

  -- 3. Find/Attach Test
  select id into test_p1 from public.lab_test where examination_id = exam_p1 limit 1;
  if test_p1 is null then insert into public.lab_test (examination_id, test_type, status, priority, lab_staff_id) values (exam_p1, 'P1 Test', 'completed', 'routine', staff_pid) returning id into test_p1; end if;

  -- 4. Find/Attach Result
  select id into res_p1 from public.lab_result where lab_test_id = test_p1 limit 1;
  if res_p1 is null then insert into public.lab_result (lab_test_id, results, interpretation) values (test_p1, 'P1 Results', 'Normal') returning id into res_p1; end if;


  -- B. PREPARE DATA FOR PATIENT 2 (Other)
  -- 1. Find Existing Appointment
  select id into appt_p2 from public.appointment where patient_id = pat2_pid limit 1;
  -- (Fallback)
  if appt_p2 is null then insert into public.appointment (patient_id, doctor_id, scheduled_at, end_time, status) values (pat2_pid, (select id from public.doctor limit 1), now(), now()+'30m', 'scheduled') returning id into appt_p2; end if;

  -- 2. Find/Attach Exam
  select id into exam_p2 from public.examination where appointment_id = appt_p2 limit 1;
  if exam_p2 is null then insert into public.examination (appointment_id, diagnosis) values (appt_p2, 'P2 Existing Dx') returning id into exam_p2; end if;

  -- 3. Find/Attach Test
  select id into test_p2 from public.lab_test where examination_id = exam_p2 limit 1;
  if test_p2 is null then insert into public.lab_test (examination_id, test_type, status, priority, lab_staff_id) values (exam_p2, 'P2 Test', 'completed', 'routine', staff_pid) returning id into test_p2; end if;

  -- 4. Find/Attach Result
  select id into res_p2 from public.lab_result where lab_test_id = test_p2 limit 1;
  if res_p2 is null then insert into public.lab_result (lab_test_id, results, interpretation) values (test_p2, 'P2 Results', 'Normal') returning id into res_p2; end if;


  ----------------------------------------------------------------
  -- 2. IMPERSONATE PATIENT 1
  ----------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', pat1_uid::text, true);
  set role authenticated;


  ----------------------------------------------------------------
  -- 3. TEST A: READ OWN DATA (Should PASS)
  ----------------------------------------------------------------
  -- Check Test
  select count(*) into count_res from public.lab_test where id = test_p1;
  if count_res > 0 then insert into view_results values ('Read Own Test', 'PASSED ✅', 'Found own test.');
  else insert into view_results values ('Read Own Test', 'FAILED ❌', 'Could not see own test (Check RLS).'); end if;

  -- Check Result
  select count(*) into count_res from public.lab_result where id = res_p1;
  if count_res > 0 then insert into view_results values ('Read Own Result', 'PASSED ✅', 'Found own result.');
  else insert into view_results values ('Read Own Result', 'FAILED ❌', 'Could not see own result (Check RLS).'); end if;


  ----------------------------------------------------------------
  -- 4. TEST B: READ PATIENT 2 DATA (Should FAIL/Hide)
  ----------------------------------------------------------------
  -- Check Test
  select count(*) into count_res from public.lab_test where id = test_p2;
  if count_res = 0 then insert into view_results values ('Read Other Test', 'PASSED ✅', 'Privacy working (0 rows).');
  else insert into view_results values ('Read Other Test', 'FAILED ❌', 'Security Breach! Saw P2s test.'); end if;

  -- Check Result
  select count(*) into count_res from public.lab_result where id = res_p2;
  if count_res = 0 then insert into view_results values ('Read Other Result', 'PASSED ✅', 'Privacy working (0 rows).');
  else insert into view_results values ('Read Other Result', 'FAILED ❌', 'Security Breach! Saw P2s result.'); end if;


  ----------------------------------------------------------------
  -- 5. TEST C: CREATE (Should FAIL)
  ----------------------------------------------------------------
  begin
    insert into public.lab_test (examination_id, test_type, status, priority, lab_staff_id)
    values (exam_p1, 'P1 Illegal Test', 'ordered', 'routine', staff_pid);
    insert into view_results values ('Create Test', 'FAILED ❌', 'Patient was able to create a test!');
  exception when others then
    insert into view_results values ('Create Test', 'PASSED ✅', 'Blocked correctly: ' || SQLERRM);
  end;


  ----------------------------------------------------------------
  -- 6. TEST D: UPDATE (Should FAIL)
  ----------------------------------------------------------------
  update public.lab_test set test_type = 'Hacked Name' where id = test_p1;
  get diagnostics rows_affected = row_count;
  
  if rows_affected = 0 then 
    insert into view_results values ('Update Test', 'PASSED ✅', 'Blocked (0 rows affected).');
  else 
    insert into view_results values ('Update Test', 'FAILED ❌', 'Patient updated test!'); 
  end if;


  ----------------------------------------------------------------
  -- 7. TEST E: DELETE (Should FAIL)
  ----------------------------------------------------------------
  begin
    delete from public.lab_result where id = res_p1;
    -- The Trigger might raise an error, OR RLS might hide the row (0 rows affected). Both are success.
    get diagnostics rows_affected = row_count;
    
    if rows_affected = 0 then
       insert into view_results values ('Delete Result', 'PASSED ✅', 'Blocked (0 rows/Trigger).');
    else
       insert into view_results values ('Delete Result', 'FAILED ❌', 'Patient deleted result!');
    end if;
  exception when others then
    insert into view_results values ('Delete Result', 'PASSED ✅', 'Blocked with Error: ' || SQLERRM);
  end;

end $$;

-- Show Results
select * from view_results;