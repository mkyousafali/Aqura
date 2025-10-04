-- Database Functions Schema
-- This file contains all the database functions needed by the application

-- Generic function to update updated_at column
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to update branches updated_at
CREATE OR REPLACE FUNCTION update_branches_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to update push subscriptions updated_at
CREATE OR REPLACE FUNCTION update_push_subscriptions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to update notification queue updated_at
CREATE OR REPLACE FUNCTION update_notification_queue_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to update user device sessions updated_at
CREATE OR REPLACE FUNCTION update_user_device_sessions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to update warning updated_at
CREATE OR REPLACE FUNCTION update_warning_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to update deadline datetime
CREATE OR REPLACE FUNCTION update_deadline_datetime()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.deadline_date IS NOT NULL THEN
        NEW.deadline_datetime = (NEW.deadline_date || ' ' || COALESCE(NEW.deadline_time::text, '23:59:59'))::timestamp with time zone;
    ELSE
        NEW.deadline_datetime = NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to create warning history
CREATE OR REPLACE FUNCTION create_warning_history()
RETURNS TRIGGER AS $$
BEGIN
    -- Handle different trigger operations
    IF TG_OP = 'INSERT' THEN
        INSERT INTO employee_warning_history (
            warning_id,
            action_type,
            new_values,
            changed_by,
            changed_by_username,
            change_reason
        ) VALUES (
            NEW.id,
            'created',
            row_to_json(NEW),
            NEW.issued_by,
            NEW.issued_by_username,
            'Warning created'
        );
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO employee_warning_history (
            warning_id,
            action_type,
            old_values,
            new_values,
            changed_by,
            changed_by_username,
            change_reason
        ) VALUES (
            NEW.id,
            'updated',
            row_to_json(OLD),
            row_to_json(NEW),
            NEW.issued_by,
            NEW.issued_by_username,
            'Warning updated'
        );
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO employee_warning_history (
            warning_id,
            action_type,
            old_values,
            changed_by,
            changed_by_username,
            change_reason
        ) VALUES (
            OLD.id,
            'deleted',
            row_to_json(OLD),
            OLD.deleted_by,
            'system',
            'Warning deleted'
        );
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Function to generate warning reference
CREATE OR REPLACE FUNCTION generate_warning_reference()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.warning_reference IS NULL OR NEW.warning_reference = '' THEN
        NEW.warning_reference = 'WRN-' || TO_CHAR(NEW.created_at, 'YYYYMMDD') || '-' || LPAD(nextval('warning_ref_seq')::text, 4, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create sequence for warning references
CREATE SEQUENCE IF NOT EXISTS warning_ref_seq START 1;

-- Function to sync fine paid columns
CREATE OR REPLACE FUNCTION sync_fine_paid_columns()
RETURNS TRIGGER AS $$
BEGIN
    -- Update fine_paid based on fine_status
    IF NEW.fine_status = 'paid' THEN
        NEW.fine_paid_date = COALESCE(NEW.fine_paid_date, CURRENT_TIMESTAMP);
        NEW.fine_paid_at = COALESCE(NEW.fine_paid_at, CURRENT_TIMESTAMP);
    ELSIF NEW.fine_status = 'pending' OR NEW.fine_status = 'cancelled' OR NEW.fine_status = 'waived' THEN
        -- Keep the paid date/time if it was already set
        IF NEW.fine_status != 'paid' AND OLD.fine_status = 'paid' THEN
            NEW.fine_paid_date = NULL;
            NEW.fine_paid_at = NULL;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to sync user roles from positions
CREATE OR REPLACE FUNCTION sync_user_roles_from_positions()
RETURNS TRIGGER AS $$
BEGIN
    -- This function would sync user roles based on position changes
    -- Implementation depends on business logic
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to cleanup assignment notifications
CREATE OR REPLACE FUNCTION trigger_cleanup_assignment_notifications()
RETURNS TRIGGER AS $$
BEGIN
    -- Clean up notifications related to the deleted assignment
    DELETE FROM notifications 
    WHERE task_assignment_id = OLD.id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Function to cleanup task notifications
CREATE OR REPLACE FUNCTION trigger_cleanup_task_notifications()
RETURNS TRIGGER AS $$
BEGIN
    -- Clean up notifications related to the deleted task
    DELETE FROM notifications 
    WHERE task_id = OLD.id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Function to log user actions
CREATE OR REPLACE FUNCTION log_user_action()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO user_audit_logs (
        user_id,
        action,
        table_name,
        record_id,
        old_values,
        new_values,
        created_at
    ) VALUES (
        CASE 
            WHEN TG_OP = 'DELETE' THEN OLD.id
            ELSE NEW.id
        END,
        TG_OP,
        TG_TABLE_NAME,
        CASE 
            WHEN TG_OP = 'DELETE' THEN OLD.id
            ELSE NEW.id
        END,
        CASE 
            WHEN TG_OP = 'UPDATE' THEN row_to_json(OLD)
            WHEN TG_OP = 'DELETE' THEN row_to_json(OLD)
            ELSE NULL
        END,
        CASE 
            WHEN TG_OP = 'INSERT' THEN row_to_json(NEW)
            WHEN TG_OP = 'UPDATE' THEN row_to_json(NEW)
            ELSE NULL
        END,
        now()
    );
    
    RETURN CASE 
        WHEN TG_OP = 'DELETE' THEN OLD
        ELSE NEW
    END;
END;
$$ LANGUAGE plpgsql;

-- Push Notification Functions

-- Main function to queue push notifications
CREATE OR REPLACE FUNCTION queue_push_notification(
    p_notification_id UUID,
    p_target_type TEXT,
    p_target_users JSONB DEFAULT NULL,
    p_target_roles TEXT[] DEFAULT NULL,
    p_target_branches UUID[] DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
    user_record RECORD;
    subscription_record RECORD;
    notification_data RECORD;
BEGIN
    -- Get notification data
    SELECT 
        title,
        body,
        type,
        created_at
    INTO notification_data
    FROM notifications 
    WHERE id = p_notification_id;
    
    IF NOT FOUND THEN
        RETURN;
    END IF;
    
    -- Process based on target type
    CASE p_target_type
        WHEN 'all_users' THEN
            -- Queue for all active users with push subscriptions
            FOR subscription_record IN 
                SELECT DISTINCT ps.user_id, ps.endpoint, ps.p256dh, ps.auth
                FROM push_subscriptions ps
                JOIN users u ON ps.user_id = u.id
                WHERE u.status = 'active'
                  AND ps.status = 'active'
            LOOP
                INSERT INTO notification_queue (
                    notification_id,
                    user_id,
                    endpoint,
                    p256dh,
                    auth,
                    payload,
                    status,
                    created_at
                ) VALUES (
                    p_notification_id,
                    subscription_record.user_id,
                    subscription_record.endpoint,
                    subscription_record.p256dh,
                    subscription_record.auth,
                    jsonb_build_object(
                        'title', notification_data.title,
                        'body', notification_data.body,
                        'type', notification_data.type,
                        'notification_id', p_notification_id
                    ),
                    'pending',
                    NOW()
                );
            END LOOP;
            
        WHEN 'specific_users' THEN
            -- Queue for specific users
            IF p_target_users IS NOT NULL THEN
                FOR subscription_record IN 
                    SELECT DISTINCT ps.user_id, ps.endpoint, ps.p256dh, ps.auth
                    FROM push_subscriptions ps
                    JOIN users u ON ps.user_id = u.id
                    WHERE u.status = 'active'
                      AND ps.status = 'active'
                      AND ps.user_id = ANY(
                          SELECT jsonb_array_elements_text(p_target_users)::UUID
                      )
                LOOP
                    INSERT INTO notification_queue (
                        notification_id,
                        user_id,
                        endpoint,
                        p256dh,
                        auth,
                        payload,
                        status,
                        created_at
                    ) VALUES (
                        p_notification_id,
                        subscription_record.user_id,
                        subscription_record.endpoint,
                        subscription_record.p256dh,
                        subscription_record.auth,
                        jsonb_build_object(
                            'title', notification_data.title,
                            'body', notification_data.body,
                            'type', notification_data.type,
                            'notification_id', p_notification_id
                        ),
                        'pending',
                        NOW()
                    );
                END LOOP;
            END IF;
            
        WHEN 'specific_roles' THEN
            -- Queue for users with specific roles
            IF p_target_roles IS NOT NULL THEN
                FOR subscription_record IN 
                    SELECT DISTINCT ps.user_id, ps.endpoint, ps.p256dh, ps.auth
                    FROM push_subscriptions ps
                    JOIN users u ON ps.user_id = u.id
                    JOIN user_roles ur ON u.id = ur.user_id
                    WHERE u.status = 'active'
                      AND ps.status = 'active'
                      AND ur.role_name = ANY(p_target_roles)
                LOOP
                    INSERT INTO notification_queue (
                        notification_id,
                        user_id,
                        endpoint,
                        p256dh,
                        auth,
                        payload,
                        status,
                        created_at
                    ) VALUES (
                        p_notification_id,
                        subscription_record.user_id,
                        subscription_record.endpoint,
                        subscription_record.p256dh,
                        subscription_record.auth,
                        jsonb_build_object(
                            'title', notification_data.title,
                            'body', notification_data.body,
                            'type', notification_data.type,
                            'notification_id', p_notification_id
                        ),
                        'pending',
                        NOW()
                    );
                END LOOP;
            END IF;
            
        WHEN 'specific_branches' THEN
            -- Queue for users in specific branches
            IF p_target_branches IS NOT NULL THEN
                FOR subscription_record IN 
                    SELECT DISTINCT ps.user_id, ps.endpoint, ps.p256dh, ps.auth
                    FROM push_subscriptions ps
                    JOIN users u ON ps.user_id = u.id
                    JOIN hr_employees e ON u.employee_id = e.id
                    WHERE u.status = 'active'
                      AND ps.status = 'active'
                      AND e.branch_id = ANY(p_target_branches)
                LOOP
                    INSERT INTO notification_queue (
                        notification_id,
                        user_id,
                        endpoint,
                        p256dh,
                        auth,
                        payload,
                        status,
                        created_at
                    ) VALUES (
                        p_notification_id,
                        subscription_record.user_id,
                        subscription_record.endpoint,
                        subscription_record.p256dh,
                        subscription_record.auth,
                        jsonb_build_object(
                            'title', notification_data.title,
                            'body', notification_data.body,
                            'type', notification_data.type,
                            'notification_id', p_notification_id
                        ),
                        'pending',
                        NOW()
                    );
                END LOOP;
            END IF;
    END CASE;
END;
$$ LANGUAGE plpgsql;

-- Trigger function to automatically queue push notifications
CREATE OR REPLACE FUNCTION trigger_queue_push_notification()
RETURNS TRIGGER AS $$
BEGIN
    -- Only queue push notifications for certain notification types
    IF NEW.type IN ('task_assignment', 'task_reminder', 'employee_warning', 'system_announcement') THEN
        PERFORM queue_push_notification(
            NEW.id,
            NEW.target_type,
            NEW.target_users,
            CASE 
                WHEN NEW.target_roles IS NOT NULL 
                THEN string_to_array(NEW.target_roles, ',')
                ELSE NULL 
            END,
            CASE 
                WHEN NEW.target_branches IS NOT NULL 
                THEN NEW.target_branches::UUID[]
                ELSE NULL 
            END
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;