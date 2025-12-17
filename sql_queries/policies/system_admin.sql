-- ==============================================================================
-- SYSTEM ADMIN: Access Everything
-- ==============================================================================
-- Helper to check if I am admin
create or replace function public.is_admin()
returns boolean as $$
  select exists (
    select 1 from public."user" 
    where id = auth.uid() and role = 'system_admin'
  );
$$ language sql security definer stable;

-- Apply "ALL" policy to every table
create policy "Admin_All_Access_Users"       on public."user"        for all using (public.is_admin());
create policy "Admin_All_Access_Patient"     on public.patient       for all using (public.is_admin());
create policy "Admin_All_Access_Doctor"      on public.doctor        for all using (public.is_admin());
create policy "Admin_All_Access_LabStaff"    on public.lab_staff     for all using (public.is_admin());
create policy "Admin_All_Access_DataStaff"   on public.data_entry_staff for all using (public.is_admin());

create policy "Admin_All_Access_Appt"        on public.appointment   for all using (public.is_admin());
create policy "Admin_All_Access_Exam"        on public.examination   for all using (public.is_admin());
create policy "Admin_All_Access_LabTest"     on public.lab_test      for all using (public.is_admin());
create policy "Admin_All_Access_LabRes"      on public.lab_result    for all using (public.is_admin());