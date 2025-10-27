-- Fix approver_id and created_by column types in expense_requisitions table
-- Run this in your Supabase SQL Editor

-- Change approver_id from BIGINT to UUID
ALTER TABLE public.expense_requisitions 
ALTER COLUMN approver_id TYPE UUID USING approver_id::TEXT::UUID;

-- Change created_by from TEXT to UUID
ALTER TABLE public.expense_requisitions 
ALTER COLUMN created_by TYPE UUID USING created_by::UUID;

-- Verify the column types
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'expense_requisitions'
AND column_name IN ('approver_id', 'created_by')
ORDER BY column_name;
