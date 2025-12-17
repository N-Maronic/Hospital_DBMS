-- 1. Create result table (if not exists)
create temporary table if not exists view_results (
  test_name text,
  status text,
  details text
);

-- 2. Grant permission
grant all on table view_results to authenticated;

-- Clear previous results
truncate table view_results;

do $$
declare
  pat_uid uuid;
  pat_profile_id uuid;
begin
  -- A. Fetch IDs
  select id into pat_uid from auth.users where email = 'patient1@gmail.com';
  select id into pat_profile_id from public.patient where user_id = pat_uid;

  -- B. Impersonate Patient 1
  perform set_config('request.jwt.claim.sub', pat_uid::text, true);
  set role authenticated;

  -- C. Attempt the Delete
  begin
    delete from public.appointment where patient_id = pat_profile_id;
    
    -- If the code reaches here, the delete worked (which is BAD for your requirements)
    insert into view_results values (
      'Delete Own Data', 
      'FAILED ❌', 
      'Appointment was deleted (Permission was not revoked).'
    );
  exception when others then
    -- If an error is caught, it means the database blocked the action (GOOD)
    insert into view_results values (
      'Delete Own Data', 
      'PASSED ✅', 
      'Delete Blocked correctly. Error: ' || SQLERRM
    );
  end;
end $$;

-- 3. Show Results
select * from view_results;