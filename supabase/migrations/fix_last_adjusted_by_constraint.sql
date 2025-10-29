-- Migration: Fix last_adjusted_by foreign key constraint
-- Created: 2025-10-29
-- Purpose: Remove foreign key constraint that references auth.users which may not be accessible

-- Drop the foreign key constraint if it exists
ALTER TABLE vendor_payment_schedule
DROP CONSTRAINT IF EXISTS vendor_payment_schedule_last_adjusted_by_fkey;

-- The column will remain as UUID without foreign key constraint
-- This allows us to store user IDs without requiring a direct foreign key to auth.users
COMMENT ON COLUMN vendor_payment_schedule.last_adjusted_by IS 'User ID who made the last adjustment (stores auth.users.id without FK constraint)';
