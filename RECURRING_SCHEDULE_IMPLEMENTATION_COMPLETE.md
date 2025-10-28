# Recurring Schedule Implementation - Complete Solution

## Overview
This implementation creates ALL future occurrences immediately when a recurring schedule is created, allowing users to:
- See all scheduled payments upfront
- Cancel individual occurrences if needed
- Modify specific occurrences
- No dependency on cron jobs for creating occurrences
- Cron only sends reminder notifications 2 days before due dates

## Architecture

### 1. **Occurrence Generation (Immediate)**
**Function**: `generate_recurring_occurrences(p_parent_id, p_source_table)`
**File**: `supabase/migrations/075_create_generate_recurring_occurrences_function.sql`

**When it runs**: Immediately after creating a recurring schedule

**What it does**:
- Takes a recurring schedule ID and source table
- Generates ALL future occurrences based on recurring type
- Each occurrence is saved as `schedule_type='single_bill'`
- Links back to parent via `recurring_metadata->>'parent_schedule_id'`

**Supported recurring types**:
- `daily`: Every day until end date
- `weekly`: Specific weekday until end date
- `monthly_date`: Start/middle/end of month until end month
- `monthly_day`: Specific day of month until end month
- `custom`: Specific custom dates array
- (yearly, half_yearly, quarterly can be added similarly)

**Example**: 
- Create daily schedule from Oct 28 to Oct 31
- Function immediately creates 4 separate entries:
  - Oct 28 (single_bill)
  - Oct 29 (single_bill)
  - Oct 30 (single_bill)
  - Oct 31 (single_bill)
- Each can be approved/rejected/cancelled independently

---

### 2. **Reminder Notifications (Cron)**
**Function**: `check_and_notify_recurring_schedules()`
**File**: `supabase/migrations/073_create_recurring_schedule_notification_function.sql` (updated)

**When it runs**: Daily via cron job

**What it does**:
- Finds all `single_bill` occurrences that are 2 days away
- Only for occurrences linked to recurring schedules (has `parent_schedule_id`)
- Checks if notification already sent (prevents duplicates)
- Sends reminder notification to approver/user

**Example**:
- Oct 28: Cron runs, finds Oct 30 occurrence, sends reminder
- Oct 29: Cron runs, finds Oct 31 occurrence, sends reminder

---

### 3. **Frontend Integration**
**File**: `frontend/src/lib/components/admin/finance/RecurringExpenseScheduler.svelte`

**Changes made**:
1. After saving to `expense_scheduler`:
   ```javascript
   await supabaseAdmin.rpc('generate_recurring_occurrences', {
       p_parent_id: data.id,
       p_source_table: 'expense_scheduler'
   });
   ```

2. After saving to `non_approved_payment_scheduler`:
   ```javascript
   await supabaseAdmin.rpc('generate_recurring_occurrences', {
       p_parent_id: data.id,
       p_source_table: 'non_approved_payment_scheduler'
   });
   ```

3. Success messages now show occurrence count

---

## Database Schema

### Parent Schedule Record
```sql
-- Example: non_approved_payment_scheduler
{
    id: 6,
    schedule_type: 'recurring',
    recurring_type: 'daily',
    recurring_metadata: {
        until_date: '2025-10-31'
    },
    approval_status: 'pending',
    ...
}
```

### Generated Occurrence Records
```sql
-- Example: Occurrences created immediately
{
    id: 101,
    schedule_type: 'single_bill', -- NOT recurring!
    due_date: '2025-10-30',
    recurring_metadata: {
        parent_schedule_id: 6,
        occurrence_date: '2025-10-30',
        recurring_type: 'daily'
    },
    approval_status: 'pending',
    ...
}

{
    id: 102,
    schedule_type: 'single_bill',
    due_date: '2025-10-31',
    recurring_metadata: {
        parent_schedule_id: 6,
        occurrence_date: '2025-10-31',
        recurring_type: 'daily'
    },
    approval_status: 'pending',
    ...
}
```

