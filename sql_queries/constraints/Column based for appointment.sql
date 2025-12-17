    -- 1. Create the Function to check columns
create or replace function check_doctor_updates()
returns trigger as $$
begin
  -- If the user is a Doctor
  if exists (select 1 from public.doctor where user_id = auth.uid()) then
    -- Check if they tried to change restricted columns
    if (NEW.patient_id is distinct from OLD.patient_id) or
       (NEW.doctor_id is distinct from OLD.doctor_id) or
       (NEW.scheduled_at is distinct from OLD.scheduled_at) then
       
       raise exception 'Doctors can only update Status and Notes. Rescheduling requires Data Entry.';
    end if;
  end if;
  return new;
end;
$$ language plpgsql;

-- 2. Attach the Trigger to the Appointment Table
drop trigger if exists on_doctor_update_check on public.appointment;
create trigger on_doctor_update_check
before update on public.appointment
for each row execute function check_doctor_updates();