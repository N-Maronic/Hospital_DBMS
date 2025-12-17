-- 1. Create a temporary table to store the PASS/FAIL result
create temporary table if not exists view_results (
  test_name text,
  status text,
  details text
);

-- 2. *** CRITICAL ***: Allow the impersonated patient to write to this table
grant all on table view_results to authenticated;

-- Clear previous results
truncate table view_results;

do $$
declare
  pat1_uid uuid;
  pat2_profile_id uuid;
  count_found int;
begin
  -- A. Fetch IDs
  -- Patient 1 (The Actor)
  select id into pat1_uid from auth.users where email = 'patient1@gmail.com';
  
  -- Patient 2 (The Target)
  select id into pat2_profile_id from public.patient where user_id = (select id from auth.users where email = 'patient2@gmail.com');

  -- B. Impersonate Patient 1
  perform set_config('request.jwt.claim.sub', pat1_uid::text, true);
  set role authenticated;

  -- C. Perform the Security Test
  -- Try to count how many of Patient 2's appointments Patient 1 can see
  select count(*) into count_found 
  from public.appointment 
  where patient_id = pat2_profile_id;

  -- D. Write Result to Table
  if count_found = 0 then
    insert into view_results values (
      'Read Others Data', 
      'PASSED ✅', 
      'Correctly hidden. Patient 1 saw 0 rows belonging to Patient 2.'
    );
  else
    insert into view_results values (
      'Read Others Data', 
      'FAILED ❌', 
      'Security Breach! Patient 1 was able to see ' || count_found || ' appointments belonging to Patient 2.'
    );
  end if;

end $$;

-- 3. Show the final result table
select * from view_results;