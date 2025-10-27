-- Fix RLS Policies for expense_requisitions table
-- Run this in your Supabase SQL Editor

-- Drop existing policies if any (to avoid conflicts)
DROP POLICY IF EXISTS "Allow authenticated users to read expense requisitions" ON public.expense_requisitions;
DROP POLICY IF EXISTS "Allow authenticated users to create expense requisitions" ON public.expense_requisitions;
DROP POLICY IF EXISTS "Allow authenticated users to update expense requisitions" ON public.expense_requisitions;
DROP POLICY IF EXISTS "Service role has full access to expense requisitions" ON public.expense_requisitions;

-- Create RLS Policies for expense_requisitions

-- Policy: Allow authenticated users to read all requisitions
CREATE POLICY "Allow authenticated users to read expense requisitions"
ON public.expense_requisitions
FOR SELECT
TO authenticated
USING (true);

-- Policy: Allow authenticated users to insert requisitions
CREATE POLICY "Allow authenticated users to create expense requisitions"
ON public.expense_requisitions
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Policy: Allow authenticated users to update requisitions
CREATE POLICY "Allow authenticated users to update expense requisitions"
ON public.expense_requisitions
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- Policy: Allow service role full access
CREATE POLICY "Service role has full access to expense requisitions"
ON public.expense_requisitions
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Verify policies were created
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'expense_requisitions'
ORDER BY policyname;
