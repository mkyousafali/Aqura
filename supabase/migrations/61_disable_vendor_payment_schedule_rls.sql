-- Temporarily disable RLS for vendor_payment_schedule table to fix 406 errors
-- Migration: 61_disable_vendor_payment_schedule_rls.sql

-- Disable RLS completely for vendor_payment_schedule table
ALTER TABLE vendor_payment_schedule DISABLE ROW LEVEL SECURITY;

-- Drop any existing policies that might be causing issues
DROP POLICY IF EXISTS "Users can view vendor payment schedule" ON vendor_payment_schedule;
DROP POLICY IF EXISTS "Users can insert vendor payment schedule" ON vendor_payment_schedule;
DROP POLICY IF EXISTS "Users can update vendor payment schedule" ON vendor_payment_schedule;
DROP POLICY IF EXISTS "Users can delete vendor payment schedule" ON vendor_payment_schedule;