-- =====================================================
-- Fix for Warning Template Double-Save Issue
-- Frontend component fix to prevent duplicate database saves
-- =====================================================

/*
ISSUE IDENTIFIED:
The WarningTemplate.svelte component is calling saveWarningRecord() multiple times:
1. Line 249: await saveWarningRecord(); (in sendInternalNotification)
2. Line 391: await saveWarningRecord(); (in saveWarningOnly)  
3. Line 409: saveWarningRecord().then(() => { (in sendToWhatsApp)
4. Line 452: saveWarningRecord().then(() => { (in printTemplate)

SOLUTION:
1. Add a "saved" flag to prevent multiple saves of the same warning
2. Modify the unique constraint to be less restrictive
3. Add proper error handling for duplicate attempts

FRONTEND CHANGES NEEDED:
In WarningTemplate.svelte, add a variable:
let warningSaved = false;

Then modify saveWarningRecord() function to check this flag:
async function saveWarningRecord() {
    if (warningSaved) {
        console.log('Warning already saved, skipping duplicate save');
        return;
    }
    
    try {
        // existing save logic...
        warningSaved = true; // Set flag after successful save
    } catch (err) {
        // handle error but don't set flag if save failed
    }
}

DATABASE CHANGES IMPLEMENTED:
1. Changed unique constraint from content-based to hourly-based
2. Added missing fine_paid_at column for frontend compatibility
3. Added column sync trigger

*/

-- =====================================================
-- Summary of all fixes applied:
-- =====================================================

-- 1. Fixed permission issue by avoiding system trigger disables
-- 2. Cleared all warning data for clean start
-- 3. Recreated triggers with better logic
-- 4. Changed unique constraint to hourly-based (prevents rapid duplicates)
-- 5. Added missing fine_paid_at column for frontend compatibility

-- Current state verification:
SELECT 'Database is ready for warning system' as status;

-- Check triggers are in place:
SELECT 
    'Triggers: ' || string_agg(trigger_name, ', ') as trigger_status
FROM information_schema.triggers 
WHERE event_object_table = 'employee_warnings';

-- Check columns exist:
SELECT 
    'Columns: ' || string_agg(column_name, ', ') as column_status
FROM information_schema.columns 
WHERE table_name = 'employee_warnings' 
  AND column_name IN ('fine_paid_date', 'fine_paid_at', 'warning_text', 'issued_at');

-- Check unique constraint:
SELECT 
    'Indexes: ' || string_agg(indexname, ', ') as index_status
FROM pg_indexes 
WHERE tablename = 'employee_warnings'
  AND indexname LIKE '%unique%';

-- Ready for testing - create a warning and verify no duplicates!