# Recurring Expense Scheduler Implementation
**Date:** 2025-01-29

## Overview
Implemented a comprehensive recurring expense scheduler system that allows scheduling recurring expenses with various frequency options.

## Database Changes

### Migration 070: Add Recurring Fields to expense_scheduler Table

**File:** `supabase/migrations/070_add_recurring_fields_to_expense_scheduler.sql`

**New Columns:**
1. **schedule_type** (TEXT, default: 'single_bill')
   - Identifies the source/type of schedule
   - Values: `'single_bill'`, `'multiple_bill'`, `'recurring'`
   - Helps distinguish between different scheduling methods

2. **recurring_type** (TEXT)
   - Type of recurring schedule
   - Values: `'daily'`, `'weekly'`, `'monthly_date'`, `'monthly_day'`, `'yearly'`, `'half_yearly'`, `'quarterly'`, `'custom'`
   - Only populated when schedule_type = 'recurring'

3. **recurring_metadata** (JSONB)
   - Stores type-specific recurring schedule details
   - Structure varies based on recurring_type:
     ```json
     {
       "until_date": "2025-12-31",        // For daily, weekly
       "weekday": 1,                       // For weekly (0-6)
       "month_position": "start",          // For monthly_date (start/middle/end)
       "until_month": "2025-12",           // For monthly options
       "day_of_month": 15,                 // For monthly_day (1-31)
       "recurring_month": 6,               // For yearly/half-yearly/quarterly (1-12)
       "recurring_day": 15,                // For yearly/half-yearly/quarterly (1-31)
       "until_year": 2026,                 // For yearly/half-yearly/quarterly
       "custom_dates": ["2025-01-15", ...] // For custom dates
     }
     ```

**Modified Columns:**
- **co_user_id**: Changed from NOT NULL to nullable
- **co_user_name**: Changed from NOT NULL to nullable
- Rationale: Recurring schedules don't require a C/O user

**Constraints Added:**
1. `check_schedule_type_values`: Ensures schedule_type is valid
2. `check_co_user_for_non_recurring`: Ensures C/O user fields are provided for single_bill and multiple_bill schedules
3. `check_recurring_type_values`: Ensures recurring_type is valid when schedule_type is 'recurring'

**Indexes Created:**
- `idx_expense_scheduler_schedule_type`
- `idx_expense_scheduler_recurring_type`

## Component Changes

### 1. RecurringExpenseScheduler.svelte (NEW)
**Path:** `frontend/src/lib/components/admin/finance/RecurringExpenseScheduler.svelte`

**Features:**
- 3-step wizard interface
  - Step 1: Branch & Category Selection
  - Step 2: Approved Request Selection (Optional)
  - Step 3: Payment Details & Recurring Schedule

**Payment Methods (Restricted):**
- Cash - نقدي
- Bank - بنكي

**Recurring Schedule Types:**

1. **Daily**
   - Until which date

2. **Weekly**
   - Weekday selection (Sunday-Saturday)
   - Until which date

3. **Specific Date of Every Month**
   - Month position (Start/Middle/End)
   - Until which month

4. **Specific Day of Every Month**
   - Day (1-31)
   - Until which month

5. **Yearly**
   - Which month (1-12)
   - Which date (1-31)
   - Until which year

6. **Half-Yearly**
   - Which month (1-12)
   - Which date (1-31)
   - Until which year

7. **Quarterly**
   - Which month (1-12)
   - Which date (1-31)
   - Until which year

8. **Custom Dates**
   - Calendar modal for selecting multiple dates
   - Add/remove individual dates

**Data Saved:**
- Sets `schedule_type = 'recurring'`
- Sets `co_user_id = null` and `co_user_name = null`
- Sets `bill_type = 'no_bill'`
- Stores all recurring details in `recurring_metadata` as JSONB

### 2. SingleBillScheduling.svelte (UPDATED)
**Changes:**
- Added `schedule_type: 'single_bill'` to saved data
- Identifies schedules created from single bill scheduling

### 3. MultipleBillScheduling.svelte (UPDATED)
**Changes:**
- Added `schedule_type: 'multiple_bill'` to saved data
- Identifies schedules created from multiple bill scheduling

### 4. Scheduler.svelte (UPDATED)
**Changes:**
- Renamed "Manual Expense Scheduler" to "Recurring Expense Scheduler"
- Updated button icon to 🔄
- Updated imports and component references

## Benefits

### 1. **Clear Schedule Type Tracking**
- Easy to identify where a schedule originated
- Can filter and display schedules by type
- Helps with reporting and analytics

### 2. **Flexible Recurring Options**
- Covers all common recurring patterns
- Custom dates option for irregular schedules
- Stores detailed metadata for each schedule type

### 3. **Database Design**
- Uses JSONB for flexible metadata storage
- Maintains referential integrity with existing tables
- Indexed for performance

### 4. **User Experience**
- Intuitive 3-step wizard
- Bilingual labels (English/Arabic)
- Clear validation messages
- Visual progress indicator

## Migration Steps

1. **Apply Migration:**
   ```sql
   -- Run migration 070
   psql -d your_database -f supabase/migrations/070_add_recurring_fields_to_expense_scheduler.sql
   ```

2. **Verify Changes:**
   ```sql
   -- Check new columns
   SELECT column_name, data_type, is_nullable 
   FROM information_schema.columns 
   WHERE table_name = 'expense_scheduler' 
   AND column_name IN ('schedule_type', 'recurring_type', 'recurring_metadata');

   -- Check constraints
   SELECT constraint_name, constraint_type 
   FROM information_schema.table_constraints 
   WHERE table_name = 'expense_scheduler';
   ```

3. **Test Scenarios:**
   - Create single bill schedule → Verify schedule_type = 'single_bill'
   - Create multiple bill schedule → Verify schedule_type = 'multiple_bill'
   - Create recurring schedule → Verify schedule_type = 'recurring' and recurring_metadata populated

## Future Enhancements

1. **Automatic Schedule Execution**
   - Background job to process recurring schedules
   - Create actual expense entries based on recurring rules

2. **Schedule Preview**
   - Show upcoming dates for recurring schedules
   - Allow editing/pausing of active recurring schedules

3. **Notifications**
   - Notify before recurring expense is due
   - Alert for failed recurring schedule processing

4. **Reporting**
   - Dashboard showing recurring expenses
   - Breakdown by schedule type
   - Cost analysis over time

## Notes

- All existing records automatically get `schedule_type = 'single_bill'` during migration
- C/O user is optional only for recurring schedules
- Recurring schedules always have `bill_type = 'no_bill'`
- Custom dates are stored as JSON array in recurring_metadata
