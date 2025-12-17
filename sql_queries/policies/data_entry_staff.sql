-- ==============================================================================
-- 0. HELPER: Check if I am Data Entry
-- ==============================================================================
create or replace function public.is_data_entry()
returns boolean as $$
  select exists (
    select 1 from public."user" 
    where id = auth.uid() and role = 'data_entry'
  );
$$ language sql security definer stable;

-- ==============================================================================
-- 1. PATIENT TABLE (Create, Read, Update)
-- ==============================================================================
create policy "DataEntry_All_Patient"
on public.patient
for all
using ( public.is_data_entry() );

-- ==============================================================================
-- 2. PUBLIC USER TABLE (Create, Read, Update)
-- Note: They need this to register new doctors/patients
-- ==============================================================================
create policy "DataEntry_All_User"
on public."user"
for all
using ( public.is_data_entry() );

-- ==============================================================================
-- 3. APPOINTMENT TABLE (Create, Read, Update)
-- ==============================================================================
create policy "DataEntry_All_Appointment"
on public.appointment
for all
using ( public.is_data_entry() );