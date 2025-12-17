create or replace function prevent_lab_test_deletion()
returns trigger as $$
begin
  ----------------------------------------------------
  -- 1. BYPASS FOR ADMINS (Dashboard & Service Role)
  ----------------------------------------------------
  -- 'postgres' = Supabase Dashboard / SQL Editor
  -- 'service_role' = Backend Server / Edge Functions
  if current_user in ('postgres', 'service_role') then
    return old; -- Allow the delete
  end if;

  ----------------------------------------------------
  -- 2. BLOCK EVERYONE ELSE (Doctors, Staff, Patients)
  ----------------------------------------------------
  raise exception 'STRICT RULE: Lab Tests cannot be deleted by users. Archive them instead.';
  return old;
end;
$$ language plpgsql;