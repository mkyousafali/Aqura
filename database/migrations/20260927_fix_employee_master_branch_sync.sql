BEGIN;

CREATE OR REPLACE FUNCTION public.update_employee_master_basic(
  p_id text,
  p_name_en text DEFAULT NULL,
  p_name_ar text DEFAULT NULL,
  p_current_branch_id integer DEFAULT NULL,
  p_current_position_id uuid DEFAULT NULL,
  p_whatsapp_number text DEFAULT NULL,
  p_email text DEFAULT NULL
)
RETURNS TABLE(
  id text,
  name_en varchar,
  name_ar varchar,
  current_branch_id integer,
  current_position_id uuid,
  whatsapp_number text,
  email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  IF COALESCE(trim(p_id), '') = '' THEN
    RAISE EXCEPTION 'Employee ID is required';
  END IF;

  IF p_current_branch_id IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM public.branches AS b WHERE b.id = p_current_branch_id) THEN
    RAISE EXCEPTION 'Branch not found';
  END IF;

  IF p_current_position_id IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM public.hr_positions AS pos WHERE pos.id = p_current_position_id) THEN
    RAISE EXCEPTION 'Position not found';
  END IF;

  SELECT employee.user_id
  INTO v_user_id
  FROM public.hr_employee_master AS employee
  WHERE employee.id = p_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Employee not found';
  END IF;

  UPDATE public.hr_employee_master AS employee
  SET
    name_en = COALESCE(NULLIF(trim(p_name_en), ''), employee.name_en),
    name_ar = COALESCE(NULLIF(trim(p_name_ar), ''), employee.name_ar),
    current_branch_id = COALESCE(p_current_branch_id, employee.current_branch_id),
    current_position_id = COALESCE(p_current_position_id, employee.current_position_id),
    whatsapp_number = CASE
      WHEN p_whatsapp_number IS NOT NULL THEN NULLIF(trim(p_whatsapp_number), '')
      ELSE employee.whatsapp_number
    END,
    email = CASE
      WHEN p_email IS NOT NULL THEN NULLIF(trim(p_email), '')
      ELSE employee.email
    END,
    updated_at = now()
  WHERE employee.id = p_id;

  IF p_current_branch_id IS NOT NULL AND v_user_id IS NOT NULL THEN
    UPDATE public.users AS linked_user
    SET branch_id = p_current_branch_id,
        updated_at = now()
    WHERE linked_user.id = v_user_id;
  END IF;

  RETURN QUERY
  SELECT
    employee.id,
    employee.name_en,
    employee.name_ar,
    employee.current_branch_id,
    employee.current_position_id,
    employee.whatsapp_number,
    employee.email
  FROM public.hr_employee_master AS employee
  WHERE employee.id = p_id;
END;
$$;

COMMIT;
