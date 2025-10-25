-- ==========================================
-- COMPLETE CASH ON DELIVERY AUTO-PAYMENT TRIGGER
-- ==========================================
-- This script creates a comprehensive trigger that automatically:
-- 1. Marks Cash on Delivery payments as paid
-- 2. Creates payment transaction records  
-- 3. Creates tasks for accountants
-- 4. Creates task assignments
-- 5. Sends notifications

-- ==========================================
-- STEP 1: CREATE COMPREHENSIVE COD TRIGGER FUNCTION
-- ==========================================
CREATE OR REPLACE FUNCTION auto_process_cash_on_delivery()
RETURNS TRIGGER AS $$
DECLARE
    new_task_id UUID;
    new_assignment_id UUID;
    receiver_name TEXT;
    accountant_id UUID;
BEGIN
    -- Only process Cash on Delivery payments that are not already marked as paid
    IF NEW.payment_method ILIKE '%cash on delivery%' AND (NEW.is_paid IS NULL OR NEW.is_paid = false) THEN
        
        -- Mark as paid
        NEW.is_paid = true;
        NEW.payment_status = 'paid';
        NEW.paid_date = NOW();
        
        -- Create payment transaction record
        INSERT INTO payment_transactions (
            payment_schedule_id,
            receiving_record_id,
            amount,
            transaction_date,
            payment_method,
            bank_name,
            iban,
            vendor_name,
            bill_number,
            notes,
            created_at,
            updated_at
        ) VALUES (
            NEW.id,
            NEW.receiving_record_id,
            NEW.final_bill_amount,
            NOW(),
            NEW.payment_method,
            NEW.bank_name,
            NEW.iban,
            NEW.vendor_name,
            NEW.bill_number,
            'Auto-generated transaction for Cash on Delivery payment',
            NOW(),
            NOW()
        );
        
        -- Get receiver name and accountant from receiving_records
        SELECT 
            COALESCE(u.username, 'Unknown') as receiver_name,
            rr.accountant_user_id
        INTO receiver_name, accountant_id
        FROM receiving_records rr
        LEFT JOIN users u ON rr.user_id = u.id
        WHERE rr.id = NEW.receiving_record_id;
        
        -- Create task for accountant if accountant exists
        IF accountant_id IS NOT NULL THEN
            -- Create task
            INSERT INTO tasks (
                title,
                description,
                created_by,
                created_by_name,
                require_task_finished,
                priority,
                status,
                created_at,
                updated_at
            ) VALUES (
                'New payment made — enter into the ERP, update the ERP reference, and upload the payment receipt',
                'Payment Details:
- Bill Number: ' || COALESCE(NEW.bill_number, 'N/A') || '
- Bill Amount: ' || COALESCE(NEW.final_bill_amount::text, 'N/A') || '
- Vendor Name: ' || COALESCE(NEW.vendor_name, 'N/A') || '
- Receiver: ' || receiver_name || '
- Payment Method: ' || COALESCE(NEW.payment_method, 'N/A') || '

This Cash on Delivery payment was automatically processed and requires ERP entry and receipt upload.',
                (SELECT user_id FROM receiving_records WHERE id = NEW.receiving_record_id),
                receiver_name,
                true,
                'medium',
                'active',
                NOW(),
                NOW()
            ) RETURNING id INTO new_task_id;
            
            -- Create task assignment
            INSERT INTO task_assignments (
                task_id,
                assignment_type,
                assigned_to_user_id,
                assigned_by,
                assigned_by_name,
                deadline_date,
                require_task_finished,
                status,
                assigned_at
            ) VALUES (
                new_task_id,
                'user',
                accountant_id,
                (SELECT user_id FROM receiving_records WHERE id = NEW.receiving_record_id),
                'System - COD Auto-Processing',
                (NOW() + INTERVAL '1 day')::date,
                true,
                'assigned',
                NOW()
            ) RETURNING id INTO new_assignment_id;
            
            -- Update payment transaction with task references
            UPDATE payment_transactions 
            SET 
                task_id = new_task_id,
                task_assignment_id = new_assignment_id,
                updated_at = NOW()
            WHERE payment_schedule_id = NEW.id
              AND task_id IS NULL;
            
            -- Create notification for accountant
            INSERT INTO notifications (
                title,
                message,
                type,
                priority,
                target_type,
                target_users,
                created_by,
                created_by_name,
                task_id,
                task_assignment_id,
                created_at
            ) VALUES (
                'New COD Payment Task Assigned',
                'You have been assigned a Cash on Delivery payment processing task for ' || COALESCE(NEW.vendor_name, 'vendor') || 
                '. Bill Amount: ' || COALESCE(NEW.final_bill_amount::text, 'N/A'),
                'task_assigned',
                'medium',
                'specific_users',
                jsonb_build_array(accountant_id),
                (SELECT user_id FROM receiving_records WHERE id = NEW.receiving_record_id),
                'System - COD Auto-Processing',
                new_task_id,
                new_assignment_id,
                NOW()
            );
        END IF;
        
        RAISE NOTICE 'Cash on Delivery payment auto-processed: % for vendor %', NEW.final_bill_amount, NEW.vendor_name;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- STEP 2: CREATE/RECREATE TRIGGER
