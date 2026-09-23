-- Employee Master's branch-change save only updated hr_employee_master.current_branch_id,
-- leaving the linked login account's users.branch_id stale. hr_employee_master.user_id
-- (NOT NULL, UNIQUE, FK -> users.id) is the authoritative link -- users.employee_id points
-- at a different, legacy hr_employees table and is not used here.
CREATE OR REPLACE FUNCTION public.update_employee_master_basic(p_id text, p_name_en text DEFAULT NULL::text, p_name_ar text DEFAULT NULL::text, p_current_branch_id integer DEFAULT NULL::integer, p_current_position_id uuid DEFAULT NULL::uuid, p_whatsapp_number text DEFAULT NULL::text, p_email text DEFAULT NULL::text)
 RETURNS TABLE(id text, name_en character varying, name_ar character varying, current_branch_id integer, current_position_id uuid, whatsapp_number text, email text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id uuid;
BEGIN
  IF COALESCE(trim(p_id), '') = '' THEN
    RAISE EXCEPTION 'Employee ID is required';
  END IF;

  IF p_current_branch_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM branches b WHERE b.id = p_current_branch_id) THEN
      RAISE EXCEPTION 'Branch not found';
    END IF;
  END IF;

  IF p_current_position_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM hr_positions pos WHERE pos.id = p_current_position_id) THEN
      RAISE EXCEPTION 'Position not found';
    END IF;
  END IF;

  RETURN QUERY
  UPDATE hr_employee_master e
  SET
    name_en = COALESCE(NULLIF(trim(p_name_en), ''), e.name_en),
    name_ar = COALESCE(NULLIF(trim(p_name_ar), ''), e.name_ar),
    current_branch_id = COALESCE(p_current_branch_id, e.current_branch_id),
    current_position_id = CASE
      WHEN p_current_position_id IS NOT NULL THEN p_current_position_id
      ELSE e.current_position_id
    END,
    whatsapp_number = CASE
      WHEN p_whatsapp_number IS NOT NULL THEN NULLIF(trim(p_whatsapp_number), '')
      ELSE e.whatsapp_number
    END,
    email = CASE
      WHEN p_email IS NOT NULL THEN NULLIF(trim(p_email), '')
      ELSE e.email
    END,
    updated_at = NOW()
  WHERE e.id = p_id
  RETURNING
    e.id,
    e.name_en,
    e.name_ar,
    e.current_branch_id,
    e.current_position_id,
    e.whatsapp_number,
    e.email;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Employee not found';
  END IF;

  -- Keep the linked login account's branch in sync with the employee's current branch.
  IF p_current_branch_id IS NOT NULL THEN
    SELECT user_id INTO v_user_id FROM hr_employee_master WHERE id = p_id;
    IF v_user_id IS NOT NULL THEN
      UPDATE users SET branch_id = p_current_branch_id WHERE id = v_user_id;
    END IF;
  END IF;
END;
$function$;
