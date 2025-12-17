create or replace function public.handle_audit_log()
returns trigger as $$
declare
  current_user_id uuid;
  user_ip text;
  record_id uuid;
  operation_type text;
begin
  -- 1. Get the User ID (safe fallback if system action)
  current_user_id := auth.uid();
  
  -- 2. Try to get IP address (from Supabase headers)
  begin
    user_ip := current_setting('request.headers', true)::json->>'x-forwarded-for';
  exception when others then
    user_ip := 'unknown';
  end;

  -- 3. Determine Operation & Record ID
  if (TG_OP = 'DELETE') then
    record_id := OLD.id;
    operation_type := 'DELETE';
  elsif (TG_OP = 'UPDATE') then
    record_id := NEW.id;
    operation_type := 'UPDATE';
  else
    record_id := NEW.id;
    operation_type := 'CREATE';
  end if;

  -- 4. Insert the Log
  -- We use 'security definer' on this function implicitly to allow writing
  insert into public.audit_logs (
    id, 
    action, 
    object_type, 
    object_id, 
    "IP_address", 
    user_id, 
    created_at
  )
  values (
    gen_random_uuid(),
    operation_type,
    TG_TABLE_NAME::public.audit_object_type, -- Auto-matches table name to Enum
    record_id,
    user_ip,
    current_user_id,
    now()
  );

  return null; -- Result is ignored for AFTER triggers
end;
$$ language plpgsql security definer; 
-- 'security definer' allows this function to write to audit_logs 
-- even though no one else has permission to.