-- ==========================================
-- Drop existing triggers if they exist
DROP TRIGGER IF EXISTS trigger_auto_process_cash_on_delivery ON vendor_payment_schedule;
DROP TRIGGER IF EXISTS trigger_auto_update_payment_status ON vendor_payment_schedule;

-- Create the COD auto-processing trigger
CREATE TRIGGER trigger_auto_process_cash_on_delivery
    BEFORE INSERT ON vendor_payment_schedule
    FOR EACH ROW
    EXECUTE FUNCTION auto_process_cash_on_delivery();

-- Recreate the payment status sync trigger for updates
CREATE OR REPLACE FUNCTION auto_update_payment_status()
RETURNS TRIGGER AS $$
BEGIN
    -- If is_paid is being set to true and payment_status is not already 'paid'
    IF NEW.is_paid = true AND (OLD.is_paid IS NULL OR OLD.is_paid = false) AND NEW.payment_status != 'paid' THEN
        NEW.payment_status = 'paid';
        NEW.paid_date = COALESCE(NEW.paid_date, NOW());
    END IF;
    
    -- If is_paid is being set to false and payment_status is 'paid'
    IF NEW.is_paid = false AND OLD.is_paid = true AND NEW.payment_status = 'paid' THEN
        NEW.payment_status = 'scheduled';
        NEW.paid_date = NULL;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_auto_update_payment_status
    BEFORE UPDATE ON vendor_payment_schedule
    FOR EACH ROW
    EXECUTE FUNCTION auto_update_payment_status();

-- ==========================================
-- STEP 3: FIX EXISTING COD PAYMENTS
-- ==========================================

-- Fix existing COD payments that are marked as paid but missing transactions/tasks
DO $$
DECLARE
    cod_payment RECORD;
    new_task_id UUID;
    new_assignment_id UUID;
    receiver_name TEXT;
    accountant_id UUID;
    fixed_count INTEGER := 0;
