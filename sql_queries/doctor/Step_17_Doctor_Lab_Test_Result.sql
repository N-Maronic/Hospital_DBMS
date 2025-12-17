create temporary table if not exists view_results (test text, status text, details text);
grant all on table view_results to authenticated;
truncate table view_results;

do $$
declare
  -- Actors
  doc1_uid uuid; doc1_pid uuid;
  staff_uid uuid; staff_pid uuid;

  -- Data IDs
  appt_id uuid; exam_id uuid; test_id uuid; res_id uuid;
  
  -- Vars
  count_res int;
  rows_affected int;
begin
  ----------------------------------------------------------------
  -- 1. SETUP & DISCOVERY (As Admin)
  ----------------------------------------------------------------
  select id into doc1_uid from auth.users where email = 'doctor1@hospital.com';
  select id into doc1_pid from public.doctor where user_id = doc1_uid;
  
  select id into staff_uid from auth.users where email = 'lab1@hospital.com';
  select id into staff_pid from public.lab_staff where user_id = staff_uid;

  -- A. Find/Ensure Appointment & Exam for Doctor 1
  select id into appt_id from public.appointment where doctor_id = doc1_pid limit 1;
  if appt_id is null then 
     insert into public.appointment (patient_id, doctor_id, scheduled_at, end_time, status) 
     values ((select id from public.patient limit 1), doc1_pid, now(), now()+'30m', 'scheduled') returning id into appt_id; 
  end if;

  select id into exam_id from public.examination where appointment_id = appt_id limit 1;
  if exam_id is null then 
     insert into public.examination (appointment_id, diagnosis) values (appt_id, 'Existing Dx') returning id into exam_id; 
  end if;

  -- B. Find/Ensure Lab Test & Result exists (Owned by Staff)
  select id into test_id from public.lab_test where examination_id = exam_id limit 1;
  if test_id is null then 
     insert into public.lab_test (examination_id, test_type, status, priority, lab_staff_id) 
     values (exam_id, 'Existing Test', 'completed', 'routine', staff_pid) returning id into test_id; 
  end if;

  select id into res_id from public.lab_result where lab_test_id = test_id limit 1;
  if res_id is null then 
     insert into public.lab_result (lab_test_id, results, interpretation) 
     values (test_id, 'Existing Data', 'Normal') returning id into res_id; 
  end if;


  ----------------------------------------------------------------
  -- 2. IMPERSONATE DOCTOR 1
  ----------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', doc1_uid::text, true);
  set role authenticated;


  ----------------------------------------------------------------
  -- 3. TEST A: READ OWN DATA (Should PASS)
  ----------------------------------------------------------------
  select count(*) into count_res from public.lab_test where id = test_id;
  if count_res > 0 then insert into view_results values ('Read Own Test', 'PASSED ✅', 'Found own test.');
  else insert into view_results values ('Read Own Test', 'FAILED ❌', 'Could not see own test.'); end if;


  ----------------------------------------------------------------
  -- 5. TEST C: UPDATE TEST (Should FAIL)
  ----------------------------------------------------------------
  begin
    update public.lab_test set test_type = 'Doc Updated Name' where id = test_id;
    get diagnostics rows_affected = row_count;
    
    if rows_affected = 0 then
       insert into view_results values ('Update Test', 'PASSED ✅', 'Blocked (0 rows/Trigger).');
    else
       insert into view_results values ('Update Test', 'FAILED ❌', 'Doctor updated test!');
    end if;
  exception when others then
    insert into view_results values ('Update Test', 'PASSED ✅', 'Blocked with Error: ' || SQLERRM);
  end;


  ----------------------------------------------------------------
  -- 5. TEST D: CREATE RESULT (Should FAIL)
  ----------------------------------------------------------------
  begin
    insert into public.lab_result (lab_test_id, results, interpretation)
    values (test_id, 'Doc Result', 'Doc Interp');
    insert into view_results values ('Create Result', 'FAILED ❌', 'Doctor created a result!');
  exception when others then
    insert into view_results values ('Create Result', 'PASSED ✅', 'Blocked correctly: ' || SQLERRM);
  end;


  ----------------------------------------------------------------
  -- 6. TEST E: UPDATE RESULT (Should FAIL)
  ----------------------------------------------------------------
  begin
    update public.lab_result set results = 'Doc Hacked Result' where id = res_id;
    get diagnostics rows_affected = row_count;
    
    if rows_affected = 0 then
       insert into view_results values ('Update Result', 'PASSED ✅', 'Blocked (0 rows/Trigger).');
    else
       insert into view_results values ('Update Result', 'FAILED ❌', 'Doctor updated result!');
    end if;
  exception when others then
    insert into view_results values ('Update Result', 'PASSED ✅', 'Blocked with Error: ' || SQLERRM);
  end;

end $$;

-- Show Results
select * from view_results;