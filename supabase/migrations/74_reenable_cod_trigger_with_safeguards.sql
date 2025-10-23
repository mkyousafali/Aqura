-- Migration 74: Fix COD Trigger with Better Safeguards
-- Re-enable trigger but add checks to prevent clearance certificate conflicts
-- The trigger should ONLY fire for actual COD payments, not random updates

BEGIN;

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS trigger_auto_create_payment_transaction_and_task ON vendor_payment_schedule;
DROP FUNCTION IF EXISTS auto_create_payment_transaction_and_task();

-- Create improved automation function with better error handling
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
    v_existing_transaction_count INTEGER;
BEGIN
    -- SAFETY CHECK: Only process if this is a valid INSERT operation with COD payment
    IF TG_OP = 'INSERT' THEN
        -- Check if this is a cash-on-delivery payment
        IF NEW.payment_method IS NOT NULL AND (
            NEW.payment_method ILIKE '%cash on delivery%' 
            OR NEW.payment_method ILIKE '%cash-on-delivery%'
            OR NEW.payment_method ILIKE '%cod%'
        ) THEN
            v_is_cash_on_delivery := TRUE;
            
            -- Check if transaction already exists (prevent duplicates)
            SELECT COUNT(*) INTO v_existing_transaction_count
            FROM payment_transactions
            WHERE payment_schedule_id = NEW.id;
            
            IF v_existing_transaction_count > 0 THEN
                -- Transaction already exists, skip processing
                RAISE NOTICE 'Skipping - transaction already exists for payment schedule: %', NEW.id;
                RETURN NEW;
            END IF;
            
            -- For cash-on-delivery, auto-mark as paid if not already paid
            IF NEW.is_paid IS FALSE OR NEW.is_paid IS NULL THEN
                v_should_auto_mark_paid := TRUE;
                -- Update the current record to mark as paid
                NEW.is_paid := TRUE;
                NEW.paid_date := NOW();
                NEW.payment_status := 'paid';
                
                RAISE NOTICE 'COD Payment detected - ID: %, Method: %, Auto-marking as paid', NEW.id, NEW.payment_method;
            END IF;
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
        -- For UPDATE, only process if is_paid changes from FALSE to TRUE (manual payment)
        IF (OLD.is_paid IS FALSE OR OLD.is_paid IS NULL) AND NEW.is_paid IS TRUE THEN
            -- Check if transaction already exists
            SELECT COUNT(*) INTO v_existing_transaction_count
            FROM payment_transactions
            WHERE payment_schedule_id = NEW.id;
            
            IF v_existing_transaction_count > 0 THEN
                RAISE NOTICE 'Skipping UPDATE - transaction already exists for payment schedule: %', NEW.id;
                RETURN NEW;
            END IF;
            
            v_should_auto_mark_paid := TRUE;
        ELSE
            -- Not a payment marking change, skip
            RETURN NEW;
        END IF;
    END IF;
    
    -- Only proceed if we should auto-mark or manually mark as paid
    IF NOT v_should_auto_mark_paid THEN
        RETURN NEW;
    END IF;
    
    -- SAFETY CHECK: Verify receiving record exists
    SELECT * INTO v_receiving_record 
    FROM receiving_records 
    WHERE id = NEW.receiving_record_id;
    
    IF v_receiving_record IS NULL THEN
        RAISE WARNING 'Receiving record not found for payment schedule ID: % - skipping automation', NEW.id;
        RETURN NEW;
    END IF;
    
    v_branch_id := v_receiving_record.branch_id;
    
    -- Get accountant ID from receiving records
    v_accountant_user_id := v_receiving_record.accountant_user_id;
    
    -- Get receiver user details
    SELECT id, username INTO v_receiver_user
    FROM users
    WHERE id = v_receiving_record.user_id;
    
    -- If no accountant in receiving record, find one
    IF v_accountant_user_id IS NULL THEN
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
    
    -- Create task
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
        E'\n• Due Date: ' || COALESCE(TO_CHAR(NEW.due_date, 'YYYY-MM-DD'), 'N/A'),
        true,
        true,
        true,
        true,
        true,
        'system',
        'Payment Automation System',
        'system',
        'active',
        'high',
        CURRENT_DATE + INTERVAL '1 day'
    ) RETURNING id INTO v_task_id;
    
    -- Create task assignment
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
    
    -- Create payment transaction
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
    
    -- Send notification
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
            E'\n\n⏰ Deadline: 24 hours',
            'task_assignment',
            'high',
            'task',
            v_task_id,
            jsonb_build_object(
                'task_id', v_task_id,
                'payment_schedule_id', NEW.id,
                'receiving_record_id', NEW.receiving_record_id,
                'bill_number', NEW.bill_number,
                'is_cash_on_delivery', v_is_cash_on_delivery
            )
        ) RETURNING id INTO v_notification_id;
    END IF;
    
    RAISE NOTICE '✅ Payment automation completed - Schedule ID: %, Task ID: %', NEW.id, v_task_id;
    
    RETURN NEW;
    
EXCEPTION WHEN OTHERS THEN
    -- Log error but don't fail the INSERT/UPDATE
    RAISE WARNING 'Payment automation error for schedule ID %: % - continuing without automation', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for INSERT only (most common case for COD)
CREATE TRIGGER trigger_auto_create_payment_transaction_and_task
    BEFORE INSERT ON vendor_payment_schedule
    FOR EACH ROW
    EXECUTE FUNCTION auto_create_payment_transaction_and_task();

COMMENT ON FUNCTION auto_create_payment_transaction_and_task() IS 'Migration 74: Fixed COD trigger with safeguards - checks for existing transactions, handles errors gracefully';
COMMENT ON TRIGGER trigger_auto_create_payment_transaction_and_task ON vendor_payment_schedule IS 'Triggers ONLY on INSERT for new COD payments';

DO $$
BEGIN
    RAISE NOTICE '✅ Migration 74 applied successfully!';
    RAISE NOTICE '   - COD trigger re-enabled with safety checks';
    RAISE NOTICE '   - Prevents duplicate transactions';
    RAISE NOTICE '   - Handles errors gracefully without breaking inserts';
    RAISE NOTICE '   - Only triggers on INSERT (new payments)';
END $$;

COMMIT;
