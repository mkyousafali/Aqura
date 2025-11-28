-- ============================================
-- ADD UNIQUE CONSTRAINT TO hr_fingerprint_transactions
-- ============================================
-- 
-- PURPOSE: Prevent duplicate attendance records
-- 
-- WHAT THIS DOES:
-- Creates a rule that says "You cannot have two records with the 
-- exact same employee_id, date, time, status, and branch_id"
-- 
-- EXAMPLE:
-- ❌ REJECTED: Employee 29 | 2025-11-28 | 20:27:24 | Check Out | Branch 3 (if already exists)
-- ✅ ACCEPTED: Employee 29 | 2025-11-28 | 20:28:00 | Check Out | Branch 3 (different time)
-- 
-- IMPORTANT: You MUST delete all duplicates FIRST before running this!
-- Run: node delete-duplicate-transactions.mjs
-- 
-- HOW TO RUN THIS:
-- 1. Go to Supabase Dashboard → SQL Editor
-- 2. Click "New Query"
-- 3. Copy and paste this entire file
-- 4. Click "Run" button
-- ============================================

-- Add the unique constraint
ALTER TABLE hr_fingerprint_transactions 
ADD CONSTRAINT unique_fingerprint_transaction 
UNIQUE (employee_id, date, time, status, branch_id);

-- Verify the constraint was added
SELECT
    conname AS constraint_name,
    conrelid::regclass AS table_name,
    pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = 'hr_fingerprint_transactions'::regclass
  AND conname = 'unique_fingerprint_transaction';

-- Done! The constraint is now active.
-- Any attempt to insert duplicate records will be automatically rejected.
