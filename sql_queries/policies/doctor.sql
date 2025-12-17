-- ==============================================================================
-- 1. HELPER FUNCTION (Corrected for UUID)
-- This grabs the Doctor ID (UUID) for the currently logged-in user.
-- ==============================================================================
create or replace function public.get_my_doctor_id()
returns uuid as $$ 
  select id from public.doctor where user_id = auth.uid() limit 1;
$$ language sql security definer stable;


-- ==============================================================================
-- 2. APPOINTMENT POLICIES
-- Rule: Cannot Create. Can View Assigned. Can Update Assigned.
-- ==============================================================================

-- A. VIEW: See appointments assigned to me
create policy "Doctor_View_Assigned_Appt"
on public.appointment for select
using (
  doctor_id = public.get_my_doctor_id()
);

-- B. UPDATE: Update status/notes for appointments assigned to me
create policy "Doctor_Update_Assigned_Appt"
on public.appointment for update
using (
  doctor_id = public.get_my_doctor_id()
);


-- ==============================================================================
-- 3. EXAMINATION POLICIES
-- Rule: Create, Read, Update (for own created examinations)
-- Link: Examination -> Appointment -> Doctor
-- ==============================================================================

-- A. VIEW: See examinations linked to my appointments
create policy "Doctor_View_Own_Exam"
on public.examination for select
using (
  exists (
    select 1 from public.appointment a
    where a.id = examination.appointment_id
    and a.doctor_id = public.get_my_doctor_id()
  )
);

-- B. INSERT: Create examination (must be for an appointment assigned to me)
create policy "Doctor_Create_Exam"
on public.examination for insert
with check (
  exists (
    select 1 from public.appointment a
    where a.id = examination.appointment_id
    and a.doctor_id = public.get_my_doctor_id()
  )
);

-- C. UPDATE: Update examinations linked to my appointments
create policy "Doctor_Update_Own_Exam"
on public.examination for update
using (
  exists (
    select 1 from public.appointment a
    where a.id = examination.appointment_id
    and a.doctor_id = public.get_my_doctor_id()
  )
);


-- ==============================================================================
-- 4. LAB TEST POLICIES
-- Rule: Create, Read. CANNOT Update.
-- Link: Lab Test -> Examination -> Appointment -> Doctor
-- ==============================================================================

-- A. VIEW: See tests ordered under my care
create policy "Doctor_View_Own_LabTests"
on public.lab_test for select
using (
  exists (
    select 1 
    from public.examination e
    join public.appointment a on e.appointment_id = a.id
    where e.id = lab_test.examination_id
    and a.doctor_id = public.get_my_doctor_id()
  )
);

-- B. INSERT: Order a lab test (must be for an exam I control)
create policy "Doctor_Order_LabTest"
on public.lab_test for insert
with check (
  exists (
    select 1 
    from public.examination e
    join public.appointment a on e.appointment_id = a.id
    where e.id = lab_test.examination_id
    and a.doctor_id = public.get_my_doctor_id()
  )
);


-- ==============================================================================
-- 5. LAB RESULT POLICIES
-- Rule: Read Only.
-- Link: Result -> Test -> Exam -> Appointment -> Doctor
-- ==============================================================================

-- A. VIEW: See results for my patients
create policy "Doctor_View_Own_LabResults"
on public.lab_result for select
using (
  exists (
    select 1 
    from public.lab_test lt
    join public.examination e on lt.examination_id = e.id
    join public.appointment a on e.appointment_id = a.id
    where lt.id = lab_result.lab_test_id
    and a.doctor_id = public.get_my_doctor_id()
  )
);