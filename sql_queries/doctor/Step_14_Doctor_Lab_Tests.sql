create temporary table if not exists view_results (test text, status text, details text);
grant all on table view_results to authenticated;
truncate table view_results;

do $$
declare
  -- Actors
  doc1_uid uuid; doc1_pid uuid;
  doc2_uid uuid; doc2_pid uuid;
  staff_uid uuid;

  -- Targets (Existing Exams)
  exam_doc1 uuid; -- Exam belonging to Doctor 1
  exam_doc2 uuid; -- Exam belonging to Doctor 2

  -- Created Test IDs
  test_created_by_d1 uuid;
  test_created_by_d2 uuid;

  -- Vars
  rows_affected int;
  count_res int;
  temp_appt uuid; -- Fallback only
begin
  ----------------------------------------------------------------
  -- 1. SETUP & DISCOVERY (As Admin)
  ----------------------------------------------------------------
  -- IDs
  select id into doc1_uid from auth.users where email = 'doctor1@hospital.com';
  select id into doc1_pid from public.doctor where user_id = doc1_uid;
  
  select id into doc2_uid from auth.users where email = 'doctor2@hospital.com';
  select id into doc2_pid from public.doctor where user_id = doc2_uid;
  
  select id from public.lab_staff limit 1 into staff_uid;

  -- A. Find Existing Exam for Doctor 1
  select e.id into exam_doc1 from public.examination e
  join public.appointment a on e.appointment_id = a.id
  where a.doctor_id = doc1_pid limit 1;

  -- Fallback (Safety only)
  if exam_doc1 is null then
     insert into public.appointment (patient_id, doctor_id, scheduled_at, end_time, status)
     values ((select id from public.patient limit 1), doc1_pid, now(), now()+'30m', 'scheduled') returning id into temp_appt;
     insert into public.examination (appointment_id, diagnosis) values (temp_appt, 'D1 Fallback') returning id into exam_doc1;
  end if;

  -- B. Find Existing Exam for Doctor 2
  select e.id into exam_doc2 from public.examination e
  join public.appointment a on e.appointment_id = a.id
  where a.doctor_id = doc2_pid limit 1;

  -- Fallback (Safety only)
  if exam_doc2 is null then
     insert into public.appointment (patient_id, doctor_id, scheduled_at, end_time, status)
     values ((select id from public.patient limit 1), doc2_pid, now(), now()+'30m', 'scheduled') returning id into temp_appt;
     insert into public.examination (appointment_id, diagnosis) values (temp_appt, 'D2 Fallback') returning id into exam_doc2;
  end if;


  ----------------------------------------------------------------
  -- 2. DOCTOR 1 ACTIONS
  ----------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', doc1_uid::text, true);
  set role authenticated;

  -- A. Create Own Lab Test (Should PASS)
  begin
    insert into public.lab_test (examination_id, test_type, status, priority, lab_staff_id)
    values (exam_doc1, 'D1 Own Test', 'ordered', 'routine', staff_uid)
    returning id into test_created_by_d1;
    
    insert into view_results values ('D1 Create Own', 'PASSED ✅', 'Success. ID: ' || test_created_by_d1);
  exception when others then
    insert into view_results values ('D1 Create Own', 'FAILED ❌', 'Error: ' || SQLERRM);
  end;

  -- B. Read Own Lab Test (Should PASS)
  select count(*) into count_res from public.lab_test where id = test_created_by_d1;
  if count_res > 0 then insert into view_results values ('D1 Read Own', 'PASSED ✅', 'Found test.');
  else insert into view_results values ('D1 Read Own', 'FAILED ❌', 'Cannot see own test.'); end if;

  -- C. Update Own Lab Test (Should FAIL)
  begin
    update public.lab_test set test_type = 'Hacked Update' where id = test_created_by_d1;
    get diagnostics rows_affected = row_count;
    if rows_affected = 0 then insert into view_results values ('D1 Update Own', 'PASSED ✅', 'Blocked (0 rows).');
    else insert into view_results values ('D1 Update Own', 'FAILED ❌', 'Update succeeded!'); end if;
  exception when others then
    insert into view_results values ('D1 Update Own', 'PASSED ✅', 'Blocked with Error: ' || SQLERRM);
  end;

  -- D. Delete Own Lab Test (Should FAIL)
  begin
    delete from public.lab_test where id = test_created_by_d1;
    get diagnostics rows_affected = row_count;
    if rows_affected = 0 then insert into view_results values ('D1 Delete Own', 'PASSED ✅', 'Blocked (0 rows).');
    else insert into view_results values ('D1 Delete Own', 'FAILED ❌', 'Delete succeeded!'); end if;
  exception when others then
    insert into view_results values ('D1 Delete Own', 'PASSED ✅', 'Blocked with Error: ' || SQLERRM);
  end;

  -- E. Create Test for Doctor 2 (Should FAIL)
  begin
    insert into public.lab_test (examination_id, test_type, status, priority, lab_staff_id)
    values (exam_doc2, 'Illegal Test', 'ordered', 'routine', staff_uid);
    insert into view_results values ('D1 Create Other', 'FAILED ❌', 'Security Breach! Created test for D2.');
  exception when others then
    insert into view_results values ('D1 Create Other', 'PASSED ✅', 'Blocked correctly: ' || SQLERRM);
  end;


  ----------------------------------------------------------------
  -- 3. DOCTOR 2 ACTIONS
  ----------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', doc2_uid::text, true);
  set role authenticated;

  -- A. Create Own Lab Test (Should PASS)
  begin
    insert into public.lab_test (examination_id, test_type, status, priority, lab_staff_id)
    values (exam_doc2, 'D2 Own Test', 'ordered', 'routine', staff_uid)
    returning id into test_created_by_d2;
    
    insert into view_results values ('D2 Create Own', 'PASSED ✅', 'Success. ID: ' || test_created_by_d2);
  exception when others then
    insert into view_results values ('D2 Create Own', 'FAILED ❌', 'Error: ' || SQLERRM);
  end;

  -- B. Read Own Lab Test (Should PASS)
  select count(*) into count_res from public.lab_test where id = test_created_by_d2;
  if count_res > 0 then insert into view_results values ('D2 Read Own', 'PASSED ✅', 'Found test.');
  else insert into view_results values ('D2 Read Own', 'FAILED ❌', 'Cannot see own test.'); end if;

  -- C. Update Own Lab Test (Should FAIL)
  begin
    update public.lab_test set test_type = 'Hacked Update' where id = test_created_by_d2;
    get diagnostics rows_affected = row_count;
    if rows_affected = 0 then insert into view_results values ('D2 Update Own', 'PASSED ✅', 'Blocked (0 rows).');
    else insert into view_results values ('D2 Update Own', 'FAILED ❌', 'Update succeeded!'); end if;
  exception when others then
    insert into view_results values ('D2 Update Own', 'PASSED ✅', 'Blocked with Error: ' || SQLERRM);
  end;

  -- D. Delete Own Lab Test (Should FAIL)
  begin
    delete from public.lab_test where id = test_created_by_d2;
    get diagnostics rows_affected = row_count;
    if rows_affected = 0 then insert into view_results values ('D2 Delete Own', 'PASSED ✅', 'Blocked (0 rows).');
    else insert into view_results values ('D2 Delete Own', 'FAILED ❌', 'Delete succeeded!'); end if;
  exception when others then
    insert into view_results values ('D2 Delete Own', 'PASSED ✅', 'Blocked with Error: ' || SQLERRM);
  end;

  -- E. Read Doctor 1's Test (Should FAIL)
  select count(*) into count_res from public.lab_test where id = test_created_by_d1;
  if count_res = 0 then insert into view_results values ('D2 Read Other', 'PASSED ✅', 'Privacy Working: Saw 0 rows.');
  else insert into view_results values ('D2 Read Other', 'FAILED ❌', 'Security Breach! Saw D1s test.'); end if;

end $$;

-- Show Results
select * from view_results;