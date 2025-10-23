-- Migration: Auto Payment Transaction and Task Creation
-- File: 59_auto_payment_transaction_automation.sql
-- Description: Creates automation to automatically create payment transactions and accountant tasks when payments are marked as paid

BEGIN;

-- Function to automatically create payment transaction and accountant task when payment is marked as paid
CREATE OR REPLACE FUNCTION auto_create_payment_transaction_and_task()
RETURNS TRIGGER AS $$
DECLARE
    v_task_id UUID;
    v_assignment_id UUID;
    v_receiving_record RECORD;
    v_accountant_user_id UUID;
    v_branch_id INTEGER;
BEGIN
    -- Only trigger when is_paid changes from FALSE to TRUE
    IF (OLD.is_paid IS FALSE OR OLD.is_paid IS NULL) AND NEW.is_paid IS TRUE THEN
        
        -- Get receiving record details
        SELECT * INTO v_receiving_record 
        FROM receiving_records 
        WHERE id = NEW.receiving_record_id;
        
        IF v_receiving_record IS NULL THEN
            RAISE WARNING 'Receiving record not found for payment schedule ID: %', NEW.id;
            RETURN NEW;
        END IF;
        
        v_branch_id := v_receiving_record.branch_id;
        
        -- Find a suitable user for this branch (prefer managers/admins since no specific accountant role exists)
        -- First try: look for users with manager/admin roles in the same branch
        SELECT u.id INTO v_accountant_user_id
        FROM users u
        WHERE u.status = 'active'
        AND u.branch_id = v_branch_id
        AND (
            u.role_type::text LIKE '%manager%' OR 
            u.role_type::text LIKE '%admin%' OR 
            u.role_type::text LIKE '%Manager%' OR 
            u.role_type::text LIKE '%Admin%'
        )
        ORDER BY u.created_at ASC
        LIMIT 1;
        
        -- Second try: any user in the same branch
        IF v_accountant_user_id IS NULL THEN
            SELECT u.id INTO v_accountant_user_id
            FROM users u
            WHERE u.status = 'active'
            AND u.branch_id = v_branch_id
            ORDER BY u.created_at ASC
            LIMIT 1;
        END IF;
        
        -- Third try: any active user (fallback)
        IF v_accountant_user_id IS NULL THEN
            SELECT u.id INTO v_accountant_user_id
            FROM users u
            WHERE u.status = 'active'
            ORDER BY 
                CASE WHEN u.branch_id = v_branch_id THEN 1 ELSE 2 END,
                u.created_at ASC
            LIMIT 1;
        END IF;
        
        -- If no accountant found, log warning but continue
        IF v_accountant_user_id IS NULL THEN
            RAISE WARNING 'No accountant found for branch ID: %, using system default', v_branch_id;
            -- You might want to set a default system user here
        END IF;
        
        -- Create task for accountant
        INSERT INTO tasks (
            title,
            description,
            require_task_finished,
            require_photo_upload,
            require_erp_reference,
            can_escalate,
            can_reassign,
            created_by,
            created_by_name,
            created_by_role,
            status,
            priority,
            due_date
        ) VALUES (
            'Payment Processing: ' || COALESCE(NEW.bill_number, 'Bill #' || NEW.id),
            'Process payment transaction for vendor ' || COALESCE(NEW.vendor_name, 'Unknown Vendor') || 
            E'\n\nPayment Details:' ||
            E'\n- Bill Number: ' || COALESCE(NEW.bill_number, 'N/A') ||
            E'\n- Amount: SAR ' || NEW.final_bill_amount ||
            E'\n- Payment Method: ' || COALESCE(NEW.payment_method, 'N/A') ||
            E'\n- Bank: ' || COALESCE(NEW.bank_name, 'N/A') ||
            E'\n- IBAN: ' || COALESCE(NEW.iban, 'N/A') ||
            E'\n- Due Date: ' || TO_CHAR(NEW.due_date, 'YYYY-MM-DD') ||
            E'\n\nPlease verify payment details and complete the transaction processing.',
            true,  -- require_task_finished
            false, -- require_photo_upload
            true,  -- require_erp_reference
            true,  -- can_escalate
            true,  -- can_reassign
            'system', -- created_by
            'Payment Automation System', -- created_by_name
            'system', -- created_by_role
            'active', -- status
            'high', -- priority
            CURRENT_DATE + INTERVAL '3 days' -- due_date: 3 days from now
        ) RETURNING id INTO v_task_id;
        
        -- Create task assignment if accountant found
        IF v_accountant_user_id IS NOT NULL THEN
            INSERT INTO task_assignments (
                task_id,
                assignment_type,
                assigned_by,
                assigned_by_name,
                assigned_to_user_id,
                status,
                notes
            ) VALUES (
                v_task_id,
                'user',
                'system',
                'Payment Automation System',
                v_accountant_user_id,
                'assigned',
                'Auto-assigned for payment processing of bill: ' || COALESCE(NEW.bill_number, NEW.id::text)
            ) RETURNING id INTO v_assignment_id;
        END IF;
        
        -- Create payment transaction record
        INSERT INTO payment_transactions (
            payment_schedule_id,
            receiving_record_id,
            receiver_user_id,
            accountant_user_id,
            task_id,
            task_assignment_id,
            transaction_date,
            amount,
            payment_method,
            bank_name,
            iban,
            vendor_name,
            bill_number,
            original_bill_url,
            notes,
            verification_status
        ) VALUES (
            NEW.id,
            NEW.receiving_record_id,
            v_receiving_record.user_id,
            v_accountant_user_id,
            v_task_id,
            v_assignment_id,
            COALESCE(NEW.paid_date, NOW()),
            NEW.final_bill_amount,
            NEW.payment_method,
            NEW.bank_name,
            NEW.iban,
            NEW.vendor_name,
            NEW.bill_number,
            v_receiving_record.original_bill_url,
            'Auto-created from payment schedule when marked as paid on ' || NOW()::date,
            'pending'
        );
        
        -- Update the payment schedule with paid date if not set
        IF NEW.paid_date IS NULL THEN
            UPDATE vendor_payment_schedule 
            SET paid_date = NOW() 
            WHERE id = NEW.id;
        END IF;
        
        RAISE NOTICE 'Created payment transaction and task for payment schedule ID: %, Task ID: %', NEW.id, v_task_id;
        
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trigger_auto_create_payment_transaction_and_task ON vendor_payment_schedule;

-- Create trigger on vendor_payment_schedule to auto-create payment transactions and tasks when is_paid = true
CREATE TRIGGER trigger_auto_create_payment_transaction_and_task
    AFTER UPDATE ON vendor_payment_schedule
    FOR EACH ROW
    EXECUTE FUNCTION auto_create_payment_transaction_and_task();

-- Add comments for documentation
COMMENT ON FUNCTION auto_create_payment_transaction_and_task() IS 'Automatically creates payment transaction record and accountant task when payment is marked as paid';
COMMENT ON TRIGGER trigger_auto_create_payment_transaction_and_task ON vendor_payment_schedule IS 'Triggers payment transaction and task creation when is_paid changes to TRUE';

COMMIT;