BEGIN
    -- Loop through existing COD payments missing transactions
    FOR cod_payment IN
        SELECT 
            vps.id,
            vps.receiving_record_id,
            vps.final_bill_amount,
            vps.payment_method,
            vps.bank_name,
            vps.iban,
            vps.vendor_name,
            vps.bill_number,
            vps.paid_date,
            rr.accountant_user_id,
            rr.user_id as receiver_user_id,
            COALESCE(u.username, 'Unknown') as receiver_name
        FROM vendor_payment_schedule vps
        INNER JOIN receiving_records rr ON vps.receiving_record_id = rr.id
        LEFT JOIN users u ON rr.user_id = u.id
        WHERE vps.is_paid = true 
          AND vps.payment_method ILIKE '%cash on delivery%'
          AND NOT EXISTS (
            SELECT 1 FROM payment_transactions pt 
            WHERE pt.payment_schedule_id = vps.id
          )
    LOOP
        -- Create missing payment transaction record
        INSERT INTO payment_transactions (
            payment_schedule_id,
            receiving_record_id,
            amount,
            transaction_date,
            payment_method,
            bank_name,
            iban,
            vendor_name,
            bill_number,
            notes,
            created_at,
            updated_at
        ) VALUES (
            cod_payment.id,
            cod_payment.receiving_record_id,
            cod_payment.final_bill_amount,
            COALESCE(cod_payment.paid_date, NOW()),
            cod_payment.payment_method,
            cod_payment.bank_name,
            cod_payment.iban,
            cod_payment.vendor_name,
            cod_payment.bill_number,
            'Auto-generated transaction for existing COD payment (retroactive fix)',
            NOW(),
            NOW()
        );
        
        -- Create task for accountant if accountant exists
        IF cod_payment.accountant_user_id IS NOT NULL THEN
            -- Create task
            INSERT INTO tasks (
                title,
                description,
                created_by,
                created_by_name,
                require_task_finished,
                priority,
                status,
                created_at,
                updated_at
            ) VALUES (
                'New payment made — enter into the ERP, update the ERP reference, and upload the payment receipt',
                'Payment Details:
- Bill Number: ' || COALESCE(cod_payment.bill_number, 'N/A') || '
- Bill Amount: ' || COALESCE(cod_payment.final_bill_amount::text, 'N/A') || '
- Vendor Name: ' || COALESCE(cod_payment.vendor_name, 'N/A') || '
- Receiver: ' || cod_payment.receiver_name || '
- Payment Method: ' || COALESCE(cod_payment.payment_method, 'N/A') || '

This Cash on Delivery payment was automatically processed and requires ERP entry and receipt upload.',
                cod_payment.receiver_user_id,
                cod_payment.receiver_name,
                true,
                'medium',
                'active',
                COALESCE(cod_payment.paid_date, NOW()),
                NOW()
            ) RETURNING id INTO new_task_id;
            
            -- Create task assignment
            INSERT INTO task_assignments (
                task_id,
                assignment_type,
                assigned_to_user_id,
                assigned_by,
                assigned_by_name,
                deadline_date,
                require_task_finished,
                status,
                assigned_at
            ) VALUES (
                new_task_id,
                'user',
                cod_payment.accountant_user_id,
                cod_payment.receiver_user_id,
                'System - COD Retroactive Fix',
                (NOW() + INTERVAL '1 day')::date,
                true,
                'assigned',
                NOW()
            ) RETURNING id INTO new_assignment_id;
            
            -- Update payment transaction with task references
            UPDATE payment_transactions 
            SET 
                task_id = new_task_id,
                task_assignment_id = new_assignment_id,
                updated_at = NOW()
            WHERE payment_schedule_id = cod_payment.id
              AND task_id IS NULL;
            
            -- Create notification for accountant
            INSERT INTO notifications (
                title,
                message,
                type,
                priority,
                target_type,
                target_users,
                created_by,
                created_by_name,
                task_id,
                task_assignment_id,
                created_at
            ) VALUES (
                'COD Payment Task Assigned (Retroactive)',
                'You have been assigned a Cash on Delivery payment processing task for ' || COALESCE(cod_payment.vendor_name, 'vendor') || 
                '. Bill Amount: ' || COALESCE(cod_payment.final_bill_amount::text, 'N/A') || ' (Retroactive fix for missing task)',
                'task_assigned',
                'medium',
                'specific_users',
                jsonb_build_array(cod_payment.accountant_user_id),
                cod_payment.receiver_user_id,
                'System - COD Retroactive Fix',
                new_task_id,
                new_assignment_id,
                NOW()
            );
        END IF;
        
        fixed_count := fixed_count + 1;
    END LOOP;
    
    RAISE NOTICE 'Fixed % existing COD payments that were missing transactions/tasks', fixed_count;
END $$;

-- ==========================================
-- COMPLETION MESSAGE
-- ==========================================
DO $$
DECLARE
    existing_fixed INTEGER;
BEGIN
    -- Count how many existing COD payments were fixed
    SELECT COUNT(*) INTO existing_fixed 
    FROM payment_transactions pt
    INNER JOIN vendor_payment_schedule vps ON pt.payment_schedule_id = vps.id
    WHERE vps.payment_method ILIKE '%cash on delivery%'
      AND pt.notes LIKE '%retroactive fix%'
      AND pt.created_at >= NOW() - INTERVAL '5 minutes';

    RAISE NOTICE '✅ Complete Cash on Delivery fix completed!';
    RAISE NOTICE '🔧 Future COD payments will now automatically:';
    RAISE NOTICE '   - Be marked as paid (is_paid = true, payment_status = paid)';
    RAISE NOTICE '   - Create payment_transactions records';
    RAISE NOTICE '   - Create tasks for accountants';
    RAISE NOTICE '   - Create task assignments';
    RAISE NOTICE '   - Send notifications to accountants';
    RAISE NOTICE '📋 Fixed % existing COD payments that were missing transactions/tasks', existing_fixed;
    RAISE NOTICE '🚀 The COD automation is now complete and functional for both existing and future payments!';
END $$;