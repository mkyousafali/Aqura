-- Migration: Remove redundant payment_status column
-- Description: Remove payment_status column from vendor_payment_schedule as is_paid boolean is sufficient

-- Step 1: Sync any remaining payment_status='paid' to is_paid=true before removal
UPDATE vendor_payment_schedule
SET is_paid = true
WHERE LOWER(payment_status) = 'paid' AND (is_paid IS NULL OR is_paid = false);

-- Step 2: Log pre-removal statistics
DO $$
DECLARE
    total_records INTEGER;
    paid_by_status INTEGER;
    paid_by_flag INTEGER;
    mismatched INTEGER;
BEGIN
    -- Count total records
    SELECT COUNT(*) INTO total_records FROM vendor_payment_schedule;
    
    -- Count paid by payment_status
    SELECT COUNT(*) INTO paid_by_status 
    FROM vendor_payment_schedule 
    WHERE LOWER(payment_status) = 'paid';
    
    -- Count paid by is_paid flag
    SELECT COUNT(*) INTO paid_by_flag 
    FROM vendor_payment_schedule 
    WHERE is_paid = true;
    
    -- Count mismatched records (should be 0 after sync)
    SELECT COUNT(*) INTO mismatched 
    FROM vendor_payment_schedule 
    WHERE (LOWER(payment_status) = 'paid' AND is_paid != true) 
       OR (is_paid = true AND LOWER(payment_status) != 'paid');
    
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '📊 Pre-removal Statistics:';
    RAISE NOTICE '   Total records: %', total_records;
    RAISE NOTICE '   Paid by payment_status: %', paid_by_status;
    RAISE NOTICE '   Paid by is_paid flag: %', paid_by_flag;
    RAISE NOTICE '   Mismatched records: %', mismatched;
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
END $$;

-- Step 3: Remove payment_status column
ALTER TABLE vendor_payment_schedule DROP COLUMN IF EXISTS payment_status;

-- Step 4: Add index on is_paid for better query performance
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_is_paid ON vendor_payment_schedule(is_paid);

-- Step 5: Add comment to document is_paid column
COMMENT ON COLUMN vendor_payment_schedule.is_paid IS 'Boolean flag indicating if payment has been completed (true=paid, false/null=not paid)';

-- Step 6: Log completion
DO $$
BEGIN
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '✅ Payment Status Column Removal Completed';
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '📊 payment_status column has been removed';
    RAISE NOTICE '📝 Using is_paid boolean column exclusively';
    RAISE NOTICE '   • is_paid = true  → Payment completed';
    RAISE NOTICE '   • is_paid = false or NULL → Payment scheduled/pending';
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE 'ℹ️  Update application code to use is_paid instead of payment_status';
    RAISE NOTICE 'ℹ️  All queries should filter by: .eq(''is_paid'', true)';
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
END $$;
