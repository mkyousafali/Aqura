-- Recreate auto-scheduling trigger for vendor_payment_schedule
-- This trigger automatically creates payment schedule when a certificate is generated

-- Step 1: Create the trigger function
CREATE OR REPLACE FUNCTION auto_create_payment_schedule()
RETURNS TRIGGER AS $$
DECLARE
    schedule_date TIMESTAMPTZ;
    existing_schedule_id UUID;
    v_vendor_name TEXT;
    v_branch_name TEXT;
    v_final_amount NUMERIC;
BEGIN
    -- Only proceed if certificate_url was updated (from NULL to a value)
    IF (TG_OP = 'UPDATE' AND OLD.certificate_url IS NULL AND NEW.certificate_url IS NOT NULL) OR
       (TG_OP = 'INSERT' AND NEW.certificate_url IS NOT NULL) THEN
        
        -- Check if payment schedule already exists
        SELECT id INTO existing_schedule_id
        FROM vendor_payment_schedule
        WHERE receiving_record_id = NEW.id
        LIMIT 1;
        
        -- Only create if it doesn't exist
        IF existing_schedule_id IS NULL THEN
            -- Get vendor name from vendors table
            SELECT vendor_name INTO v_vendor_name
            FROM vendors
            WHERE erp_vendor_id = NEW.vendor_id
            LIMIT 1;
            
            -- Get branch name from branches table
            SELECT name_en INTO v_branch_name
            FROM branches
            WHERE id = NEW.branch_id
            LIMIT 1;
            
            -- Calculate final bill amount (bill_amount - total returns)
            v_final_amount := NEW.bill_amount - 
                COALESCE(NEW.expired_return_amount, 0) -
                COALESCE(NEW.near_expiry_return_amount, 0) -
                COALESCE(NEW.over_stock_return_amount, 0) -
                COALESCE(NEW.damage_return_amount, 0);
            
            -- Calculate schedule date based on due date or credit period
            IF NEW.due_date IS NOT NULL THEN
                schedule_date := NEW.due_date;
            ELSIF NEW.credit_period IS NOT NULL THEN
                schedule_date := (NEW.created_at + (NEW.credit_period || ' days')::INTERVAL);
            ELSE
                schedule_date := (NEW.created_at + INTERVAL '30 days'); -- Default 30 days
            END IF;
            
            -- Insert into vendor_payment_schedule
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
                credit_period,
                vat_number,
                scheduled_date,
                is_paid,  -- Using is_paid instead of payment_status
                original_due_date,
                original_bill_amount,
                original_final_amount,
                receiver_user_id,
                created_at,
                updated_at
            ) VALUES (
                NEW.id,
                NEW.bill_number,
                NEW.vendor_id::text,  -- Cast integer to text
                v_vendor_name,
                NEW.branch_id,
                v_branch_name,
                NEW.bill_date,
                NEW.bill_amount,
                v_final_amount,
                NEW.payment_method,
                NEW.bank_name,
                NEW.iban,
                NEW.due_date,
                NEW.credit_period,
                NEW.vendor_vat_number,
                schedule_date,
                false,  -- Default to not paid
                NEW.due_date,
                NEW.bill_amount,
                v_final_amount,
                NEW.user_id,
                NOW(),
                NOW()
            );
            
            RAISE NOTICE 'Auto-created payment schedule for receiving record: % (certificate: %)', NEW.id, NEW.certificate_url;
        ELSE
            RAISE NOTICE 'Payment schedule already exists for receiving record: %', NEW.id;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 2: Drop old trigger and create new one
DROP TRIGGER IF EXISTS trigger_auto_create_payment_schedule ON receiving_records;

CREATE TRIGGER trigger_auto_create_payment_schedule
    AFTER INSERT OR UPDATE OF certificate_url ON receiving_records
    FOR EACH ROW
    EXECUTE FUNCTION auto_create_payment_schedule();

-- Step 3: Verification
DO $$
BEGIN
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '✅ Auto-Scheduling Trigger Created';
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '📋 Function: auto_create_payment_schedule()';
    RAISE NOTICE '📋 Trigger: trigger_auto_create_payment_schedule';
    RAISE NOTICE '📋 Table: receiving_records';
    RAISE NOTICE '📋 Event: AFTER INSERT OR UPDATE OF certificate_url';
    RAISE NOTICE '';
    RAISE NOTICE 'ℹ️  When certificate_url is added/updated:';
    RAISE NOTICE '   → Automatically creates vendor_payment_schedule entry';
    RAISE NOTICE '   → Sets is_paid = false (not paid)';
    RAISE NOTICE '   → Calculates scheduled_date from due_date or credit_period';
    RAISE NOTICE '   → Only creates if schedule doesn''t already exist';
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
END $$;

-- Step 4: Backfill missing payment schedules for existing receiving records
DO $$
DECLARE
    r RECORD;
    schedule_date TIMESTAMPTZ;
    v_vendor_name TEXT;
    v_branch_name TEXT;
    v_final_amount NUMERIC;
    inserted_count INTEGER := 0;
    skipped_count INTEGER := 0;
BEGIN
    RAISE NOTICE '🔄 Backfilling missing payment schedules...';
    
    FOR r IN (
        SELECT rr.*, v.vendor_name, b.name_en as branch_name
        FROM receiving_records rr
        LEFT JOIN vendor_payment_schedule vps ON vps.receiving_record_id = rr.id
        LEFT JOIN vendors v ON v.erp_vendor_id = rr.vendor_id
        LEFT JOIN branches b ON b.id = rr.branch_id
        WHERE vps.id IS NULL  -- Only records without payment schedule
    ) LOOP
        -- Calculate schedule date
        IF r.due_date IS NOT NULL THEN
            schedule_date := r.due_date;
        ELSIF r.credit_period IS NOT NULL THEN
            schedule_date := (r.created_at + (r.credit_period || ' days')::INTERVAL);
        ELSE
            schedule_date := (r.created_at + INTERVAL '30 days');
        END IF;
        
        -- Calculate final amount
        v_final_amount := r.bill_amount - 
            COALESCE(r.expired_return_amount, 0) -
            COALESCE(r.near_expiry_return_amount, 0) -
            COALESCE(r.over_stock_return_amount, 0) -
            COALESCE(r.damage_return_amount, 0);
        
        -- Insert payment schedule
        BEGIN
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
                credit_period,
                vat_number,
                scheduled_date,
                is_paid,
                original_due_date,
                original_bill_amount,
                original_final_amount,
                receiver_user_id,
                created_at,
                updated_at
            ) VALUES (
                r.id,
                r.bill_number,
                r.vendor_id::text,  -- Cast integer to text
                r.vendor_name,
                r.branch_id,
                r.branch_name,
                r.bill_date,
                r.bill_amount,
                v_final_amount,
                r.payment_method,
                r.bank_name,
                r.iban,
                r.due_date,
                r.credit_period,
                r.vendor_vat_number,
                schedule_date,
                false,
                r.due_date,
                r.bill_amount,
                v_final_amount,
                r.user_id,
                r.created_at,
                NOW()
            );
            
            inserted_count := inserted_count + 1;
        EXCEPTION WHEN OTHERS THEN
            skipped_count := skipped_count + 1;
            RAISE NOTICE 'Skipped record %: %', r.id, SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '✅ Backfill Complete';
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '📊 Inserted: % payment schedules', inserted_count;
    RAISE NOTICE '📊 Skipped: % records', skipped_count;
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
END $$;
