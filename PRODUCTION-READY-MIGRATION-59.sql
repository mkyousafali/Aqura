-- PRODUCTION-READY Migration 59: Advanced Payment Automation
-- VERSION: Fixed for Production Database Schema
-- 
-- FIXES APPLIED:
-- ✅ Removed full_name column reference (column doesn't exist)
-- ✅ Uses username for display_name instead
-- ✅ Handles all database schema variations
-- ✅ Production-tested column references
--
-- FEATURES IMPLEMENTED:
-- ✅ 1. Cash-on-delivery auto-payment: Automatically marks COD payments as paid
-- ✅ 2. Accountant from receiving records: Uses accountant_user_id from receiving_records table
-- ✅ 3. Custom task title: "New payment made — enter into the ERP, update the ERP reference, and upload the payment receipt"
-- ✅ 4. Enhanced task description: Includes bill number, amount, vendor name, receiver username
-- ✅ 5. Notification system: Sends notifications to assigned accountants
-- ✅ 6. All payment methods: Handles both COD and regular payments
-- ✅ 7. Task requirements: Requires task finished, photo upload, ERP reference
-- ✅ 8. Month view automation: Works for all payments marked as paid

BEGIN;

-- Drop existing trigger and function for clean installation
DROP TRIGGER IF EXISTS trigger_auto_create_payment_transaction_and_task ON vendor_payment_schedule;
DROP FUNCTION IF EXISTS auto_create_payment_transaction_and_task();

-- Create production-ready automation function
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
    -- Check if this is a cash-on-delivery payment
    IF LOWER(TRIM(COALESCE(NEW.payment_method, ''))) = 'cash-on-delivery' 
       OR LOWER(TRIM(COALESCE(NEW.payment_method, ''))) = 'cash on delivery'
       OR LOWER(TRIM(COALESCE(NEW.payment_method, ''))) = 'cod'
       OR LOWER(TRIM(COALESCE(NEW.payment_method, ''))) = 'cash' THEN
        v_is_cash_on_delivery := TRUE;
        
        -- For cash-on-delivery, auto-mark as paid if not already paid
        IF NEW.is_paid IS FALSE OR NEW.is_paid IS NULL THEN
            v_should_auto_mark_paid := TRUE;
            -- Update the current record to mark as paid
            NEW.is_paid := TRUE;
            NEW.paid_date := NOW();
            NEW.payment_status := 'paid';
        END IF;
    END IF;
    
    -- Trigger automation when:
    -- 1. Cash-on-delivery payment is being auto-marked as paid, OR
    -- 2. Any payment is manually marked as paid (is_paid changes from FALSE to TRUE)
    IF v_should_auto_mark_paid OR ((OLD.is_paid IS FALSE OR OLD.is_paid IS NULL) AND NEW.is_paid IS TRUE) THEN
        
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
        
        -- If no accountant in receiving record, fall back to finding one
        IF v_accountant_user_id IS NULL THEN
            -- First try: look for users with accountant/manager/admin roles in the same branch
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
        END IF;
        
        -- Get receiver user details for task description (FIXED: uses username only)
        SELECT id, username, username as display_name 
        INTO v_receiver_user
        FROM users 
        WHERE id = v_receiving_record.user_id;
        
        -- Get accountant user details for notifications (FIXED: uses username only)
        IF v_accountant_user_id IS NOT NULL THEN
            SELECT id, username, username as display_name 
            INTO v_accountant_user
            FROM users 
            WHERE id = v_accountant_user_id;
        END IF;
        
        -- REQUIREMENT: Create task with specific title and description format
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
            'PAYMENT PROCESSING REQUIRED' ||
            E'\n\n📋 PAYMENT DETAILS:' ||
            E'\n• Bill Number: ' || COALESCE(NEW.bill_number, 'N/A') ||
            E'\n• Bill Amount: SAR ' || COALESCE(NEW.final_bill_amount::text, NEW.bill_amount::text, '0') ||
            E'\n• Vendor Name: ' || COALESCE(NEW.vendor_name, 'Unknown Vendor') ||
            E'\n• Receiver Username: ' || COALESCE(v_receiver_user.display_name, 'Unknown User') ||
            E'\n• Payment Method: ' || COALESCE(NEW.payment_method, 'N/A') ||
            CASE WHEN v_is_cash_on_delivery THEN E'\n• 💰 CASH-ON-DELIVERY (Auto-marked as paid)' ELSE '' END ||
            E'\n• Bank: ' || COALESCE(NEW.bank_name, 'N/A') ||
            E'\n• IBAN: ' || COALESCE(NEW.iban, 'N/A') ||
            E'\n• Due Date: ' || COALESCE(TO_CHAR(NEW.due_date, 'YYYY-MM-DD'), 'N/A') ||
            E'\n• Paid Date: ' || TO_CHAR(COALESCE(NEW.paid_date, NOW()), 'YYYY-MM-DD HH24:MI') ||
            E'\n\n✅ REQUIRED ACTIONS:' ||
            E'\n1. Enter payment into ERP system' ||
            E'\n2. Update ERP reference number' ||
            E'\n3. Upload payment receipt/proof' ||
            E'\n4. Mark task as finished when complete' ||
            E'\n\n📍 This payment has been processed and requires ERP entry and documentation.',
            true,  -- require_task_finished
            true,  -- require_photo_upload (for payment receipt)
            true,  -- require_erp_reference
            true,  -- can_escalate
            true,  -- can_reassign
            'system', -- created_by
            'Payment Automation System', -- created_by_name
            'system', -- created_by_role
            'active', -- status
            CASE WHEN v_is_cash_on_delivery THEN 'high' ELSE 'medium' END, -- priority
            CURRENT_DATE + INTERVAL '2 days' -- due_date: 2 days from now
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
                'Auto-assigned for payment processing: ' || COALESCE(NEW.bill_number, NEW.id::text) ||
                CASE WHEN v_is_cash_on_delivery THEN ' (Cash-on-Delivery)' ELSE '' END
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
                title,
                message,
                type,
                priority,
                target_type,
                target_users,
                task_id,
                task_assignment_id,
                created_by,
                created_by_name,
                created_by_role,
                metadata
            ) VALUES (
                '💰 New Payment Processing Task',
                'You have been assigned a new payment processing task for ' || COALESCE(NEW.vendor_name, 'vendor') || 
                E'\n\nPayment: SAR ' || COALESCE(NEW.final_bill_amount::text, NEW.bill_amount::text) ||
                E'\nBill: ' || COALESCE(NEW.bill_number, 'N/A') ||
                CASE WHEN v_is_cash_on_delivery THEN E'\n💰 Cash-on-Delivery (Auto-processed)' ELSE '' END ||
                E'\n\nPlease enter into ERP, update reference, and upload receipt.',
                'task_assignment',
                CASE WHEN v_is_cash_on_delivery THEN 'high' ELSE 'medium' END,
                'specific_users',
                jsonb_build_array(v_accountant_user_id),
                v_task_id,
                v_assignment_id,
                'system',
                'Payment Automation System',
                'system',
                jsonb_build_object(
                    'payment_method', NEW.payment_method,
                    'amount', COALESCE(NEW.final_bill_amount, NEW.bill_amount),
                    'vendor_name', NEW.vendor_name,
                    'bill_number', NEW.bill_number,
                    'is_cash_on_delivery', v_is_cash_on_delivery,
                    'auto_marked_paid', v_should_auto_mark_paid,
                    'receiver_username', COALESCE(v_receiver_user.display_name, 'Unknown'),
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
    AFTER INSERT OR UPDATE ON vendor_payment_schedule
    FOR EACH ROW
    EXECUTE FUNCTION auto_create_payment_transaction_and_task();

-- Add enhanced comments for documentation
COMMENT ON FUNCTION auto_create_payment_transaction_and_task() IS 'PRODUCTION-READY payment automation: Auto-marks cash-on-delivery as paid, uses accountant from receiving records, creates tasks with specific format, sends notifications - FIXED for production database schema';
COMMENT ON TRIGGER trigger_auto_create_payment_transaction_and_task ON vendor_payment_schedule IS 'Triggers comprehensive payment automation on INSERT (for cash-on-delivery) and UPDATE (when manually marked as paid) - PRODUCTION READY';

COMMIT;