# How to Check Employee Punch Records

## Quick Reference Script

This script checks punch records from the `hr_fingerprint_transactions` table and converts Saudi time (GMT+3) to UTC (-3 hours).

### Script Location
`D:\Aqura\check-employee-punches.js`

### How to Run
```powershell
node check-employee-punches.js
```

## What It Does

1. **Shows table structure** - Displays all columns in the table
2. **Fetches punch records** - Gets all punches for a specific employee and branch
3. **Sorts chronologically** - Orders by `date` (descending) then `time` (descending)
4. **Converts timezone** - Subtracts 3 hours from Saudi time to get UTC
5. **Shows both formats** - Displays in 24-hour and 12-hour format

## Important Notes

### Table Columns
- `employee_id` - Employee ID (stored as TEXT, not INTEGER)
- `branch_id` - Branch ID (INTEGER)
- `date` - Date of punch (YYYY-MM-DD)
- `time` - Time of punch in Saudi time (HH:MM:SS)
- `status` - "Check In" or "Check Out"
- `device_id` - Biometric device ID
- `location` - Branch location name
- `created_at` - When record was synced to database (UTC timestamp)

### Key Points

1. **Use date + time columns ONLY**
   - Don't rely on `created_at` for chronological order
   - The `date` and `time` columns reflect actual punch time in Saudi timezone

2. **Saudi Time = GMT+3**
   - All times in the `time` column are in Saudi Arabia timezone
   - To convert to UTC: subtract 3 hours

3. **Sorting Order**
   - First sort by `date` (descending) - most recent date first
   - Then sort by `time` (descending) - latest time first
   - **Note**: This sorts by string, so 00:16 comes before 12:03 alphabetically

4. **Time Conversion Example**
   - Original: `2025-11-30 11:59:12` (Saudi time)
   - After -3 hours: `2025-11-30 08:59` (UTC)
   
   - Original: `2025-11-29 00:16:54` (Saudi time)
   - After -3 hours: `2025-11-28 21:16` (UTC, previous day!)

## Customize the Script

### Change Employee ID
```javascript
.eq('employee_id', '11')  // Change '11' to your employee ID
```

### Change Branch ID
```javascript
.eq('branch_id', 3)  // Change 3 to your branch ID
```

### Limit Results
```javascript
.limit(2)  // Add this line after .order() to get only last 2 records
```

### Filter by Date Range
```javascript
.gte('date', '2025-11-01')  // Greater than or equal to
.lte('date', '2025-11-30')  // Less than or equal to
```

## Example Output

```
📌 Record 1:
   Date: 2025-11-30
   Time (Original): 11:59:12
   Time (-3hrs): 8:59 (24hr) = 8:59 AM (12hr)
   Status: Check In

📌 Record 2:
   Date: 2025-11-29
   Time (Original): 00:16:54
   Time (-3hrs): 21:16 (24hr) = 9:16 PM (12hr)
   Status: Check Out
```

## Troubleshooting

### Error: "column does not exist"
- Check column names match exactly: `employee_id`, `branch_id`, `date`, `time`
- Use the table structure check at the beginning of the script

### No records found
- Verify employee ID exists in the table
- Check branch ID is correct
- Ensure employee has punch records for the specified filters

### Wrong timezone
- Verify you're subtracting 3 hours (not adding)
- Check that input time is in Saudi timezone (GMT+3)
- Remember: subtracting 3 hours from midnight (00:XX) goes to previous day

## Environment Variables

The script reads from `frontend/.env`:
- `PUBLIC_SUPABASE_URL` - Supabase project URL
- `SUPABASE_SERVICE_ROLE_KEY` - Service role key (full database access)

Make sure these are set correctly in your `.env` file.

## Integration with Mobile Interface

The mobile interface (`frontend/src/routes/mobile/+page.svelte`) now uses this same method to display punch records:

### How It Works in Mobile:

1. **Fetches employee_id** - Gets the varchar employee_id from `hr_employees` table using user's UUID
2. **Queries punch records** - Gets last 10 records from `hr_fingerprint_transactions`
3. **Sorts chronologically** - Orders by date + time (descending) 
4. **Takes latest 2** - Gets the most recent 2 punch records overall
5. **Converts timezone** - Subtracts 3 hours using proper Date object (handles date changes correctly)
6. **Displays in 12-hour format** - Shows time in 12-hour format with AM/PM

### Key Implementation:

```javascript
// Create proper datetime and subtract 3 hours
const saudiDateTime = new Date(`${record.date}T${record.time}`);
const utcDateTime = new Date(saudiDateTime.getTime() - (3 * 60 * 60 * 1000));

// Extract adjusted time
const hour24 = utcDateTime.getHours();
const minutes = utcDateTime.getMinutes();
const hour12 = hour24 % 12 || 12;
const ampm = hour24 >= 12 ? 'PM' : 'AM';
```

This ensures that:
- ✅ Date changes are handled correctly (e.g., 00:16 minus 3 hours = 21:16 previous day)
- ✅ Timezone conversion is accurate
- ✅ Mobile and desktop show consistent punch times
