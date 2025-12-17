-- 1. Create result table
create temporary table if not exists view_results (
  test_name text,
  status text,
  details text
);

-- 2. Grant permission so the "impersonated" user can write the report
grant all on table view_results to authenticated;

-- Clear previous results
truncate table view_results;

do $$
declare
  pat1_uid uuid;
  pat2_profile_id uuid;
  rows_affected int;
begin
  -- A. Fetch IDs
  -- Patient 1 (The Actor)
  select id into pat1_uid from auth.users where email = 'patient1@gmail.com';
  -- Patient 2 (The Target)
  select id into pat2_profile_id from public.patient where user_id = (select id from auth.users where email = 'patient2@gmail.com');

  -- B. Impersonate Patient 1
  perform set_config('request.jwt.claim.sub', pat1_uid::text, true);
  set role authenticated;

  -- C. Attempt the Attack
  update public.appointment 
  set notes = 'HACKED BY PATIENT 1'
  where patient_id = pat2_profile_id;

  get diagnostics rows_affected = row_count;

  -- D. Log Results
  if rows_affected = 0 then
    insert into view_results values (
      'Update Others Data', 
      'PASSED ✅', 
      'Update blocked correctly (0 rows affected).'
    );
  else
    insert into view_results values (
      'Update Others Data', 
      'FAILED ❌', 
      'Security Breach! Patient 1 updated ' || rows_affected || ' rows belonging to Patient 2!'
    );
  end if;
end $$;

-- 3. Show Results
select * from view_results;