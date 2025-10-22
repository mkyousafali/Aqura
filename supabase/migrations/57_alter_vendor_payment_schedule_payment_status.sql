-- Add payment status fields to vendor_payment_schedule table
-- Migration: 57_alter_vendor_payment_schedule_payment_status.sql

-- Add new columns to track payment status
ALTER TABLE vendor_payment_schedule 
ADD COLUMN IF NOT EXISTS is_paid BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS payment_reference VARCHAR(255),
ADD COLUMN IF NOT EXISTS paid_date TIMESTAMPTZ;

-- Create index for faster queries on payment status
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_is_paid 
ON vendor_payment_schedule(is_paid);

-- Create index for paid date queries
CREATE INDEX IF NOT EXISTS idx_vendor_payment_schedule_paid_date 
ON vendor_payment_schedule(paid_date);

-- Add comment to document the new columns
COMMENT ON COLUMN vendor_payment_schedule.is_paid IS 'Boolean flag to indicate if payment has been marked as paid';
COMMENT ON COLUMN vendor_payment_schedule.payment_reference IS 'Reference number provided when marking payment as paid';
COMMENT ON COLUMN vendor_payment_schedule.paid_date IS 'Timestamp when payment was marked as paid';