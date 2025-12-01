# Employee Punch Check Logic

### Step 1: Fetch All Punch Records
```javascript
const { data, error } = await supabase
  .from('hr_fingerprint_transactions')
  .select('*')
  .eq('employee_id', employeeId);
```

**Why fetch all records?**
- Database ordering by separate `date` and `time` columns can be unreliable
- We need to combine date + time for accurate chronological sorting
- Ensures we get truly latest punches, not just latest date

### Step 2: Sort by Combined Date + Time
```javascript
const sortedData = data.sort((a, b) => {
  const dateTimeA = new Date(`${a.date}T${a.time}`);
  const dateTimeB = new Date(`${b.date}T${b.time}`);
  return dateTimeB - dateTimeA; // Descending (newest first)
}).slice(0, 2); // Take only latest 2
```

### Step 3: Convert Time to Saudi Timezone (UTC-3)
```javascript
const [hours, minutes, seconds] = punch.time.split(':').map(Number);
let saudiHours = hours - 3;
if (saudiHours < 0) saudiHours += 24;
```

### Step 4: Convert to 12-Hour Format
```javascript
const period = saudiHours >= 12 ? 'PM' : 'AM';
const displayHours = saudiHours % 12 || 12;
const time12hr = `${displayHours}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')} ${period}`;
```
