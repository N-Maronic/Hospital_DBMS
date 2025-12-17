-- ==============================================================================
-- 0. HELPER: Get My Lab Staff ID (CORRECTED for UUID)
-- ==============================================================================
create or replace function public.get_my_lab_id()
returns uuid as $$ 
  select id from public.lab_staff where user_id = auth.uid() limit 1;
$$ language sql security definer stable;

-- ==============================================================================
-- 1. PATIENT TABLE (Read Only - ID access)
-- ==============================================================================
create policy "Lab_Read_Patient"
on public.patient for select
using (
  -- 1. Can see patients if I am a lab staff member (broad access to find patients)
  auth.uid() in (select user_id from public.lab_staff)
);

-- ==============================================================================
-- 2. LAB TEST (Read Assigned, Update Status)
-- ==============================================================================

-- A. VIEW: See tests assigned to me
create policy "Lab_View_Assigned_Test"
on public.lab_test for select
using (
  lab_staff_id = public.get_my_lab_id()
);

-- B. UPDATE: Update tests assigned to me (e.g. changing status)
create policy "Lab_Update_Assigned_Test"
on public.lab_test for update
using (
  lab_staff_id = public.get_my_lab_id()
);

-- ==============================================================================
-- 3. LAB RESULT (Create, Read Own, Update Own)
-- ==============================================================================

-- A. VIEW: See results I created
create policy "Lab_View_Own_Result"
on public.lab_result for select
using (
  exists (
    select 1 from public.lab_test lt
    where lt.id = lab_result.lab_test_id
    and lt.lab_staff_id = public.get_my_lab_id()
  )
);

-- B. INSERT: Create result for a test I own
create policy "Lab_Create_Result"
on public.lab_result for insert
with check (
  exists (
    select 1 from public.lab_test lt
    where lt.id = lab_result.lab_test_id
    and lt.lab_staff_id = public.get_my_lab_id()
  )
);

-- C. UPDATE: Update results I created
create policy "Lab_Update_Own_Result"
on public.lab_result for update
using (
  exists (
    select 1 from public.lab_test lt
    where lt.id = lab_result.lab_test_id
    and lt.lab_staff_id = public.get_my_lab_id()
  )
);