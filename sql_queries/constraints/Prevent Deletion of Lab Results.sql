----------------------------------------------------------------
-- 1. TRIGGER: BLOCK DELETING LAB RESULTS
----------------------------------------------------------------
-- (We already have a global trigger for lab_tests from previous steps)

create or replace function prevent_lab_result_deletion()
returns trigger as $$
begin
  if current_user in ('postgres', 'service_role') then
    return old;
  end if;
  
  raise exception 'STRICT RULE: Lab Results cannot be deleted. Archive them instead.';
  return old;
end;
$$ language plpgsql;

drop trigger if exists on_delete_result_check on public.lab_result;
create trigger on_delete_result_check
before delete on public.lab_result
for each row execute function prevent_lab_result_deletion();

----------------------------------------------------------------
-- 2. ENSURE RLS BLOCKS CREATION (Implied)
----------------------------------------------------------------
-- By default, RLS is "Deny All" unless a policy exists. 
-- Since we never created an "INSERT" policy for Lab Staff on 'appointment' 
-- or 'examination', they will automatically be blocked. 
-- The test below confirms this.