----------------------------------------------------------------
-- 1. CLEANUP OLD POLICIES (Revoke Permissions)
----------------------------------------------------------------
-- Remove any existing policies that might allow Doctors to write
drop policy if exists "Doctors can create lab tests" on public.lab_test;
drop policy if exists "Doctors can update own lab tests" on public.lab_test;
drop policy if exists "Doctors can create lab results" on public.lab_result;
drop policy if exists "Doctors can update lab results" on public.lab_result;

-- Ensure RLS is active
alter table public.lab_test enable row level security;
alter table public.lab_result enable row level security;

----------------------------------------------------------------
-- 2. CREATE BLOCKING TRIGGERS (The Enforcer)
----------------------------------------------------------------
-- Even if RLS fails, this trigger will block any modification by a Doctor
create or replace function block_doctor_lab_mods()
returns trigger as $$
begin
  if exists (select 1 from public.doctor where user_id = auth.uid()) then
    raise exception 'Access Denied: Doctors cannot create or update Lab Tests/Results. Only Lab Staff can.';
  end if;
  return new;
end;
$$ language plpgsql;

-- Attach to Lab Test (Insert/Update)
drop trigger if exists stop_doc_lab_test_mod on public.lab_test;
create trigger stop_doc_lab_test_mod
before insert or update on public.lab_test
for each row execute function block_doctor_lab_mods();

-- Attach to Lab Result (Insert/Update)
drop trigger if exists stop_doc_lab_result_mod on public.lab_result;
create trigger stop_doc_lab_result_mod
before insert or update on public.lab_result
for each row execute function block_doctor_lab_mods();