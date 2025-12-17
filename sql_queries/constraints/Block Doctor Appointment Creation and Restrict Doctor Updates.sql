----------------------------------------------------------------
-- 1. CONSTRAINT: BLOCK DOCTOR CREATION (INSERT)
----------------------------------------------------------------
create or replace function block_doctor_appt_insert()
returns trigger 
security definer
as $$
begin
  if exists (select 1 from public.doctor where user_id = auth.uid()) then
    raise exception 'Doctors are not allowed to create appointments. Only Staff/Patients can.';
  end if;
  return new;
end;
$$ language plpgsql;

drop trigger if exists on_doctor_insert_appt on public.appointment;
create trigger on_doctor_insert_appt
before insert on public.appointment
for each row execute function block_doctor_appt_insert();


----------------------------------------------------------------
-- 2. CONSTRAINT: RESTRICT DOCTOR UPDATES (UPDATE)
----------------------------------------------------------------
create or replace function check_doctor_appt_updates()
returns trigger 
security definer
as $$
begin
  if exists (select 1 from public.doctor where user_id = auth.uid()) then
    -- Check if ANY field other than 'status' has changed
    if (NEW.patient_id is distinct from OLD.patient_id) or
       (NEW.doctor_id is distinct from OLD.doctor_id) or
       (NEW.scheduled_at is distinct from OLD.scheduled_at) or
       (NEW.end_time is distinct from OLD.end_time) or
       (NEW.notes is distinct from OLD.notes) then 
       
       raise exception 'Doctors can only update the Status. All other fields are locked.';
    end if;
  end if;
  return new;
end;
$$ language plpgsql;

drop trigger if exists on_doctor_appt_update_check on public.appointment;
create trigger on_doctor_appt_update_check
before update on public.appointment
for each row execute function check_doctor_appt_updates();