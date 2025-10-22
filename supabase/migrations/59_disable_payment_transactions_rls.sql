-- Disable RLS for payment_transactions table temporarily
-- Migration: 59_disable_payment_transactions_rls.sql

-- Disable RLS completely for payment_transactions table
ALTER TABLE payment_transactions DISABLE ROW LEVEL SECURITY;

-- Drop any existing policies that might be causing issues
DROP POLICY IF EXISTS "Users can view payment transactions" ON payment_transactions;
DROP POLICY IF EXISTS "Users can create payment transactions" ON payment_transactions;
DROP POLICY IF EXISTS "Authorized users can update payment transactions" ON payment_transactions;
DROP POLICY IF EXISTS "Enable read access for all users" ON payment_transactions;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON payment_transactions;
DROP POLICY IF EXISTS "Enable update for authenticated users only" ON payment_transactions;