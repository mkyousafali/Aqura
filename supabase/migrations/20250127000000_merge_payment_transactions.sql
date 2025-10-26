-- Migration: Merge payment_transactions into vendor_payment_schedule
-- Description: Remove payment_transactions table and migrate all data to vendor_payment_schedule

-- Step 1: Add new columns to vendor_payment_schedule for tracking tasks and transaction details
DO $$ 
BEGIN
    -- Add task tracking columns
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='vendor_payment_schedule' AND column_name='task_id') THEN
        ALTER TABLE vendor_payment_schedule ADD COLUMN task_id UUID REFERENCES tasks(id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='vendor_payment_schedule' AND column_name='task_assignment_id') THEN
        ALTER TABLE vendor_payment_schedule ADD COLUMN task_assignment_id UUID REFERENCES task_assignments(id);
    END IF;
    
    -- Add user tracking columns
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='vendor_payment_schedule' AND column_name='receiver_user_id') THEN
        ALTER TABLE vendor_payment_schedule ADD COLUMN receiver_user_id UUID;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='vendor_payment_schedule' AND column_name='accountant_user_id') THEN
        ALTER TABLE vendor_payment_schedule ADD COLUMN accountant_user_id UUID;
    END IF;
    
    -- Add verification columns
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='vendor_payment_schedule' AND column_name='verification_status') THEN
        ALTER TABLE vendor_payment_schedule ADD COLUMN verification_status TEXT DEFAULT 'pending';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='vendor_payment_schedule' AND column_name='verified_by') THEN
        ALTER TABLE vendor_payment_schedule ADD COLUMN verified_by UUID;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='vendor_payment_schedule' AND column_name='verified_date') THEN
        ALTER TABLE vendor_payment_schedule ADD COLUMN verified_date TIMESTAMP WITH TIME ZONE;
    END IF;
    
    -- Add transaction details column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='vendor_payment_schedule' AND column_name='transaction_date') THEN
        ALTER TABLE vendor_payment_schedule ADD COLUMN transaction_date TIMESTAMP WITH TIME ZONE;
    END IF;
    
    -- Add original bill URL if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='vendor_payment_schedule' AND column_name='original_bill_url') THEN
        ALTER TABLE vendor_payment_schedule ADD COLUMN original_bill_url TEXT;
    END IF;
    
    -- Add created_by if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='vendor_payment_schedule' AND column_name='created_by') THEN
        ALTER TABLE vendor_payment_schedule ADD COLUMN created_by UUID;
    END IF;
END $$;

-- Step 2: Migrate all data from payment_transactions to vendor_payment_schedule
UPDATE vendor_payment_schedule vps
SET 
    payment_reference = COALESCE(pt.reference_number, vps.payment_reference),
    task_id = COALESCE(pt.task_id, vps.task_id),
    task_assignment_id = COALESCE(pt.task_assignment_id, vps.task_assignment_id),
    receiver_user_id = COALESCE(pt.receiver_user_id, vps.receiver_user_id),
    accountant_user_id = COALESCE(pt.accountant_user_id, vps.accountant_user_id),
    verification_status = COALESCE(pt.verification_status, vps.verification_status, 'pending'),
    verified_by = COALESCE(pt.verified_by, vps.verified_by),
    verified_date = COALESCE(pt.verified_date, vps.verified_date),
    transaction_date = COALESCE(pt.transaction_date, vps.transaction_date, vps.paid_date),
    original_bill_url = COALESCE(pt.original_bill_url, vps.original_bill_url),
    created_by = COALESCE(pt.created_by, vps.created_by),
    updated_at = NOW()
FROM payment_transactions pt
WHERE vps.id = pt.payment_schedule_id;

-- Step 3: Log migration statistics
DO $$
DECLARE
    updated_count INTEGER;
    task_count INTEGER;
