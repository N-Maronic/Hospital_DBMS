-- 1. Track Appointments
drop trigger if exists on_appointment_audit on public.appointment;
create trigger on_appointment_audit
after insert or update or delete on public.appointment
for each row execute function public.handle_audit_log();

-- 2. Track Patients
drop trigger if exists on_patient_audit on public.patient;
create trigger on_patient_audit
after insert or update or delete on public.patient
for each row execute function public.handle_audit_log();

-- 3. Track Examinations
drop trigger if exists on_exam_audit on public.examination;
create trigger on_exam_audit
after insert or update or delete on public.examination
for each row execute function public.handle_audit_log();

-- 4. Track Lab Tests
drop trigger if exists on_lab_test_audit on public.lab_test;
create trigger on_lab_test_audit
after insert or update or delete on public.lab_test
for each row execute function public.handle_audit_log();

-- 5. Track Users (Careful: This is public."user")
drop trigger if exists on_user_audit on public."user";
create trigger on_user_audit
after insert or update or delete on public."user"
for each row execute function public.handle_audit_log();