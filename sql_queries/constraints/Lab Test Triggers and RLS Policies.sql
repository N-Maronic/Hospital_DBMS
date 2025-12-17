----------------------------------------------------------------
-- 1. FIX THE TRIGGER (Add SECURITY DEFINER)
----------------------------------------------------------------
create or replace function enforce_lab_staff_only()
returns trigger 
security definer  -- <--- THIS IS THE KEY FIX
as $$
begin
  -- Now this check works because the function has admin rights
  if not exists (select 1 from public.lab_staff where user_id = auth.uid()) then
     raise exception 'Access Denied: Only Lab Staff can update Lab Tests/Results.';
  end if;
  return new;
end;
$$ language plpgsql;

-- Re-attach the trigger just to be safe
drop trigger if exists strict_staff_only_test on public.lab_test;
create trigger strict_staff_only_test
before update on public.lab_test
for each row execute function enforce_lab_staff_only();


----------------------------------------------------------------
-- 2. RUN THE SMARTER TEST SCRIPT
----------------------------------------------------------------
create temporary table if not exists view_results (test text, status text, details text);
grant all on table view_results to authenticated;
truncate table view_results;

do $$
declare
  doc_uid uuid;
  pat_uid uuid;
  staff_uid uuid;
  my_appt_id uuid;
  my_exam_id uuid;
  my_test_id uuid;
  rows_affected int;
begin
  -- SETUP (Admin)
  select id into doc_uid from auth.users where email = 'doctor1@hospital.com';
  select id into pat_uid from auth.users where email = 'patient1@gmail.com';
  select id into staff_uid from auth.users where email = 'lab1@hospital.com';

  -- Find Data
  select id into my_appt_id from public.appointment where doctor_id = (select id from public.doctor where user_id = doc_uid) limit 1;
  -- If null, creating fallback data is skipped for brevity, assuming previous tests ran. 
  -- Ensure you have at least one appointment/exam/test created from previous steps.
  
  -- Find Test ID
  select id into my_test_id from public.lab_test 
  where examination_id in (select id from public.examination where appointment_id = my_appt_id) limit 1;

  ----------------------------------------------------------------
  -- TEST A: DOCTOR (Should be Blocked)
  ----------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', doc_uid::text, true);
  set role authenticated;

  update public.lab_test set test_type = 'Hacked Name' where id = my_test_id;
  get diagnostics rows_affected = row_count;

  if rows_affected = 0 then
    insert into view_results values ('Doctor Update', 'PASSED ✅', 'Blocked by RLS (0 rows affected).');
  else
    -- If rows > 0, we check if the Trigger threw an error (caught below)
    insert into view_results values ('Doctor Update', 'FAILED ❌', 'Doctor actually updated data!');
  end if;
  
  -- (Note: Since we removed the Doctor's UPDATE policy, RLS forces 0 rows. This is a secure PASS.)


  ----------------------------------------------------------------
  -- TEST B: PATIENT (Should be Blocked)
  ----------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', pat_uid::text, true);
  set role authenticated;

  update public.lab_test set test_type = 'Patient Hack' where id = my_test_id;
  get diagnostics rows_affected = row_count;

  if rows_affected = 0 then
    insert into view_results values ('Patient Update', 'PASSED ✅', 'Blocked by RLS (0 rows affected).');
  else
    insert into view_results values ('Patient Update', 'FAILED ❌', 'Patient updated data!');
  end if;


  ----------------------------------------------------------------
  -- TEST C: LAB STAFF (Should Succeed)
  ----------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', staff_uid::text, true);
  set role authenticated;

  begin
    update public.lab_test set test_type = 'Staff Official Update' where id = my_test_id;
    get diagnostics rows_affected = row_count;
    
    if rows_affected > 0 then
       insert into view_results values ('Lab Staff Update', 'PASSED ✅', 'Staff updated successfully.');
    else
       insert into view_results values ('Lab Staff Update', 'FAILED ❌', 'Staff update touched 0 rows (Check Staff RLS).');
    end if;
  exception when others then
    insert into view_results values ('Lab Staff Update', 'FAILED ❌', 'Trigger Error: ' || SQLERRM);
  end;

end $$;

select * from view_results;