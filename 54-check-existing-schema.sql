-- Check Existing Database Schema
-- This will show us the actual structure of existing tables

-- 1. Check users table structure
SELECT 'USERS TABLE STRUCTURE:' as info;
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'users' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- 2. Check hr_employees table structure
SELECT 'HR_EMPLOYEES TABLE STRUCTURE:' as info;
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'hr_employees' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- 3. Check hr_departments table structure
SELECT 'HR_DEPARTMENTS TABLE STRUCTURE:' as info;
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'hr_departments' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- 4. Check hr_positions table structure
SELECT 'HR_POSITIONS TABLE STRUCTURE:' as info;
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'hr_positions' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- 5. Check branches table structure
SELECT 'BRANCHES TABLE STRUCTURE:' as info;
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'branches' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- 6. List all existing tables
SELECT 'ALL EXISTING TABLES:' as info;
SELECT tablename 
FROM pg_tables 
WHERE schemaname = 'public' 
ORDER BY tablename;

-- 7. Check if specific tables exist
SELECT 
    'Table exists check:' as info,
    table_name,
    CASE WHEN COUNT(*) > 0 THEN 'EXISTS' ELSE 'MISSING' END as status
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('users', 'hr_employees', 'hr_departments', 'hr_positions', 'branches')
GROUP BY table_name
ORDER BY table_name;