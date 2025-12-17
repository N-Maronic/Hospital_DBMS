create temporary table if not exists view_results (test text, status text, details text);
grant all on table view_results to authenticated;
truncate table view_results;

do $$
declare
  doc_uid uuid;
  doc_profile_id uuid;
  pat_profile_id uuid;
  target_appt_id uuid;
  rows_affected int;
begin
  ----------------------------------------------------------------
  -- A. SETUP (As Admin)
  ----------------------------------------------------------------
  select id into doc_uid from auth.users where email = 'doctor1@hospital.com';
  select id into doc_profile_id from public.doctor where user_id = doc_uid;
  select id into pat_profile_id from public.patient limit 1;

  -- Ensure there is an appointment for the doctor to try and update
  select id into target_appt_id from public.appointment where doctor_id = doc_profile_id limit 1;
  
  if target_appt_id is null then
     -- Admin creates one so the doctor has something to test on
     insert into public.appointment (patient_id, doctor_id, scheduled_at, end_time, status)
     values (pat_profile_id, doc_profile_id, now(), now()+'30m', 'scheduled')
     returning id into target_appt_id;
  end if;

  ----------------------------------------------------------------
  -- B. IMPERSONATE DOCTOR
  ----------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', doc_uid::text, true);
  set role authenticated;

  ----------------------------------------------------------------
  -- C. TEST 1: ATTEMPT TO CREATE (Should Fail)
  ----------------------------------------------------------------
  begin
    insert into public.appointment (patient_id, doctor_id, scheduled_at, end_time, status)
    values (pat_profile_id, doc_profile_id, now() + interval '1 year', now() + interval '1 year 30m', 'scheduled');
    
    insert into view_results values ('Create Appointment', 'FAILED ❌', 'Doctor was able to create!');
  exception when others then
    insert into view_results values ('Create Appointment', 'PASSED ✅', 'Blocked: ' || SQLERRM);
  end;

  ----------------------------------------------------------------
  -- D. TEST 2: ATTEMPT TO UPDATE TIME (Should Fail)
  ----------------------------------------------------------------
  begin
    update public.appointment 
    set scheduled_at = scheduled_at + interval '1 hour'
    where id = target_appt_id;
    
    insert into view_results values ('Update Time', 'FAILED ❌', 'Doctor changed the time!');
  exception when others then
    insert into view_results values ('Update Time', 'PASSED ✅', 'Blocked: ' || SQLERRM);
  end;

  ----------------------------------------------------------------
  -- E. TEST 3: ATTEMPT TO UPDATE STATUS (Should Pass)
  ----------------------------------------------------------------
  begin
    update public.appointment 
    set status = 'completed'
    where id = target_appt_id;
    
    get diagnostics rows_affected = row_count;

    if rows_affected > 0 then
      insert into view_results values ('Update Status', 'PASSED ✅', 'Success: Status updated.');
    else
      insert into view_results values ('Update Status', 'FAILED ❌', 'Update 0 rows (Check RLS).');
    end if;
  exception when others then
     insert into view_results values ('Update Status', 'FAILED ❌', 'Error: ' || SQLERRM);
  end;

end $$;

-- SHOW RESULTS
select * from view_results;