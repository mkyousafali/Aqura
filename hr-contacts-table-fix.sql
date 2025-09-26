-- =====================================================
-- FIX HR EMPLOYEE CONTACTS TABLE - MATCH FRONTEND
-- Run this in Supabase to fix the contacts table structure
-- =====================================================

-- Step 1: Drop old columns and add new ones to match frontend
ALTER TABLE hr_employee_contacts 
    DROP COLUMN IF EXISTS contact_type,
    DROP COLUMN IF EXISTS contact_name,
    DROP COLUMN IF EXISTS phone,
    DROP COLUMN IF EXISTS relationship,
    ADD COLUMN whatsapp_number VARCHAR(20),
    ADD COLUMN contact_number VARCHAR(20);

-- Step 2: Drop the old constraint if it exists
ALTER TABLE hr_employee_contacts 
    DROP CONSTRAINT IF EXISTS chk_hr_contacts_type;

-- Step 3: Update table comment
COMMENT ON TABLE hr_employee_contacts IS 'HR Employee Contacts - Simple contact info matching Contact Management frontend: WhatsApp Number, Contact Number, Email';

-- Verification query to check the table structure
SELECT column_name, data_type, is_nullable, column_default 
FROM information_schema.columns 
WHERE table_name = 'hr_employee_contacts' 
AND table_schema = 'public'
ORDER BY ordinal_position;