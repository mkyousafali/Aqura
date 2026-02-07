-- Alter shelf_paper_fonts: change primary key from UUID to F1, F2, F3 format
-- and ensure original file name is preserved

-- Step 1: Drop existing primary key constraint
ALTER TABLE shelf_paper_fonts DROP CONSTRAINT shelf_paper_fonts_pkey;

-- Step 2: Drop the old UUID id column
ALTER TABLE shelf_paper_fonts DROP COLUMN id;

-- Step 3: Create a sequence for auto-incrementing
CREATE SEQUENCE IF NOT EXISTS shelf_paper_fonts_id_seq START WITH 1 INCREMENT BY 1;

-- Step 4: Add new id column with F1, F2, F3 format as primary key
ALTER TABLE shelf_paper_fonts ADD COLUMN id VARCHAR(20) PRIMARY KEY DEFAULT ('F' || nextval('shelf_paper_fonts_id_seq')::TEXT);

-- Step 5: Ensure original_file_name column exists (stores the exact uploaded file name)
ALTER TABLE shelf_paper_fonts ADD COLUMN IF NOT EXISTS original_file_name VARCHAR(500);

-- Grant sequence usage to all roles
GRANT USAGE, SELECT ON SEQUENCE shelf_paper_fonts_id_seq TO anon;
GRANT USAGE, SELECT ON SEQUENCE shelf_paper_fonts_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE shelf_paper_fonts_id_seq TO service_role;
