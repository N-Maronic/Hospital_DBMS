-- 1. Reset Policies for lab_test to ensure a clean slate
alter table public.lab_test enable row level security;
drop policy if exists "Doctors can update own lab tests" on public.lab_test;
drop policy if exists "Doctors can delete own lab tests" on public.lab_test;

-- 2. CREATE UPDATE POLICY
-- Allow Doctor to "see" the row for UPDATE operations
create policy "Doctors can update own lab tests"
on public.lab_test for update
to authenticated
using (
  exists (
    select 1 from public.examination e
    join public.appointment a on e.appointment_id = a.id
    join public.doctor d on a.doctor_id = d.id
    where e.id = public.lab_test.examination_id
    and d.user_id = auth.uid()
  )
);

-- 3. CREATE DELETE POLICY
-- Allow Doctor to "see" the row for DELETE operations
-- (We need this so the "Block Delete" trigger can actually fire and say "NO")
create policy "Doctors can delete own lab tests"
on public.lab_test for delete
to authenticated
using (
  exists (
    select 1 from public.examination e
    join public.appointment a on e.appointment_id = a.id
    join public.doctor d on a.doctor_id = d.id
    where e.id = public.lab_test.examination_id
    and d.user_id = auth.uid()
  )
);

----------------------------------------------------------------
-- 4. ENSURE TRIGGERS ARE ACTIVE (The "Police")
----------------------------------------------------------------

-- A. Re-verify the Update Trigger (Blocks Status/Priority changes)
create or replace function check_doctor_lab_updates()
returns trigger as $$
begin
  if exists (select 1 from public.doctor where user_id = auth.uid()) then
    if (NEW.status is distinct from OLD.status) or
       (NEW.priority is distinct from OLD.priority) or
       (NEW.lab_staff_id is distinct from OLD.lab_staff_id) then
       raise exception 'Doctors can only update the Test Name (test_type).';
    end if;
  end if;
  return new;
end;
$$ language plpgsql;

drop trigger if exists on_doctor_lab_update_check on public.lab_test;
create trigger on_doctor_lab_update_check
before update on public.lab_test
for each row execute function check_doctor_lab_updates();


-- B. Re-verify the Delete Trigger (Blocks ALL Deletes)
create or replace function block_doctor_delete_test()
returns trigger as $$
begin
  if exists (select 1 from public.doctor where user_id = auth.uid()) then
    raise exception 'Doctors are not allowed to delete Lab Tests.';
  end if;
  return old;
end;
$$ language plpgsql;

drop trigger if exists on_doctor_delete_test_check on public.lab_test;
create trigger on_doctor_delete_test_check
before delete on public.lab_test
for each row execute function block_doctor_delete_test();