------------------------------------------------------------
-- 1. CLEANUP: Remove old triggers/functions to ensure fresh start
------------------------------------------------------------
drop trigger if exists on_doctor_appt_update_check on public.appointment;
drop function if exists check_doctor_updates() cascade;

------------------------------------------------------------
-- 2. DEFINE THE RULE (The Function)
------------------------------------------------------------
create or replace function check_doctor_updates()
returns trigger as $$
begin
  -- Logic: If the user is a Doctor...
  if exists (select 1 from public.doctor where user_id = auth.uid()) then
    
    -- ...Check if they are changing FORBIDDEN columns
    if (NEW.patient_id is distinct from OLD.patient_id) or
       (NEW.doctor_id is distinct from OLD.doctor_id) or
       (NEW.scheduled_at is distinct from OLD.scheduled_at) or
       (NEW.scheduled_by is distinct from OLD.scheduled_by) then -- <--- The Key Check
       
       raise exception 'Doctors can only update Status and Notes.';
    end if;
  end if;
  return new;
end;
$$ language plpgsql;

------------------------------------------------------------
-- 3. APPLY THE RULE (The Trigger) - THIS WAS MISSING
------------------------------------------------------------
create trigger on_doctor_appt_update_check
before update on public.appointment
for each row execute function check_doctor_updates();


------------------------------------------------------------
-- 4. IMMEDIATE TEST (Verify it works)
------------------------------------------------------------
create temporary table if not exists view_results (test text, status text, details text);
grant all on table view_results to authenticated;
truncate table view_results;

do $$
declare
  doc_uid uuid;
  doc_profile_id uuid;
  staff_uid uuid;
  target_appt_id uuid;
begin
  -- Setup IDs (Admin level)
  select id into doc_uid from auth.users where email = 'doctor1@hospital.com';
  select id into doc_profile_id from public.doctor where user_id = doc_uid;
  select id into staff_uid from auth.users where email = 'data_entry_1@hospital.com';

  -- Ensure Doctor has an appointment
  select id into target_appt_id from public.appointment where doctor_id = doc_profile_id limit 1;
  if target_appt_id is null then
    insert into public.appointment (patient_id, doctor_id, scheduled_at, end_time, status, scheduled_by)
    values ((select id from public.patient limit 1), doc_profile_id, now(), now()+'30m', 'scheduled', doc_uid)
    returning id into target_appt_id;
  end if;

  -- Impersonate Doctor
  perform set_config('request.jwt.claim.sub', doc_uid::text, true);
  set role authenticated;

  -- TEST: Try to hack 'scheduled_by'
  begin
    update public.appointment 
    set scheduled_by = staff_uid 
    where id = target_appt_id;

    -- If this runs, the Trigger Failed
    insert into view_results values ('Update scheduled_by', 'FAILED ❌', 'Doctor was able to update it!');
  exception when others then
    -- If this runs, the Trigger Worked
    insert into view_results values ('Update scheduled_by', 'PASSED ✅', 'Blocked correctly: ' || SQLERRM);
  end;

end $$;

-- Show Final Result
select * from view_results;