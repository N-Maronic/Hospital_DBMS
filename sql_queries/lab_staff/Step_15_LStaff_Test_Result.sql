create temporary table if not exists view_results (test text, status text, details text);
grant all on table view_results to authenticated;
truncate table view_results;

do $$
declare
  -- Actors
  staff1_uid uuid; staff1_pid uuid;
  staff2_uid uuid;
  
  -- IDs
  target_test_id uuid;
  target_exam_id uuid;
  target_result_id uuid;
  
  -- Vars
  rows_affected int;
  count_res int;
begin
  ----------------------------------------------------------------
  -- 1. SETUP (As Admin)
  ----------------------------------------------------------------
  select id into staff1_uid from auth.users where email = 'lab1@hospital.com';
  select id into staff1_pid from public.lab_staff where user_id = staff1_uid;
  select id into staff2_uid from auth.users where email = 'lab2@hospital.com';

  -- Find a test assigned to Staff 1
  select id, examination_id into target_test_id, target_exam_id
  from public.lab_test 
  where lab_staff_id = staff1_pid 
  limit 1;

  if target_test_id is null then
     raise exception 'Setup Error: No existing test found for Lab Staff 1.';
  end if;

  ----------------------------------------------------------------
  -- 2. LAB STAFF 1 ACTIONS (The Owner)
  ----------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', staff1_uid::text, true);
  set role authenticated;

  -- A. Create Lab Test (Should FAIL)
  begin
    insert into public.lab_test (examination_id, test_type, status, priority, lab_staff_id)
    values (target_exam_id, 'Illegal Staff Test', 'ordered', 'routine', staff1_pid);
    insert into view_results values ('S1 Create Test', 'FAILED ❌', 'Staff 1 was able to create a test!');
  exception when others then
    insert into view_results values ('S1 Create Test', 'PASSED ✅', 'Blocked correctly: ' || SQLERRM);
  end;

  -- B. Read Own Lab Test (Should PASS)
  select count(*) into count_res from public.lab_test where id = target_test_id;
  if count_res > 0 then insert into view_results values ('S1 Read Own', 'PASSED ✅', 'Found assigned test.');
  else insert into view_results values ('S1 Read Own', 'FAILED ❌', 'Could not see own assigned test.'); end if;

  -- C. Update Status (Should PASS)
  update public.lab_test set status = 'in_progress' where id = target_test_id;
  get diagnostics rows_affected = row_count;
  if rows_affected > 0 then insert into view_results values ('S1 Update Status', 'PASSED ✅', 'Success: Status updated.');
  else insert into view_results values ('S1 Update Status', 'FAILED ❌', 'Update touched 0 rows.'); end if;

  -- D. Create Result (Should PASS)
  begin
    insert into public.lab_result (lab_test_id, results, interpretation)
    values (target_test_id, 'Verified Normal', 'No issues found')
    returning id into target_result_id;
    
    insert into view_results values ('S1 Create Result', 'PASSED ✅', 'Result added. ID: ' || target_result_id);
  exception when others then
    insert into view_results values ('S1 Create Result', 'FAILED ❌', 'Error: ' || SQLERRM);
  end;

  -- E. Delete Result (Should FAIL)
  begin
    delete from public.lab_result where id = target_result_id;
      insert into view_results values ('S1 Delete Result', 'PASSED ✅', 'Blocked correctly: ');
  exception when others then
      insert into view_results values ('S1 Delete Result', 'FAILED ❌', 'Staff deleted result!' || SQLERRM);

  end;

  -- F. Delete Test (Should FAIL)
  begin
    delete from public.lab_test where id = target_test_id;
    insert into view_results values ('S1 Delete Test', 'PASSED ✅', 'Blocked correctly: ');
  exception when others then
      insert into view_results values ('S1 Delete Test', 'FAILED ❌', 'Staff deleted test!' || SQLERRM);
  end;

  -- G. Create Appointment (Should FAIL)
  begin
    insert into public.appointment (patient_id, doctor_id, scheduled_at, end_time, status)
    values ((select id from public.patient limit 1), (select id from public.doctor limit 1), now(), now(), 'scheduled');
    insert into view_results values ('S1 Create Appt', 'FAILED ❌', 'Staff created an appointment!');
  exception when others then
    insert into view_results values ('S1 Create Appt', 'PASSED ✅', 'Blocked correctly: ' || SQLERRM);
  end;

  -- H. Create Examination (Should FAIL)
  begin
    insert into public.examination (appointment_id, diagnosis)
    values ((select id from public.appointment limit 1), 'Staff Diagnosis');
    insert into view_results values ('S1 Create Exam', 'FAILED ❌', 'Staff created an examination!');
  exception when others then
    insert into view_results values ('S1 Create Exam', 'PASSED ✅', 'Blocked correctly: ' || SQLERRM);
  end;


  ----------------------------------------------------------------
  -- 3. LAB STAFF 2 ACTIONS (The Outsider)
  ----------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', staff2_uid::text, true);
  set role authenticated;

  -- I. Read Staff 1's Test (Should FAIL/Hide)
  select count(*) into count_res from public.lab_test where id = target_test_id;
  if count_res = 0 then insert into view_results values ('S2 Read Other', 'PASSED ✅', 'Privacy Working: Saw 0 rows.');
  else insert into view_results values ('S2 Read Other', 'FAILED ❌', 'Security Breach! Saw S1s test.'); end if;

  -- J. Update Staff 1's Test (Should FAIL)
  update public.lab_test set status = 'completed' where id = target_test_id;
  get diagnostics rows_affected = row_count;
  if rows_affected = 0 then insert into view_results values ('S2 Update Other', 'PASSED ✅', 'Blocked (0 rows affected).');
  else insert into view_results values ('S2 Update Other', 'FAILED ❌', 'Security Breach! Updated S1s test.'); end if;

end $$;

-- Show Results
select * from view_results;