---

## Installation Steps

### 1. Apply Migration 075 (Generate Occurrences Function)
```sql
-- Run in Supabase SQL Editor
-- File: supabase/migrations/075_create_generate_recurring_occurrences_function.sql
-- This creates the generate_recurring_occurrences() function
```

### 2. Apply Updated Migration 073 (Reminder Function)
```sql
-- Run in Supabase SQL Editor
-- File: supabase/migrations/073_create_recurring_schedule_notification_function.sql
-- This updates the notification function to only send reminders
```

### 3. Frontend is Already Updated
The `RecurringExpenseScheduler.svelte` component now calls the function automatically.

### 4. Test the Implementation
```sql
-- Create a test recurring schedule (will be done via UI)
-- Then query to see occurrences:

SELECT 
    id,
    schedule_type,
    due_date,
    amount,
    approval_status,
    recurring_metadata->>'parent_schedule_id' as parent_id,
    recurring_metadata->>'occurrence_date' as occurrence_date
FROM non_approved_payment_scheduler
WHERE recurring_metadata->>'parent_schedule_id' = '6' -- Your parent schedule ID
ORDER BY due_date;
```

---

## User Experience Flow

### Creating a Recurring Schedule:

1. **User selects**: Daily schedule until Oct 31, 2025
2. **User clicks**: Submit
3. **System creates**:
   - 1 parent record (schedule_type='recurring')
   - N occurrence records (schedule_type='single_bill', one for each day)
4. **User sees**: "✅ Generated 4 occurrences"
5. **Approver gets**: Notification about recurring schedule approval request
6. **Approval center shows**: All 4 individual occurrences, each with approve/reject buttons

### Managing Occurrences:

- **Cancel specific day**: Reject that single occurrence
- **Modify amount**: Update that specific occurrence
- **See all occurrences**: Query by parent_schedule_id
- **Cancel entire schedule**: Reject parent + all pending occurrences

### Reminder System:

- **2 days before**: Approver/user gets reminder notification
- **1 day before**: (Could add another notification if needed)
- **Day of**: Payment should be processed

---

## Benefits of This Approach

✅ **Immediate visibility**: All occurrences created upfront
✅ **Individual control**: Cancel/modify any specific occurrence
✅ **No cron dependency**: Occurrences exist immediately
✅ **Better UX**: Users can see exactly what's scheduled
✅ **Flexible management**: Each occurrence is independent
✅ **Audit trail**: Clear parent-child relationship via metadata
✅ **Reminder system**: Cron only for notifications (simpler)

---

## Testing Checklist

- [ ] Create daily recurring schedule → Verify all days created
- [ ] Create weekly recurring schedule → Verify correct weekdays created
- [ ] Create monthly recurring schedule → Verify correct dates created
- [ ] Create custom dates schedule → Verify only selected dates created
- [ ] Check occurrence count in success message
- [ ] View occurrences in approval center
- [ ] Approve/reject individual occurrence
- [ ] Cancel parent schedule
- [ ] Verify reminders sent 2 days before (via cron)
- [ ] Verify no duplicate notifications

---

## Migration Files

1. **075_create_generate_recurring_occurrences_function.sql** ← NEW
   - Creates `generate_recurring_occurrences()` function
   - Handles all recurring types
   - Generates occurrences immediately

2. **073_create_recurring_schedule_notification_function.sql** ← UPDATED
   - Now only sends reminder notifications
   - Does NOT create occurrences anymore
   - Runs daily via cron

3. **074_setup_recurring_schedule_cron_job.sql**
   - Sets up logging infrastructure
   - Still needed for reminder system

---

## Next Steps

1. ✅ Apply migration 075 first
2. ✅ Apply updated migration 073
3. ✅ Test creating a daily recurring schedule
4. ✅ Verify occurrences in database
5. ✅ Check approval center shows all occurrences
6. Set up cron job for reminders (GitHub Actions or Supabase cron)

---

## Date: October 28, 2025
## Status: Ready for Testing
