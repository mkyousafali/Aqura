CREATE OR REPLACE FUNCTION get_bt_assigned_ims(p_request_ids UUID[])
RETURNS TABLE (
    product_request_id UUID,
    assigned_to_user_id UUID
) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        qt.product_request_id,
        qta.assigned_to_user_id
    FROM quick_tasks qt
    INNER JOIN quick_task_assignments qta ON qta.quick_task_id = qt.id
    WHERE qt.product_request_type = 'BT'
    AND qt.product_request_id = ANY(p_request_ids);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_bt_assigned_ims(UUID[]) TO authenticated;
GRANT EXECUTE ON FUNCTION get_bt_assigned_ims(UUID[]) TO anon;
