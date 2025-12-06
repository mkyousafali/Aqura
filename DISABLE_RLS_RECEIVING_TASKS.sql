-- Disable RLS on receiving_tasks table
-- This table is used to create tasks after receiving records are created

ALTER TABLE receiving_tasks DISABLE ROW LEVEL SECURITY;

-- Verify
SELECT tablename, rowsecurity FROM pg_tables 
WHERE tablename = 'receiving_tasks';
