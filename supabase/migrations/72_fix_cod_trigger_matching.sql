-- Migration 72: Fix Cash-on-Delivery Pattern Matching in Trigger
-- Description: Updates trigger to handle all possible COD payment method variations
-- Date: 2025-10-23
-- Version: 1.0.11
--
-- PROBLEM: Trigger isn't matching payment methods like "Cash on Delivery" (with spaces and capitalization)
-- SOLUTION: Use ILIKE (case-insensitive) pattern matching instead of exact equality

BEGIN;

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS trigger_auto_create_payment_transaction_and_task ON vendor_payment_schedule;
DROP FUNCTION IF EXISTS auto_create_payment_transaction_and_task();

-- Create the improved automation function with better pattern matching
CREATE OR REPLACE FUNCTION auto_create_payment_transaction_and_task()
RETURNS TRIGGER AS $$
DECLARE
    v_task_id UUID;
    v_assignment_id UUID;
    v_notification_id UUID;
    v_receiving_record RECORD;
    v_accountant_user_id UUID;
    v_receiver_user RECORD;
    v_accountant_user RECORD;
    v_branch_id INTEGER;
    v_is_cash_on_delivery BOOLEAN := FALSE;
    v_should_auto_mark_paid BOOLEAN := FALSE;
BEGIN
    -- Check if this is a cash-on-delivery payment (IMPROVED MATCHING)
    -- Uses ILIKE for case-insensitive pattern matching
    IF NEW.payment_method IS NOT NULL AND (
        NEW.payment_method ILIKE '%cash on delivery%' 
        OR NEW.payment_method ILIKE '%cash-on-delivery%'
        OR NEW.payment_method ILIKE '%cod%'
        OR NEW.payment_method ILIKE 'cash on delivery'
        OR NEW.payment_method ILIKE 'cash-on-delivery'
        OR NEW.payment_method ILIKE 'cod'
    ) THEN
        v_is_cash_on_delivery := TRUE;
        
        -- For cash-on-delivery, auto-mark as paid if not already paid
        IF NEW.is_paid IS FALSE OR NEW.is_paid IS NULL THEN
            v_should_auto_mark_paid := TRUE;
            -- Update the current record to mark as paid
            NEW.is_paid := TRUE;
            NEW.paid_date := NOW();
            NEW.payment_status := 'paid';
            
            -- Debug log
            RAISE NOTICE 'COD Payment detected - ID: %, Method: %, Auto-marking as paid', NEW.id, NEW.payment_method;
        END IF;
    END IF;
    
    -- Trigger automation when:
    -- 1. Cash-on-delivery payment is being auto-marked as paid (INSERT), OR
    -- 2. Any payment is manually marked as paid (UPDATE where is_paid changes from FALSE to TRUE)
    IF v_should_auto_mark_paid OR (TG_OP = 'UPDATE' AND (OLD.is_paid IS FALSE OR OLD.is_paid IS NULL) AND NEW.is_paid IS TRUE) THEN
        
        -- Get receiving record details
        SELECT * INTO v_receiving_record 
        FROM receiving_records 
        WHERE id = NEW.receiving_record_id;
        
        IF v_receiving_record IS NULL THEN
            RAISE WARNING 'Receiving record not found for payment schedule ID: %', NEW.id;
            RETURN NEW;
        END IF;
        
        v_branch_id := v_receiving_record.branch_id;
        
        -- REQUIREMENT: Use accountant ID from receiving records
        v_accountant_user_id := v_receiving_record.accountant_user_id;
        
        -- Get receiver user details for notification
        SELECT id, username INTO v_receiver_user
        FROM users
        WHERE id = v_receiving_record.user_id;
        
        -- If no accountant in receiving record, find one
        IF v_accountant_user_id IS NULL THEN
            -- Try to find accountant/manager/admin in the same branch
            SELECT u.id INTO v_accountant_user_id
            FROM users u
            WHERE u.status = 'active'
            AND u.branch_id = v_branch_id
            AND (
                u.role_type::text ILIKE '%accountant%' OR
                u.role_type::text ILIKE '%manager%' OR 
                u.role_type::text ILIKE '%admin%'
            )
            ORDER BY 
                CASE WHEN u.role_type::text ILIKE '%accountant%' THEN 1 ELSE 2 END,
                u.created_at ASC
            LIMIT 1;
            
            -- Fallback: any active user in branch
            IF v_accountant_user_id IS NULL THEN
                SELECT u.id INTO v_accountant_user_id
                FROM users u
                WHERE u.status = 'active'
                AND u.branch_id = v_branch_id
                ORDER BY u.created_at ASC
                LIMIT 1;
            END IF;
        END IF;
        
        -- Get accountant user details
        IF v_accountant_user_id IS NOT NULL THEN
            SELECT id, username INTO v_accountant_user
            FROM users
            WHERE id = v_accountant_user_id;
        END IF;
        
        -- REQUIREMENT: Create task with specific title
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
            'New payment made — enter into the ERP, update the ERP reference, and upload the payment receipt',
            'Process payment transaction for vendor payment' ||
            E'\n\n📋 Payment Details:' ||
            E'\n• Bill Number: ' || COALESCE(NEW.bill_number, 'N/A') ||
            E'\n• Bill Amount: SAR ' || COALESCE(NEW.final_bill_amount::text, NEW.bill_amount::text, '0') ||
            E'\n• Vendor Name: ' || COALESCE(NEW.vendor_name, 'Unknown Vendor') ||
            E'\n• Receiver Username: ' || COALESCE(v_receiver_user.username, 'Unknown User') ||
            E'\n• Payment Method: ' || COALESCE(NEW.payment_method, 'N/A') ||
            CASE WHEN v_is_cash_on_delivery THEN E'\n• 💰 CASH-ON-DELIVERY (Auto-marked as paid)' ELSE '' END ||
            E'\n• Bank: ' || COALESCE(NEW.bank_name, 'N/A') ||
            E'\n• IBAN: ' || COALESCE(NEW.iban, 'N/A') ||
            E'\n• Due Date: ' || COALESCE(TO_CHAR(NEW.due_date, 'YYYY-MM-DD'), 'N/A') ||
            E'\n\n📝 Required Actions:' ||
            E'\n1. Enter payment details into ERP system' ||
            E'\n2. Update ERP reference number in the system' ||
            E'\n3. Upload payment receipt/proof' ||
            E'\n4. Mark task as finished',
            true,  -- require_task_finished
            true,  -- require_photo_upload (payment receipt)
            true,  -- require_erp_reference
            true,  -- can_escalate
            true,  -- can_reassign
            'system',
            'Payment Automation System',
            'system',
            'active',
            'high',
            CURRENT_DATE + INTERVAL '1 day' -- Due tomorrow (24 hours deadline)
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
                'Auto-assigned for payment processing of bill: ' || COALESCE(NEW.bill_number, NEW.id::text) ||
                CASE WHEN v_is_cash_on_delivery THEN ' (Cash-on-Delivery - Auto-paid)' ELSE '' END
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
            COALESCE(NEW.final_bill_amount, NEW.bill_amount),
            NEW.payment_method,
            NEW.bank_name,
            NEW.iban,
            NEW.vendor_name,
            NEW.bill_number,
            v_receiving_record.original_bill_url,
            'Auto-created from payment schedule on ' || NOW()::date ||
            CASE WHEN v_is_cash_on_delivery THEN ' (Cash-on-Delivery - Auto-paid)' ELSE ' (Manually marked as paid)' END,
            'pending'
        );
        
        -- REQUIREMENT: Send notification to accountant
        IF v_accountant_user_id IS NOT NULL THEN
            INSERT INTO notifications (
                user_id,
                title,
                message,
                type,
                priority,
                reference_type,
                reference_id,
                data
            ) VALUES (
                v_accountant_user_id,
                '💰 New Payment Processing Task',
                'You have been assigned a new payment processing task for ' || COALESCE(NEW.vendor_name, 'vendor') || 
                E'\n\nBill: ' || COALESCE(NEW.bill_number, 'N/A') ||
                E'\nAmount: SAR ' || COALESCE(NEW.final_bill_amount::text, NEW.bill_amount::text, '0') ||
                CASE WHEN v_is_cash_on_delivery THEN E'\n\n💰 This is a CASH-ON-DELIVERY payment (auto-marked as paid)' ELSE '' END ||
                E'\n\n⏰ Deadline: 24 hours' ||
                E'\n\nPlease process this payment in the ERP system and upload the payment receipt.',
                'task_assignment',
                'high',
                'task',
                v_task_id,
                jsonb_build_object(
                    'task_id', v_task_id,
                    'payment_schedule_id', NEW.id,
                    'receiving_record_id', NEW.receiving_record_id,
                    'bill_number', NEW.bill_number,
                    'is_cash_on_delivery', v_is_cash_on_delivery,
                    'auto_marked_paid', v_should_auto_mark_paid,
                    'receiver_username', COALESCE(v_receiver_user.username, 'Unknown'),
                    'accountant_source', CASE WHEN v_receiving_record.accountant_user_id IS NOT NULL THEN 'receiving_record' ELSE 'auto_assigned' END
                )
            ) RETURNING id INTO v_notification_id;
        END IF;
        
        -- Log the automation result
        RAISE NOTICE 'Payment automation completed - Schedule ID: %, Task ID: %, Accountant: %, Notification: %, Cash-on-Delivery: %, Auto-paid: %', 
            NEW.id, v_task_id, v_accountant_user_id, v_notification_id, v_is_cash_on_delivery, v_should_auto_mark_paid;
        
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on vendor_payment_schedule for both INSERT and UPDATE
-- This handles both cash-on-delivery auto-payments and manual payment marking
CREATE TRIGGER trigger_auto_create_payment_transaction_and_task
    BEFORE INSERT OR UPDATE ON vendor_payment_schedule
    FOR EACH ROW
    EXECUTE FUNCTION auto_create_payment_transaction_and_task();

-- Add comments for documentation
COMMENT ON FUNCTION auto_create_payment_transaction_and_task() IS 'FIXED v1.0.11 (Migration 72): Improved COD pattern matching with ILIKE, auto-marks cash-on-delivery as paid on INSERT';
COMMENT ON TRIGGER trigger_auto_create_payment_transaction_and_task ON vendor_payment_schedule IS 'Triggers on INSERT (COD auto-payment) and UPDATE (manual payment marking) with improved pattern matching';

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Migration 72 applied successfully!';
    RAISE NOTICE '   - Improved COD pattern matching (ILIKE for case-insensitive)';
    RAISE NOTICE '   - Handles: "Cash on Delivery", "Cash-on-Delivery", "COD", etc.';
    RAISE NOTICE '   - Added TG_OP check for UPDATE operations';
END $$;

COMMIT;
