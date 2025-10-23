-- ENHANCED Migration: Fix Cash-on-Delivery Auto-Scheduling
-- This fixes the issue where cash-on-delivery payments are not being auto-scheduled
-- 
-- PROBLEM: Cash-on-delivery payments should be scheduled immediately when receiving records
-- are created/updated, but the current trigger only schedules when certificate is generated.
--
-- SOLUTION: Enhanced auto-scheduling trigger that handles cash-on-delivery payments
-- immediately, regardless of certificate status.

BEGIN;

-- Drop and recreate the auto-scheduling function with cash-on-delivery support
DROP FUNCTION IF EXISTS auto_schedule_payment_on_certificate_generation();

CREATE OR REPLACE FUNCTION auto_schedule_payment_on_certificate_generation()
RETURNS TRIGGER AS $$
DECLARE
    v_is_cash_payment BOOLEAN := FALSE;
    v_should_schedule BOOLEAN := FALSE;
BEGIN
    -- Check if this is a cash-on-delivery payment
    IF LOWER(TRIM(COALESCE(NEW.payment_method, ''))) = 'cash-on-delivery' 
       OR LOWER(TRIM(COALESCE(NEW.payment_method, ''))) = 'cash on delivery'
       OR LOWER(TRIM(COALESCE(NEW.payment_method, ''))) = 'cod'
       OR LOWER(TRIM(COALESCE(NEW.payment_method, ''))) = 'cash' THEN
        v_is_cash_payment := TRUE;
    END IF;
    
    -- Determine when to schedule payments:
    -- 1. For cash-on-delivery: Schedule immediately when payment_method is set (no certificate needed)
    -- 2. For other payments: Schedule when certificate is generated (existing logic)
    
    IF v_is_cash_payment THEN
        -- For cash payments: Schedule when payment method is set or updated
        IF (OLD.payment_method IS NULL OR OLD.payment_method = '') AND NEW.payment_method IS NOT NULL
           OR (OLD.payment_method != NEW.payment_method AND NEW.payment_method IS NOT NULL) THEN
            v_should_schedule := TRUE;
            RAISE NOTICE 'Cash-on-delivery payment detected, scheduling immediately for receiving record: %', NEW.id;
        END IF;
    ELSE
        -- For non-cash payments: Original logic - schedule when certificate is generated
        IF (OLD.certificate_url IS NULL AND NEW.certificate_url IS NOT NULL)
           OR (OLD.certificate_generated_at IS NULL AND NEW.certificate_generated_at IS NOT NULL)
           OR (NEW.certificate_generated_at IS NOT NULL AND NEW.certificate_generated_at != OLD.certificate_generated_at) THEN
            v_should_schedule := TRUE;
            RAISE NOTICE 'Certificate generated, scheduling payment for receiving record: %', NEW.id;
        END IF;
    END IF;
    
    -- Schedule the payment if conditions are met
    IF v_should_schedule THEN
        -- Only auto-schedule if:
        -- 1. Payment method is set
        -- 2. Due date is set (or can be calculated)
        -- 3. Bill amount is greater than 0
        -- 4. Not already scheduled
        IF NEW.payment_method IS NOT NULL 
           AND (NEW.due_date IS NOT NULL OR NEW.bill_date IS NOT NULL) -- Due date or bill date must exist
           AND NEW.bill_amount > 0 
           AND NOT EXISTS (
               SELECT 1 FROM vendor_payment_schedule 
               WHERE receiving_record_id = NEW.id
           ) THEN
            
            -- Calculate due date if not set (for cash payments, use bill_date + credit_period or bill_date)
            DECLARE
                v_calculated_due_date DATE;
            BEGIN
                v_calculated_due_date := COALESCE(
                    NEW.due_date,
                    CASE 
                        WHEN v_is_cash_payment THEN NEW.bill_date -- Cash payments due immediately
                        WHEN NEW.credit_period IS NOT NULL THEN NEW.bill_date + INTERVAL '1 day' * NEW.credit_period
                        ELSE NEW.bill_date + INTERVAL '30 days' -- Default 30 days
                    END
                );
            END;
            
            -- Insert into payment schedule
            INSERT INTO vendor_payment_schedule (
                receiving_record_id,
                bill_number,
                vendor_id,
                vendor_name,
                branch_id,
                branch_name,
                bill_date,
                bill_amount,
                final_bill_amount,
                payment_method,
                bank_name,
                iban,
                due_date,
                original_due_date,
                original_bill_amount,
                original_final_amount,
                credit_period,
                vat_number,
                payment_status,
                scheduled_date,
                notes,
                is_paid
            )
            SELECT 
                NEW.id,
                NEW.bill_number,
                NEW.vendor_id,
                COALESCE(v.vendor_name, NEW.vendor_name, 'Unknown Vendor'),
                NEW.branch_id,
                COALESCE(b.name_en, 'Unknown Branch'),
                NEW.bill_date,
                NEW.bill_amount,
                COALESCE(NEW.final_bill_amount, NEW.bill_amount),
                NEW.payment_method,
                NEW.bank_name,
                NEW.iban,
                v_calculated_due_date,
                v_calculated_due_date, -- Store original due date same as current due date initially
                NEW.bill_amount, -- Store original bill amount
                COALESCE(NEW.final_bill_amount, NEW.bill_amount), -- Store original final amount
                NEW.credit_period,
                NEW.vendor_vat_number,
                'scheduled',
                NOW(),
                CASE 
                    WHEN v_is_cash_payment THEN 'Auto-scheduled cash-on-delivery payment when receiving record updated'
                    ELSE 'Auto-scheduled when certificate was generated in receiving process'
                END,
                FALSE -- Start as unpaid, let the payment automation trigger handle marking as paid
            FROM branches b
            LEFT JOIN vendors v ON v.erp_vendor_id = NEW.vendor_id AND v.branch_id = NEW.branch_id
            WHERE b.id = NEW.branch_id;
            
            RAISE NOTICE 'Payment scheduled successfully for receiving record: %, Payment method: %, Cash payment: %', 
                NEW.id, NEW.payment_method, v_is_cash_payment;
            
        ELSE
            RAISE WARNING 'Payment not scheduled for receiving record %. Reasons: payment_method=%, due_date=%, bill_date=%, bill_amount=%, already_exists=%', 
                NEW.id, NEW.payment_method, NEW.due_date, NEW.bill_date, NEW.bill_amount,
                EXISTS(SELECT 1 FROM vendor_payment_schedule WHERE receiving_record_id = NEW.id);
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate the trigger
DROP TRIGGER IF EXISTS auto_schedule_payment_on_certificate_trigger ON receiving_records;

CREATE TRIGGER auto_schedule_payment_on_certificate_trigger
    AFTER UPDATE ON receiving_records
    FOR EACH ROW
    EXECUTE FUNCTION auto_schedule_payment_on_certificate_generation();

-- Also create a trigger for INSERT to handle new receiving records with cash-on-delivery
CREATE TRIGGER auto_schedule_payment_on_insert_trigger
    AFTER INSERT ON receiving_records
    FOR EACH ROW
    EXECUTE FUNCTION auto_schedule_payment_on_certificate_generation();

-- Add enhanced comments
COMMENT ON FUNCTION auto_schedule_payment_on_certificate_generation() IS 'Enhanced auto-scheduling: Schedules cash-on-delivery payments immediately when payment method is set, other payments when certificate is generated';
COMMENT ON TRIGGER auto_schedule_payment_on_certificate_trigger ON receiving_records IS 'Triggers payment scheduling on receiving record updates - handles both cash and regular payments';
COMMENT ON TRIGGER auto_schedule_payment_on_insert_trigger ON receiving_records IS 'Triggers payment scheduling on new receiving records - handles cash-on-delivery payments immediately';

COMMIT;