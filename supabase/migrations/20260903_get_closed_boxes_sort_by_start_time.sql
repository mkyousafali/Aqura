-- Switch the Closed Boxes list (get_closed_boxes RPC) to filter and sort by
-- box_operations.start_time instead of updated_at, and expose start_time in
-- the returned JSON so the frontend can show a "Start Time" column.
-- Latest start_time is listed first (DESC).

CREATE OR REPLACE FUNCTION public.get_closed_boxes(p_branch_id text DEFAULT 'all'::text, p_date_from text DEFAULT NULL::text, p_date_to text DEFAULT NULL::text, p_limit integer DEFAULT 100, p_offset integer DEFAULT 0) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_total_count bigint;
  v_boxes jsonb;
BEGIN
  SELECT COUNT(*)
  INTO v_total_count
  FROM box_operations bo
  WHERE bo.status = 'completed'
    AND (p_branch_id = 'all' OR bo.branch_id = p_branch_id::int)
    AND (p_date_from IS NULL OR bo.start_time >= p_date_from::date)
    AND (p_date_to IS NULL OR bo.start_time < (p_date_to::date + interval '1 day'));

  SELECT COALESCE(jsonb_agg(row_data ORDER BY (row_data->>'start_time')::timestamptz DESC), '[]'::jsonb)
  INTO v_boxes
  FROM (
    SELECT jsonb_build_object(
      'id', bo.id,
      'box_number', bo.box_number,
      'branch_id', bo.branch_id,
      'user_id', bo.user_id,
      'status', bo.status,
      'notes', bo.notes,
      'complete_details', bo.complete_details,
      'completed_by_name', bo.completed_by_name,
      'completed_by_user_id', bo.completed_by_user_id,
      'total_before', bo.total_before,
      'total_after', bo.total_after,
      'start_time', bo.start_time,
      'created_at', bo.created_at,
      'updated_at', bo.updated_at,
      'transfer_status', pdt.status::text,
      'transfer_key', CASE WHEN pdt.box_number IS NOT NULL
        THEN pdt.box_number::text || '-' || pdt.branch_id::text || '-' || pdt.date_closed_box::text
        ELSE NULL END
    ) as row_data
    FROM box_operations bo
    LEFT JOIN pos_deduction_transfers pdt ON pdt.box_operation_id = bo.id
    WHERE bo.status = 'completed'
      AND (p_branch_id = 'all' OR bo.branch_id = p_branch_id::int)
      AND (p_date_from IS NULL OR bo.start_time >= p_date_from::date)
      AND (p_date_to IS NULL OR bo.start_time < (p_date_to::date + interval '1 day'))
    ORDER BY bo.start_time DESC
    LIMIT p_limit
    OFFSET p_offset
  ) sub;

  RETURN jsonb_build_object('boxes', v_boxes, 'total_count', v_total_count);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_closed_boxes(text, text, text, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_closed_boxes(text, text, text, integer, integer) TO anon;
