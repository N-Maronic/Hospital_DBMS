-- 1. CLEAN START: Drop the table if it exists from a previous run
drop table if exists test_report;

-- 2. Create the temporary report table
create temporary table test_report (
  test_name text,
  status text,
  details text
);

-- 3. *** THE FIX ***: Give 'authenticated' users (Doctor, Patient, etc.) permission to write here
grant insert, select on table test_report to authenticated;

-- 4. Run the Security Tests
do $$
declare
  target_appt_id uuid := '78ac92f1-8328-4d52-90af-876297255eef';
  
  -- Variables
  pat_uid uuid;
  lab_uid uuid;
  data_uid uuid;
  doc_uid uuid;
  doc_profile_id uuid;
begin
  ----------------------------------------------------------------
  -- SETUP
  ----------------------------------------------------------------
  select id into pat_uid  from auth.users where email = 'patient1@gmail.com';
  select id into lab_uid  from auth.users where email = 'lab1@hospital.com';
  select id into data_uid from auth.users where email = 'data1@hospital.com';
  select id into doc_uid  from auth.users where email = 'doctor1@hospital.com';

  select id into doc_profile_id from public.doctor where user_id = doc_uid;

  -- Ensure Appointment is owned by Doctor 1 and in the PAST
  update public.appointment
  set doctor_id = doc_profile_id, scheduled_at = now() - interval '2 days'
  where id = target_appt_id;

  insert into test_report values ('SETUP', 'SUCCESS', 'Appointment prepared.');

  ----------------------------------------------------------------
  -- TEST 1-3: BAD ACTORS (Should be BLOCKED)
  ----------------------------------------------------------------
  
  -- Patient
  begin
    perform set_config('request.jwt.claim.sub', pat_uid::text, true);
    set role authenticated;
    insert into public.examination (appointment_id, diagnosis, notes) values (target_appt_id, 'Hack', 'Patient attempt');
    insert into test_report values ('TEST 1: Patient', 'FAILED ❌', 'Security breach!');
  exception when others then
    insert into test_report values ('TEST 1: Patient', 'PASSED ✅', 'Blocked: ' || SQLERRM);
  end;

  -- Data Entry
  begin
    perform set_config('request.jwt.claim.sub', data_uid::text, true);
    set role authenticated;
    insert into public.examination (appointment_id, diagnosis, notes) values (target_appt_id, 'Hack', 'Data attempt');
    insert into test_report values ('TEST 2: Data Entry', 'FAILED ❌', 'Security breach!');
  exception when others then
    insert into test_report values ('TEST 2: Data Entry', 'PASSED ✅', 'Blocked: ' || SQLERRM);
  end;

  -- Lab Staff
  begin
    perform set_config('request.jwt.claim.sub', lab_uid::text, true);
    set role authenticated;
    insert into public.examination (appointment_id, diagnosis, notes) values (target_appt_id, 'Hack', 'Lab attempt');
    insert into test_report values ('TEST 3: Lab Staff', 'FAILED ❌', 'Security breach!');
  exception when others then
    insert into test_report values ('TEST 3: Lab Staff', 'PASSED ✅', 'Blocked: ' || SQLERRM);
  end;

  ----------------------------------------------------------------
  -- TEST 4: DOCTOR (Should SUCCEED)
  ----------------------------------------------------------------
  begin
    perform set_config('request.jwt.claim.sub', doc_uid::text, true);
    set role authenticated;

    insert into public.examination (appointment_id, diagnosis, notes)
    values (target_appt_id, 'Valid Diagnosis', 'Created by Doctor');

    -- This line failed before because of MISSING GRANTS (Step 3 fixed it)
    insert into test_report values ('TEST 4: Doctor', 'PASSED ✅', 'Doctor created exam.');
  exception when others then
    insert into test_report values ('TEST 4: Doctor', 'FAILED ❌', 'Doctor blocked! Error: ' || SQLERRM);
  end;

end $$;

-- 5. Show Results
select * from test_report;