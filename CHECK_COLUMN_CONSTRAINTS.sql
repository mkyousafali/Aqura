-- ============================================================================
-- CHECK COLUMN CONSTRAINTS
-- ============================================================================
-- See which columns are NOT NULL (required)
-- ============================================================================

SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'receiving_records'
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- ============================================================================
-- This will show:
-- - Which columns MUST have values (is_nullable = NO)
-- - Which columns can be NULL (is_nullable = YES)
-- - Default values for columns
--
-- Compare this with the data you're sending in receivingData object
-- ============================================================================