BEGIN
    -- Count how many records were updated
    SELECT COUNT(*) INTO updated_count
    FROM vendor_payment_schedule
    WHERE payment_reference IS NOT NULL AND payment_reference != '';
    
    -- Count how many have tasks
    SELECT COUNT(*) INTO task_count
    FROM vendor_payment_schedule
    WHERE task_id IS NOT NULL;
    
    RAISE NOTICE '✅ Migration completed: % payment references migrated', updated_count;
    RAISE NOTICE '✅ Task references migrated: % payments have tasks', task_count;
END $$;

-- Step 4: Drop payment_transactions table
-- First drop any foreign key constraints if they exist
ALTER TABLE IF EXISTS payment_transactions 
    DROP CONSTRAINT IF EXISTS payment_transactions_payment_schedule_id_fkey;

ALTER TABLE IF EXISTS payment_transactions 
    DROP CONSTRAINT IF EXISTS payment_transactions_receiving_record_id_fkey;

ALTER TABLE IF EXISTS payment_transactions 
    DROP CONSTRAINT IF EXISTS payment_transactions_task_id_fkey;

ALTER TABLE IF EXISTS payment_transactions 
    DROP CONSTRAINT IF EXISTS payment_transactions_task_assignment_id_fkey;

-- Drop the table
DROP TABLE IF EXISTS payment_transactions CASCADE;

-- Step 5: Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_task_id ON vendor_payment_schedule(task_id);
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_accountant_user_id ON vendor_payment_schedule(accountant_user_id);
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_verification_status ON vendor_payment_schedule(verification_status);

-- Step 6: Add comments to document the changes
COMMENT ON COLUMN vendor_payment_schedule.payment_reference IS 'Payment reference number (migrated from payment_transactions). Format: CP#XXXX or AUTO-COD-XXXXX';
COMMENT ON COLUMN vendor_payment_schedule.task_id IS 'Task created for accountant when payment is marked as paid';
COMMENT ON COLUMN vendor_payment_schedule.task_assignment_id IS 'Task assignment for the accountant';
COMMENT ON COLUMN vendor_payment_schedule.receiver_user_id IS 'User who received the goods (from receiving_records)';
COMMENT ON COLUMN vendor_payment_schedule.accountant_user_id IS 'Accountant assigned to process this payment';
COMMENT ON COLUMN vendor_payment_schedule.verification_status IS 'Payment verification status: pending, verified, rejected';
COMMENT ON COLUMN vendor_payment_schedule.verified_by IS 'User who verified the payment';
COMMENT ON COLUMN vendor_payment_schedule.verified_date IS 'Date when payment was verified';
COMMENT ON COLUMN vendor_payment_schedule.transaction_date IS 'Actual transaction/payment date';
COMMENT ON COLUMN vendor_payment_schedule.original_bill_url IS 'URL to the original bill/invoice document';
COMMENT ON COLUMN vendor_payment_schedule.is_paid IS 'Boolean flag indicating if payment has been completed (true=paid, false/null=scheduled)';

-- Step 9: Log completion
DO $$
BEGIN
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '✅ Migration completed successfully';
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '📊 payment_transactions table has been removed';
    RAISE NOTICE '� payment_status column has been removed (redundant with is_paid)';
    RAISE NOTICE '�📝 All data migrated to vendor_payment_schedule table:';
    RAISE NOTICE '   • payment_reference (reference numbers)';
    RAISE NOTICE '   • is_paid (boolean flag for payment completion)';
    RAISE NOTICE '   • task_id & task_assignment_id (task tracking)';
    RAISE NOTICE '   • receiver_user_id & accountant_user_id (user tracking)';
    RAISE NOTICE '   • verification_status, verified_by, verified_date';
    RAISE NOTICE '   • transaction_date & original_bill_url';
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE 'ℹ️  When a payment is marked as paid, set is_paid = true';
    RAISE NOTICE 'ℹ️  Create a task for the accountant';
    RAISE NOTICE 'ℹ️  Store task_id and task_assignment_id in vendor_payment_schedule';
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
END $$;
