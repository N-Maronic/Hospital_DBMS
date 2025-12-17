-- ==============================================================================
-- 1. ENABLE ROW LEVEL SECURITY (RLS)
-- ==============================================================================
alter table public.appointment enable row level security;
alter table public.examination enable row level security;
alter table public.lab_test    enable row level security;
alter table public.lab_result  enable row level security;


-- ==============================================================================
-- 2. APPOINTMENT POLICIES (Singular)
-- Logic: Link directly to public.patient using auth.uid()
-- ==============================================================================

-- A. VIEW: Patients see only their own appointments
create policy "Patient_View_Own_Appt"
on public.appointment for select
using (
  auth.uid() in (
    select user_id from public.patient where id = appointment.patient_id
  )
);

-- B. INSERT: Patients can book appointments (only for themselves)
create policy "Patient_Book_Own_Appt"
on public.appointment for insert
with check (
  auth.uid() in (
    select user_id from public.patient where id = appointment.patient_id
  )
);

-- C. UPDATE: Patients can cancel/reschedule (update) their own appointments
create policy "Patient_Update_Own_Appt"
on public.appointment for update
using (
  auth.uid() in (
    select user_id from public.patient where id = appointment.patient_id
  )
);


-- ==============================================================================
-- 3. EXAMINATION POLICIES (Read Only)
-- Logic: Exam -> Appointment -> Patient -> User
-- ==============================================================================

create policy "Patient_View_Own_Exams"
on public.examination for select
using (
  exists (
    select 1
    from public.appointment a
    join public.patient p on a.patient_id = p.id
    where a.id = examination.appointment_id
    and p.user_id = auth.uid()
  )
);


-- ==============================================================================
-- 4. LAB TEST POLICIES (Read Only)
-- Logic: Test -> Exam -> Appointment -> Patient -> User
-- ==============================================================================

create policy "Patient_View_Own_LabTests"
on public.lab_test for select
using (
  exists (
    select 1
    from public.examination e
    join public.appointment a on e.appointment_id = a.id
    join public.patient p on a.patient_id = p.id
    where e.id = lab_test.examination_id
    and p.user_id = auth.uid()
  )
);


-- ==============================================================================
-- 5. LAB RESULT POLICIES (Read Only)
-- Logic: Result -> Test -> Exam -> Appointment -> Patient -> User
-- ==============================================================================

create policy "Patient_View_Own_LabResults"
on public.lab_result for select
using (
  exists (
    select 1
    from public.lab_test lt
    join public.examination e on lt.examination_id = e.id
    join public.appointment a on e.appointment_id = a.id
    join public.patient p on a.patient_id = p.id
    where lt.id = lab_result.lab_test_id
    and p.user_id = auth.uid()
  )
);