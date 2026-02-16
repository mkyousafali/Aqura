-- RPC function to handle stock request approval/rejection in a single transaction
-- Replaces 4-6 separate client-side queries with one atomic server-side operation:
-- 1. Update product_request_st status
-- 2. Auto-complete linked quick_tasks
-- 3. Auto-complete linked quick_task_assignments
-- 4. Insert notification to requester

CREATE OR REPLACE FUNCTION update_stock_request_status(
    p_request_id UUID,
    p_new_status VARCHAR
)
RETURNS JSONB AS $$
DECLARE
    v_requester_user_id UUID;
    v_status_label TEXT;
    v_status_label_ar TEXT;
    v_notif_type TEXT;
    v_message TEXT;
    v_title TEXT;
    v_tasks_completed INTEGER := 0;
    v_task_record RECORD;
BEGIN
    -- 1. Update the request status
    UPDATE product_request_st
    SET status = p_new_status, updated_at = NOW()
    WHERE id = p_request_id
    RETURNING requester_user_id INTO v_requester_user_id;

    IF v_requester_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Request not found');
    END IF;

    -- 2. Auto-complete linked quick tasks
    FOR v_task_record IN
        SELECT id FROM quick_tasks
        WHERE product_request_id = p_request_id
          AND product_request_type = 'ST'
    LOOP
        -- Complete task assignments
        UPDATE quick_task_assignments
        SET status = 'completed', completed_at = NOW()
        WHERE quick_task_id = v_task_record.id;

        -- Complete the task itself
        UPDATE quick_tasks
        SET status = 'completed', completed_at = NOW()
        WHERE id = v_task_record.id;

        v_tasks_completed := v_tasks_completed + 1;
    END LOOP;

    -- 3. Build notification content
    IF p_new_status = 'approved' THEN
        v_status_label := 'Accepted ✅';
        v_status_label_ar := 'مقبول ✅';
        v_notif_type := 'success';
        v_message := 'Your Stock Request has been approved.' || E'\n---\n' || 'طلب المخزون الخاص بك تم قبوله.';
    ELSE
        v_status_label := 'Rejected ❌';
        v_status_label_ar := 'مرفوض ❌';
        v_notif_type := 'error';
        v_message := 'Your Stock Request has been rejected.' || E'\n---\n' || 'طلب المخزون الخاص بك تم رفضه.';
    END IF;

    v_title := 'ST Request ' || v_status_label || ' | طلب ST ' || v_status_label_ar;

    -- 4. Insert notification
    INSERT INTO notifications (
        title, message, type, priority,
        target_type, target_users, status,
        total_recipients, created_at
    ) VALUES (
        v_title, v_message, v_notif_type, 'normal',
        'specific_users', jsonb_build_array(v_requester_user_id::TEXT), 'published',
        1, NOW()
    );

    RETURN jsonb_build_object(
        'success', true,
        'status', p_new_status,
        'tasks_completed', v_tasks_completed,
        'notification_sent', true
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION update_stock_request_status(UUID, VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION update_stock_request_status(UUID, VARCHAR) TO anon;
