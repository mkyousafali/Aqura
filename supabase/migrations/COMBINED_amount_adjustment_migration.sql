-- Combined Migration Script for Amount Adjustment Feature
-- Run this in Supabase SQL Editor
-- Date: 2025-10-29

-- STEP 1: Drop existing foreign key constraint if it exists
ALTER TABLE vendor_payment_schedule
DROP CONSTRAINT IF EXISTS vendor_payment_schedule_last_adjusted_by_fkey;

-- Drop unique constraint on receiving_record_id to allow split payments
ALTER TABLE vendor_payment_schedule
DROP CONSTRAINT IF EXISTS vendor_payment_schedule_receiving_record_id_unique;

-- STEP 2: Add columns for tracking discount adjustments (if not exists)
ALTER TABLE vendor_payment_schedule
ADD COLUMN IF NOT EXISTS discount_amount DECIMAL(15, 2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS discount_notes TEXT;

-- STEP 3: Add columns for GRR (Goods Receipt Return) adjustments
ALTER TABLE vendor_payment_schedule
ADD COLUMN IF NOT EXISTS grr_amount DECIMAL(15, 2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS grr_reference_number TEXT,
ADD COLUMN IF NOT EXISTS grr_notes TEXT;

-- STEP 4: Add columns for PRI (Purchase Return Invoice) adjustments
ALTER TABLE vendor_payment_schedule
ADD COLUMN IF NOT EXISTS pri_amount DECIMAL(15, 2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS pri_reference_number TEXT,
ADD COLUMN IF NOT EXISTS pri_notes TEXT;

-- STEP 5: Add tracking columns for adjustment metadata
ALTER TABLE vendor_payment_schedule
ADD COLUMN IF NOT EXISTS last_adjustment_date TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS last_adjusted_by UUID,
ADD COLUMN IF NOT EXISTS adjustment_history JSONB DEFAULT '[]'::jsonb;

-- STEP 6: Add comments to document the columns
COMMENT ON COLUMN vendor_payment_schedule.discount_amount IS 'Discount amount deducted from bill';
COMMENT ON COLUMN vendor_payment_schedule.discount_notes IS 'Notes explaining the discount';
COMMENT ON COLUMN vendor_payment_schedule.grr_amount IS 'Goods Receipt Return amount deducted from bill';
COMMENT ON COLUMN vendor_payment_schedule.grr_reference_number IS 'Reference number for GRR document';
COMMENT ON COLUMN vendor_payment_schedule.grr_notes IS 'Notes for GRR adjustment';
COMMENT ON COLUMN vendor_payment_schedule.pri_amount IS 'Purchase Return Invoice amount deducted from bill';
COMMENT ON COLUMN vendor_payment_schedule.pri_reference_number IS 'Reference number for PRI document';
COMMENT ON COLUMN vendor_payment_schedule.pri_notes IS 'Notes for PRI adjustment';
COMMENT ON COLUMN vendor_payment_schedule.last_adjustment_date IS 'Date of last adjustment';
COMMENT ON COLUMN vendor_payment_schedule.last_adjusted_by IS 'User ID who made the last adjustment (stores auth.users.id without FK constraint)';
COMMENT ON COLUMN vendor_payment_schedule.adjustment_history IS 'JSON array of all adjustment history';

-- STEP 7: Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_adjustments 
ON vendor_payment_schedule(last_adjustment_date) 
WHERE last_adjustment_date IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_grr_ref 
ON vendor_payment_schedule(grr_reference_number) 
WHERE grr_reference_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_pri_ref 
ON vendor_payment_schedule(pri_reference_number) 
WHERE pri_reference_number IS NOT NULL;

-- STEP 8: Add constraints to ensure amounts are non-negative
ALTER TABLE vendor_payment_schedule
DROP CONSTRAINT IF EXISTS check_discount_amount_positive;

ALTER TABLE vendor_payment_schedule
ADD CONSTRAINT check_discount_amount_positive 
CHECK (discount_amount >= 0);

ALTER TABLE vendor_payment_schedule
DROP CONSTRAINT IF EXISTS check_grr_amount_positive;

ALTER TABLE vendor_payment_schedule
ADD CONSTRAINT check_grr_amount_positive 
CHECK (grr_amount >= 0);

ALTER TABLE vendor_payment_schedule
DROP CONSTRAINT IF EXISTS check_pri_amount_positive;

ALTER TABLE vendor_payment_schedule
ADD CONSTRAINT check_pri_amount_positive 
CHECK (pri_amount >= 0);

-- STEP 9: Add constraint to ensure total deductions don't exceed bill amount
ALTER TABLE vendor_payment_schedule
DROP CONSTRAINT IF EXISTS check_total_deductions_valid;

ALTER TABLE vendor_payment_schedule
ADD CONSTRAINT check_total_deductions_valid 
CHECK (
  (COALESCE(discount_amount, 0) + COALESCE(grr_amount, 0) + COALESCE(pri_amount, 0)) <= COALESCE(original_final_amount, final_bill_amount, bill_amount)
);

-- STEP 10: Create function to automatically update final_bill_amount
-- This deducts from the original_final_amount (or final_bill_amount if original is null)
CREATE OR REPLACE FUNCTION update_final_bill_amount_on_adjustment()
RETURNS TRIGGER AS $$
BEGIN
  -- Only recalculate if there are actual adjustments (discount, GRR, or PRI)
  -- This prevents the trigger from interfering with split payments
  IF (COALESCE(NEW.discount_amount, 0) > 0 OR 
      COALESCE(NEW.grr_amount, 0) > 0 OR 
      COALESCE(NEW.pri_amount, 0) > 0) THEN
    
    DECLARE
      base_amount DECIMAL(15, 2);
    BEGIN
      -- Determine the base amount to deduct from
      base_amount := COALESCE(NEW.original_final_amount, NEW.bill_amount);
      
      -- Calculate new final_bill_amount by deducting discount, GRR, and PRI amounts
      NEW.final_bill_amount := base_amount - 
        COALESCE(NEW.discount_amount, 0) - 
        COALESCE(NEW.grr_amount, 0) - 
        COALESCE(NEW.pri_amount, 0);
    END;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- STEP 11: Create trigger to auto-update final_bill_amount
DROP TRIGGER IF EXISTS trg_update_final_bill_amount ON vendor_payment_schedule;
CREATE TRIGGER trg_update_final_bill_amount
  BEFORE INSERT OR UPDATE OF discount_amount, grr_amount, pri_amount, bill_amount
  ON vendor_payment_schedule
  FOR EACH ROW
  EXECUTE FUNCTION update_final_bill_amount_on_adjustment();

-- Migration completed successfully
-- The edit amount feature should now work without foreign key constraint errors
