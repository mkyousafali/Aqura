BEGIN;

CREATE OR REPLACE FUNCTION public.assign_in_process_products(
  p_old_employee_id text,
  p_new_employee_id text,
  p_barcodes text[],
  p_branch_id integer
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_count integer;
  v_now text := to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
BEGIN
  UPDATE public.erp_synced_products
  SET
    in_process = (
      SELECT COALESCE(jsonb_agg(elem), '[]'::jsonb)
      FROM jsonb_array_elements(in_process) AS elem
      WHERE NOT (
        elem->>'employee_id' = p_old_employee_id
        AND elem->>'branch_id' = p_branch_id::text
      )
    ),
    managed_by = COALESCE(managed_by, '[]'::jsonb) || (
      SELECT COALESCE(
        jsonb_agg(
          (elem - 'moved_at') || jsonb_build_object(
            'employee_id', p_new_employee_id,
            'claimed_at', v_now
          )
        ),
        '[]'::jsonb
      )
      FROM jsonb_array_elements(in_process) AS elem
      WHERE elem->>'employee_id' = p_old_employee_id
        AND elem->>'branch_id' = p_branch_id::text
    )
  WHERE barcode = ANY(p_barcodes)
    AND EXISTS (
      SELECT 1
      FROM jsonb_array_elements(in_process) AS elem
      WHERE elem->>'employee_id' = p_old_employee_id
        AND elem->>'branch_id' = p_branch_id::text
    );

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$function$;

COMMIT;
