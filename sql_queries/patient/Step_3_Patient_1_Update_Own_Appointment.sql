-- 1. Setup a temp table to hold the comparison
create temporary table if not exists update_log (
    state text, 
    appt_id uuid, 
    scheduled_at timestamptz, 
    end_time timestamptz
);
grant all on table update_log to authenticated;
truncate table update_log;

do $$
declare
  pat_uid uuid;
  pat_profile_id uuid;
  rows_affected int;
begin
  ----------------------------------------------------------------
  -- A. SETUP (As Admin)
  ----------------------------------------------------------------
  select id into pat_uid from auth.users where email = 'patient1@gmail.com';
  select id into pat_profile_id from public.patient where user_id = pat_uid;

  ----------------------------------------------------------------
  -- B. IMPERSONATE PATIENT 1
  ----------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', pat_uid::text, true);
  set role authenticated;

  ----------------------------------------------------------------
  -- C. CAPTURE "BEFORE" STATE
  ----------------------------------------------------------------
  insert into update_log (state, appt_id, scheduled_at, end_time)
  select 'BEFORE', id, scheduled_at, end_time
  from public.appointment
  where patient_id = pat_profile_id
  order by scheduled_at desc
  limit 1; -- Just tracking the latest one for clarity

  ----------------------------------------------------------------
  -- D. PERFORM UPDATE
  ----------------------------------------------------------------
  update public.appointment 
  set scheduled_at = scheduled_at + interval '1 hour',
      end_time = end_time + interval '1 hour'
  where patient_id = pat_profile_id;

  get diagnostics rows_affected = row_count;

  ----------------------------------------------------------------
  -- E. CAPTURE "AFTER" STATE & REPORT
  ----------------------------------------------------------------
  if rows_affected > 0 then
    insert into update_log (state, appt_id, scheduled_at, end_time)
    select 'AFTER', id, scheduled_at, end_time
    from public.appointment
    where patient_id = pat_profile_id
    order by scheduled_at desc
    limit 1;
    
    raise notice '✅ PASSED: Update Successful. % rows changed.', rows_affected;
  else
    raise notice '❌ FAILED: Update touched 0 rows (Check RLS or Data).';
  end if;

end $$;

-- 2. SHOW THE COMPARISON
select * from update_log order by appt_id, state desc;