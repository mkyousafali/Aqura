-- Migration: Create function to send reminder notifications 2 days before scheduled occurrences
-- This function should be called daily by a cron job or scheduled task
-- Note: Occurrences are created immediately by generate_recurring_occurrences() function

-- Create function to send reminders for upcoming scheduled payments
CREATE OR REPLACE FUNCTION check_and_notify_recurring_schedules()
RETURNS TABLE (
    schedule_id INTEGER,
    notification_sent BOOLEAN,
    message TEXT
) AS $$
DECLARE
    rec RECORD;
    notification_exists BOOLEAN;
BEGIN
    -- Process all scheduled single_bill occurrences that are 2 days away
    -- These occurrences were created by generate_recurring_occurrences() function
    FOR rec IN 
        SELECT 
            id,
            branch_id,
            branch_name,
            expense_category_id,
            expense_category_name_en,
            expense_category_name_ar,
            co_user_id,
            co_user_name,
            payment_method,
            amount,
            description,
            bill_type,
            due_date,
            recurring_metadata,
            approver_id,
            approver_name,
            'non_approved_payment_scheduler' as source_table
        FROM non_approved_payment_scheduler
        WHERE schedule_type = 'single_bill'
        AND approval_status = 'pending'
        AND due_date = CURRENT_DATE + INTERVAL '2 days'
        AND recurring_metadata->>'parent_schedule_id' IS NOT NULL -- Only recurring occurrences
        
        UNION ALL
        
        SELECT 
            id,
            branch_id,
            branch_name,
            expense_category_id,
            expense_category_name_en,
            expense_category_name_ar,
            co_user_id,
            co_user_name,
            payment_method,
            amount,
            description,
            bill_type,
            due_date,
            recurring_metadata,
            NULL::INTEGER as approver_id,
            NULL::TEXT as approver_name,
            'expense_scheduler' as source_table
        FROM expense_scheduler
        WHERE schedule_type = 'single_bill'
        AND status = 'pending'
        AND is_paid = FALSE
        AND due_date = CURRENT_DATE + INTERVAL '2 days'
        AND recurring_metadata->>'parent_schedule_id' IS NOT NULL -- Only recurring occurrences
    LOOP
        -- Check if notification already sent for this occurrence
        SELECT EXISTS(
            SELECT 1 FROM notifications
            WHERE metadata->>'schedule_id' = rec.id::TEXT
            AND metadata->>'occurrence_date' = rec.due_date::TEXT
            AND type = 'approval_request'
            AND created_at >= CURRENT_DATE
        ) INTO notification_exists;
        
        -- Send notification if not already sent
        IF NOT notification_exists THEN
            INSERT INTO notifications (
                title,
                message,
                type,
                priority,
                target_type,
                target_users,
                created_by,
                metadata
            ) VALUES (
                FORMAT('Recurring Payment Approval Required - Due: %s', TO_CHAR(rec.due_date, 'DD Mon YYYY')),
                FORMAT(
                    'A recurring expense payment requires your approval.

Branch: %s
Category: %s
Amount: %s SAR
Due Date: %s
Payment Method: %s
Recurring Type: %s

This payment is due in 2 days. Please review and approve.',
                    rec.branch_name,
                    rec.expense_category_name_en,
                    rec.amount::TEXT,
                    TO_CHAR(rec.due_date, 'DD Mon YYYY'),
                    COALESCE(REPLACE(rec.payment_method, '_', ' '), 'N/A'),
                    REPLACE(rec.recurring_metadata->>'recurring_type', '_', ' ')
                ),
                'approval_request',
                'high',
                'specific_users',
                ARRAY[COALESCE(rec.approver_id, rec.co_user_id)], -- Send to approver or CO user
                'system',
                jsonb_build_object(
                    'schedule_id', rec.id,
                    'occurrence_date', rec.due_date,
                    'parent_schedule_id', rec.recurring_metadata->>'parent_schedule_id',
                    'recurring_type', rec.recurring_metadata->>'recurring_type',
                    'source_table', rec.source_table
                )
            );
            
            schedule_id := rec.id;
            notification_sent := TRUE;
            message := FORMAT('Sent reminder notification for schedule ID %s (due date: %s)', rec.id, rec.due_date);
            RETURN NEXT;
        END IF;
    END LOOP;
    
    RETURN;
END;
$$ LANGUAGE plpgsql;

-- Add comment to function
COMMENT ON FUNCTION check_and_notify_recurring_schedules() IS 
'Sends reminder notifications to approvers/users 2 days before scheduled payment occurrences. Occurrences are pre-created by generate_recurring_occurrences() function.';

-- Grant execute permission
GRANT EXECUTE ON FUNCTION check_and_notify_recurring_schedules() TO authenticated;
GRANT EXECUTE ON FUNCTION check_and_notify_recurring_schedules() TO service_role;
