-- Migration: Add amount adjustment tracking columns to vendor_payment_schedule
-- Created: 2025-10-29
-- Purpose: Track amount reductions due to discounts, GRR, or PRI

-- Add columns for tracking discount adjustments
ALTER TABLE vendor_payment_schedule
ADD COLUMN IF NOT EXISTS discount_amount DECIMAL(15, 2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS discount_notes TEXT;

-- Add columns for GRR (Goods Receipt Return) adjustments
ALTER TABLE vendor_payment_schedule
ADD COLUMN IF NOT EXISTS grr_amount DECIMAL(15, 2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS grr_reference_number TEXT,
ADD COLUMN IF NOT EXISTS grr_notes TEXT;

-- Add columns for PRI (Purchase Return Invoice) adjustments
ALTER TABLE vendor_payment_schedule
ADD COLUMN IF NOT EXISTS pri_amount DECIMAL(15, 2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS pri_reference_number TEXT,
ADD COLUMN IF NOT EXISTS pri_notes TEXT;

-- Add tracking columns for adjustment metadata
ALTER TABLE vendor_payment_schedule
ADD COLUMN IF NOT EXISTS last_adjustment_date TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS last_adjusted_by UUID,
ADD COLUMN IF NOT EXISTS adjustment_history JSONB DEFAULT '[]'::jsonb;

-- Add comment to document the columns
COMMENT ON COLUMN vendor_payment_schedule.discount_amount IS 'Discount amount deducted from bill';
COMMENT ON COLUMN vendor_payment_schedule.discount_notes IS 'Notes explaining the discount';
COMMENT ON COLUMN vendor_payment_schedule.grr_amount IS 'Goods Receipt Return amount deducted from bill';
COMMENT ON COLUMN vendor_payment_schedule.grr_reference_number IS 'Reference number for GRR document';
COMMENT ON COLUMN vendor_payment_schedule.grr_notes IS 'Notes for GRR adjustment';
COMMENT ON COLUMN vendor_payment_schedule.pri_amount IS 'Purchase Return Invoice amount deducted from bill';
COMMENT ON COLUMN vendor_payment_schedule.pri_reference_number IS 'Reference number for PRI document';
COMMENT ON COLUMN vendor_payment_schedule.pri_notes IS 'Notes for PRI adjustment';
COMMENT ON COLUMN vendor_payment_schedule.last_adjustment_date IS 'Date of last adjustment';
COMMENT ON COLUMN vendor_payment_schedule.last_adjusted_by IS 'User ID who made the last adjustment';
COMMENT ON COLUMN vendor_payment_schedule.adjustment_history IS 'JSON array of all adjustment history';

-- Create index for faster queries on adjusted payments
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_adjustments 
ON vendor_payment_schedule(last_adjustment_date) 
WHERE last_adjustment_date IS NOT NULL;

-- Create index for GRR reference numbers
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_grr_ref 
ON vendor_payment_schedule(grr_reference_number) 
WHERE grr_reference_number IS NOT NULL;

-- Create index for PRI reference numbers
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_pri_ref 
ON vendor_payment_schedule(pri_reference_number) 
WHERE pri_reference_number IS NOT NULL;

-- Add constraints to ensure amounts are non-negative
ALTER TABLE vendor_payment_schedule
ADD CONSTRAINT check_discount_amount_positive 
CHECK (discount_amount >= 0);

ALTER TABLE vendor_payment_schedule
ADD CONSTRAINT check_grr_amount_positive 
CHECK (grr_amount >= 0);

ALTER TABLE vendor_payment_schedule
ADD CONSTRAINT check_pri_amount_positive 
CHECK (pri_amount >= 0);

-- Add constraint to ensure total deductions don't exceed bill amount
ALTER TABLE vendor_payment_schedule
ADD CONSTRAINT check_total_deductions_valid 
CHECK (
  (COALESCE(discount_amount, 0) + COALESCE(grr_amount, 0) + COALESCE(pri_amount, 0)) <= bill_amount
);

-- Create a function to automatically update final_bill_amount when adjustments change
CREATE OR REPLACE FUNCTION update_final_bill_amount_on_adjustment()
RETURNS TRIGGER AS $$
BEGIN
  -- Calculate new final_bill_amount based on bill_amount minus all deductions
  NEW.final_bill_amount := NEW.bill_amount - 
    COALESCE(NEW.discount_amount, 0) - 
    COALESCE(NEW.grr_amount, 0) - 
    COALESCE(NEW.pri_amount, 0);
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to auto-update final_bill_amount
DROP TRIGGER IF EXISTS trg_update_final_bill_amount ON vendor_payment_schedule;
CREATE TRIGGER trg_update_final_bill_amount
  BEFORE INSERT OR UPDATE OF discount_amount, grr_amount, pri_amount, bill_amount
  ON vendor_payment_schedule
  FOR EACH ROW
  EXECUTE FUNCTION update_final_bill_amount_on_adjustment();
