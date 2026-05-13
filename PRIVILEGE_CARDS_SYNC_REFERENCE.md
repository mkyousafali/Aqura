# erp-sync-app - Complete Sync Reference Guide

## 📋 Overview

**erp-sync-app** is an **Electron desktop application** (`D:\erp-sync-app`) that syncs data from **SQL Server ERP** to **Supabase cloud database**. It runs on a Windows PC and continuously syncs multiple data types every 5-60 minutes.

This document covers **ALL tables and sync mechanisms**.

---

## � All Tables Synced

The erp-sync-app syncs data to **FIVE main Supabase tables**:

| # | Source | Table | Sync Frequency | Size | Purpose |
|---|--------|-------|-----------------|------|---------|
| 1️⃣ | SQL Server: InvTransactionMaster | `erp_daily_sales` | Every 5 minutes | - | Daily sales summaries (SI/SR vouchers) |
| 2️⃣ | SQL Server: PrivilegeCards | `privilege_cards_master` | Every 60 minutes | Small | All unique card numbers (lookup) |
| 3️⃣ | SQL Server: PrivilegeCards + InvTransactionMaster | `privilege_cards_branch` | Every 60 minutes | **29 MB** | Card balances, holder names, redemptions |
| 4️⃣ | ZKBioTime: personnel_employee | `hr_employees` | Every 60 minutes | - | Employee records from biometric system |
| 5️⃣ | ZKBioTime: iclock_transaction | `hr_fingerprint_transactions` | Every 5 minutes | - | Punch clock records (check-in/out) |

---

## 🔄 Data Flow Architecture

```
┌─────────────────────────────────────────────────────────┐
│  SQL Server ERP (Primary Source)                        │
├─────────────────────────────────────────────────────────┤
│  ├─ InvTransactionMaster (Sales)                        │
│  ├─ PrivilegeCards (Loyalty Cards)                      │
│  └─ [Other master tables]                               │
└─────────────────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────────────────┐
│  ZKBioTime Server (Biometric System - Separate DB)     │
├─────────────────────────────────────────────────────────┤
│  ├─ personnel_employee (Employee list)                  │
│  └─ iclock_transaction (Punch records)                  │
└─────────────────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────────────────┐
│  erp-sync-app (Windows Desktop - D:\erp-sync-app)      │
├─────────────────────────────────────────────────────────┤
│  ✅ Electron Application (Node.js + mssql)             │
│  ✅ Connects to SQL Server + ZKBioTime                  │
│  ✅ Runs scheduled sync jobs (every 5/60 min)          │
│  ✅ Handles offline mode with retry queue              │
└─────────────────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────────────────┐
│  Supabase Cloud Database                                │
├─────────────────────────────────────────────────────────┤
│  ├─ erp_daily_sales (5min) ✅                          │
│  ├─ privilege_cards_master (60min) ✅                  │
│  ├─ privilege_cards_branch (60min) ✅ [29 MB]          │
│  ├─ hr_employees (60min) ✅                            │
│  ├─ hr_fingerprint_transactions (5min) ✅              │
│  ├─ erp_connections (config store)                     │
│  └─ biometric_connections (config store)               │
└─────────────────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────────────────┐
│  Aqura Frontend Application                             │
├─────────────────────────────────────────────────────────┤
│  ├─ Loyalty Page (reads privilege_cards_branch)        │
│  ├─ Dashboard (reads erp_daily_sales)                  │
│  ├─ HR System (reads hr_employees, hr_fingerprint)     │
│  └─ Reports & Analytics                                │
└─────────────────────────────────────────────────────────┘
```

---

## 🖥️ Key Component: erp-sync-app

**Location:** `D:\erp-sync-app\`  
**Type:** Electron desktop application  
**Language:** Node.js + mssql + @supabase/supabase-js  
**Purpose:** Bridges SQL Server ERP to Supabase cloud database

### Installation & Running

```bash
cd D:\erp-sync-app
npm install
npm start  # Development mode
npm run build  # Build Windows installer
```

The app:
- ✅ Runs as Windows service (auto-start on login)
- ✅ Connects to local SQL Server via configured IP & credentials
- ✅ Stores config in Supabase `erp_connections` table
- ✅ Syncs data to multiple Supabase tables (erp_daily_sales, hr_employees, privilege_cards_*)

---

---

# 🎯 SYNC TABLE 1: erp_daily_sales

**Source:** SQL Server `InvTransactionMaster` (Sales & Returns)  
**Frequency:** Every 5 minutes  
**Branch-specific:** YES (filtered by `erp_branch_id`)

## How It Works

The app queries sales data for **today and yesterday** every 5 minutes and upserts summary statistics.

**File:** [D:\erp-sync-app\main.js#L2050](file:///D:/erp-sync-app/main.js)

### SQL Query - Sales (SI = Sales Invoice)

```sql
SELECT 
  COALESCE(COUNT(*), 0) AS TotalBills,
  COALESCE(SUM(CAST([GrandTotal] AS DECIMAL(18,2))), 0) AS GrossAmount,
  COALESCE(SUM(CAST([VatAmount] AS DECIMAL(18,2))), 0) AS TaxAmount,
  COALESCE(SUM(CAST([TotalDiscount] AS DECIMAL(18,2))), 0) AS DiscountAmount
FROM [dbo].[InvTransactionMaster]
WHERE [VoucherType] = 'SI'
  AND [BranchId] = @branchId
  AND CAST([TransactionDate] AS DATE) = @date
```

### SQL Query - Returns (SR = Sales Return)

```sql
SELECT 
  COALESCE(COUNT(*), 0) AS TotalReturns,
  COALESCE(SUM(CAST([GrandTotal] AS DECIMAL(18,2))), 0) AS ReturnAmount,
  COALESCE(SUM(CAST([VatAmount] AS DECIMAL(18,2))), 0) AS ReturnTax
FROM [dbo].[InvTransactionMaster]
WHERE [VoucherType] = 'SR'
  AND [BranchId] = @branchId
  AND CAST([TransactionDate] AS DATE) = @date
```

### Data Transformation

```javascript
const salesData = {
  branch_id: config.branch_id,
  sale_date: dateStr,                    // YYYY-MM-DD
  total_bills: sales.TotalBills,         // Count of SI vouchers
  gross_amount: sales.GrossAmount,       // Total before tax
  tax_amount: sales.TaxAmount,           // VAT amount
  discount_amount: sales.DiscountAmount, // Total discounts
  total_returns: returns.TotalReturns,   // Count of SR vouchers
  return_amount: returns.ReturnAmount,   // Return total
  return_tax: returns.ReturnTax,         // Return VAT
  net_bills: sales.TotalBills - returns.TotalReturns,  // NET count
  net_amount: sales.GrossAmount - returns.ReturnAmount, // NET total
  net_tax: sales.TaxAmount - returns.ReturnTax,        // NET tax
  last_sync_at: new Date().toISOString()
};

// Upsert to Supabase
await supabase
  .from('erp_daily_sales')
  .upsert(salesData, {
    onConflict: 'branch_id,sale_date'
  });
```

### Supabase Table Schema

| Column | Type | Purpose |
|--------|------|---------|
| branch_id | integer (PK) | Which branch |
| sale_date | date (PK) | YYYY-MM-DD |
| total_bills | integer | Count of sales invoices |
| gross_amount | numeric | Total sales (before VAT) |
| tax_amount | numeric | Total VAT collected |
| discount_amount | numeric | Total discounts given |
| total_returns | integer | Count of return invoices |
| return_amount | numeric | Total return amount |
| return_tax | numeric | VAT on returns |
| net_bills | integer | Sales minus returns |
| net_amount | numeric | Net sales amount |
| net_tax | numeric | Net VAT |
| last_sync_at | timestamp | Last sync time |
| created_at | timestamp | Record created |
| updated_at | timestamp | Record updated |

### Used By

- 📊 **Dashboard & Reports** - Daily sales metrics
- 📈 **Analytics** - Revenue tracking
- 📋 **Branch Performance** - Sales summaries

---

# 🎯 SYNC TABLE 2 & 3: Privilege Card Sync

**Source:** SQL Server `PrivilegeCards` + `InvTransactionMaster`  
**Frequency:** Every 60 minutes  
**Tables:** `privilege_cards_master` + `privilege_cards_branch`

## How It Works

### Two Sync Functions

#### 1. **syncPrivilegeCardsMaster()** - All Unique Card Numbers

**File:** [D:\erp-sync-app\main.js#L1700](file:///D:/erp-sync-app/main.js)

**Frequency:** Every 60 minutes (+ initial sync on start)

**SQL Query:**
```sql
SELECT DISTINCT 
  LTRIM(CardNumber) as card_number
FROM PrivilegeCards
WHERE LTRIM(CardNumber) != ''
  AND CardNumber NOT LIKE '%?%'
  AND CardNumber NOT LIKE '%+%'
ORDER BY LTRIM(CardNumber)
```

**Upsert to Supabase:**
```javascript
const records = result.recordset.map(row => ({
  card_number: row.card_number.trim(),
  updated_at: new Date().toISOString()
}));

await supabase
  .from('privilege_cards_master')
  .upsert(records, { onConflict: 'card_number' });
```

**Table:** `privilege_cards_master` (small lookup table)

---

#### 2. **syncPrivilegeCardsByBranch()** - Full Card Data WITH Balance

**File:** [D:\erp-sync-app\main.js#L1800](file:///D:/erp-sync-app/main.js)

**Frequency:** Every 60 minutes (+ initial sync on start)

**SQL Query (ERP Side):**
```sql
SELECT 
  pc.PrivilegeCardsID,
  LTRIM(pc.CardNumber) as card_number,
  pc.BranchID as branch_id,
  pc.CardBalance as card_balance,           -- ← POINTS/BALANCE VALUE
  pc.CardHolderName as card_holder_name,
  pc.ExpiryDate as expiry_date,
  pc.Mobile as mobile,
  ISNULL(SUM(CASE WHEN itm.PrivRedeem > 0 THEN itm.PrivRedeem ELSE 0 END), 0) as total_redemptions,
  ISNULL(SUM(CASE WHEN itm.PrivRedeem > 0 THEN 1 ELSE 0 END), 0) as redemption_count
FROM PrivilegeCards pc
LEFT JOIN InvTransactionMaster itm ON pc.PrivilegeCardsID = itm.PrivCardID
WHERE pc.BranchID = ${branchId}
  AND LTRIM(pc.CardNumber) != ''
  AND pc.CardNumber NOT LIKE '%?%'
  AND pc.CardNumber NOT LIKE '%+%'
GROUP BY 
  pc.PrivilegeCardsID,
  pc.CardNumber,
  pc.BranchID,
  pc.CardBalance,
  pc.CardHolderName,
  pc.ExpiryDate,
  pc.Mobile
ORDER BY pc.CardNumber
```

**Transform & Upsert:**
```javascript
const records = result.recordset.map(row => ({
  privilege_card_id: row.PrivilegeCardsID,
  card_number: row.card_number.trim(),
  branch_id: row.branch_id,
  card_balance: parseFloat(row.card_balance) || 0,
  card_holder_name: row.card_holder_name || '',
  total_redemptions: parseFloat(row.total_redemptions) || 0,
  redemption_count: row.redemption_count || 0,
  expiry_date: row.expiry_date,
  mobile: row.mobile || '',
  last_sync_at: new Date().toISOString(),
  updated_at: new Date().toISOString()
}));

await supabase
  .from('privilege_cards_branch')
  .upsert(records, {
    onConflict: 'privilege_card_id,branch_id'
  });
```

**Table:** `privilege_cards_branch` (29 MB - main loyalty data table)

---

---

## 📊 Supabase Tables (Privilege Cards)

### privilege_cards_master
| Column | Type | Purpose |
|--------|------|---------|
| card_number | text (PK) | Unique card ID from ERP |
| updated_at | timestamp | Last sync time |

### privilege_cards_branch
| Column | Type | Purpose |
|--------|------|---------|
| privilege_card_id | bigint | ERP internal ID |
| card_number | text | Card number |
| branch_id | integer | Which branch |
| **card_balance** | numeric | **CUSTOMER POINTS ✅** |
| card_holder_name | text | Card holder name |
| total_redemptions | numeric | Total points spent |
| redemption_count | integer | Number of redemption txns |
| expiry_date | date | Card expiry date |
| mobile | text | Phone number |
| last_sync_at | timestamp | Last sync from ERP |
| updated_at | timestamp | Record update time |

### Used By

- 💳 **Loyalty Page** - Shows customer points balance
- 🔐 **Customer Login** - Validates card numbers
- 📱 **Mobile App** - Loyalty member details

---

# 🎯 SYNC TABLE 4: hr_employees

**Source:** ZKBioTime `personnel_employee`  
**Frequency:** Every 60 minutes  
**Branch-specific:** YES (filtered by branch location code)

## How It Works

Syncs employee records from the **ZKBioTime biometric system** (NOT ERP).

**File:** [D:\erp-sync-app\main.js#L1500](file:///D:/erp-sync-app/main.js)

### SQL Query (ZKBioTime)

```sql
SELECT 
  emp_code AS employee_id,
  first_name AS name
FROM personnel_employee
WHERE emp_code IS NOT NULL 
  AND first_name IS NOT NULL
```

### Data Transformation

```javascript
const locationCode = bioConfig.branch_location_code || ''; // e.g., "ADA", "KHF"

const employees = result.recordset.map(emp => ({
  employee_id: locationCode + emp.employee_id,    // PREFIX with location code
  original_employee_id: emp.employee_id,
  name: emp.name,
  branch_id: bioConfig.branch_id,
  status: 'active',
  created_at: new Date().toISOString(),
  updated_at: new Date().toISOString()
}));

// Update or insert
for (const emp of employees) {
  if (existingIds.has(emp.employee_id)) {
    // UPDATE existing
    await supabase
      .from('hr_employees')
      .update({ name: emp.name, updated_at: now })
      .eq('employee_id', emp.employee_id)
      .eq('branch_id', bioConfig.branch_id);
  } else {
    // CREATE new
    await supabase
      .from('hr_employees')
      .insert(emp);
  }
}
```

### Supabase Table Schema

| Column | Type | Purpose |
|--------|------|---------|
| employee_id | text (PK) | Location code + EMP code (e.g., "ADA001") |
| name | text | Employee name from ZKBioTime |
| branch_id | integer | Which branch |
| status | text | active/inactive |
| created_at | timestamp | Record created |
| updated_at | timestamp | Record updated |

### Used By

- 👥 **HR System** - Employee records
- 📊 **Attendance Reports** - Employee list
- 🔗 **Fingerprint Punch Lookup** - Links punch records to employees

---

# 🎯 SYNC TABLE 5: hr_fingerprint_transactions

**Source:** ZKBioTime `iclock_transaction`  
**Frequency:** Every 5 minutes (with auto catch-up for gaps)  
**Branch-specific:** YES

## How It Works

Syncs **punch clock records** (check-in/check-out) from ZKBioTime biometric terminals. Auto-detects sync gaps and catches up.

**File:** [D:\erp-sync-app\main.js#L1000](file:///D:/erp-sync-app/main.js)

### SQL Query (ZKBioTime)

```sql
SELECT 
  emp_code AS employee_id,
  punch_time,
  punch_state,
  terminal_sn,
  terminal_alias,
  area_alias
FROM [dbo].[iclock_transaction]
WHERE CAST(punch_time AS DATE) >= CAST(DATEADD(day, -${daysToSync}, GETDATE()) AS DATE)
  AND terminal_sn = @terminal_sn  -- Optional: filter by device
ORDER BY punch_time ASC
```

### Punch State Mapping

| Code | Status |
|------|--------|
| 0 | Check In |
| 1 | Check Out |
| 2 | Break Out |
| 3 | Break In |
| 4 | Overtime In |
| 5 | Overtime Out |

### Data Transformation

```javascript
const locationCode = bioConfig.branch_location_code || '';

const transformedTransactions = transactions.map(t => {
  const punchTimeStr = t.punch_time.toISOString();
  const datePart = punchTimeStr.split('T')[0];      // YYYY-MM-DD
  const timePart = punchTimeStr.split('T')[1].split('.')[0]; // HH:MM:SS
  
  const punchState = parseInt(t.punch_state, 10);
  let status;
  switch(punchState) {
    case 0: status = 'Check In'; break;
    case 1: status = 'Check Out'; break;
    case 2: status = 'Break Out'; break;
    case 3: status = 'Break In'; break;
    case 4: status = 'Overtime In'; break;
    case 5: status = 'Overtime Out'; break;
    default: return null;
  }
  
  return {
    employee_id: locationCode + t.employee_id,
    date: datePart,
    time: timePart,
    status: status,
    device_id: t.terminal_sn || t.terminal_alias || 'Unknown',
    location: t.area_alias || 'Unknown',
    branch_id: bioConfig.branch_id,
    created_at: new Date().toISOString()
  };
}).filter(t => t !== null);

// Filter duplicates (same employee, date, time, status within 2 minutes = skip)
// Then batch insert
const batchSize = 100;
for (let i = 0; i < newRecords.length; i += batchSize) {
  const batch = newRecords.slice(i, i + batchSize);
  
  await supabase
    .from('hr_fingerprint_transactions')
    .insert(batch)
    .select();
}
```

### Supabase Table Schema

| Column | Type | Purpose |
|--------|------|---------|
| employee_id | text | Location code + EMP code |
| date | date | Punch date (YYYY-MM-DD) |
| time | time | Punch time (HH:MM:SS) |
| status | text | Check In / Out / Break / Overtime |
| device_id | text | Biometric device serial number |
| location | text | Terminal location/area |
| branch_id | integer | Which branch |
| created_at | timestamp | Record created |

### Smart Features

✅ **Duplicate Detection** - Removes punches within 2 minutes of each other  
✅ **Batch Processing** - Inserts 100 records per batch  
✅ **Auto Catch-up** - If sync gap detected (>1 day), catches up automatically  
✅ **Offline Support** - Queues punches if Supabase unavailable  
✅ **Deduplication** - Fast lookup set prevents re-syncing  

### Used By

- 📊 **Attendance Tracking** - Employee daily attendance
- 🕐 **Shift Analysis** - Check-in/out patterns
- 📈 **Reports** - Attendance summaries
- ⚠️ **Alerts** - Late arrivals, missing check-outs

---

# 🔧 Configuration Storage Tables

## erp_connections

Stores **ERP SQL Server connection** details for each branch.

**File:** [D:\erp-sync-app\main.js#L400](file:///D:/erp-sync-app/main.js)

| Column | Type | Purpose |
|--------|------|---------|
| id | bigint (PK) | Record ID |
| branch_id | integer | Which branch |
| branch_name | text | Branch name |
| erp_branch_id | integer | ERP system branch ID |
| server_ip | text | SQL Server IP address |
| server_name | text | SQL Server hostname |
| database_name | text | Database name |
| username | text | SQL login username |
| password | text | SQL login password (encrypted) |
| device_id | text | Windows device ID |
| is_active | boolean | Is this config active |
| created_at | timestamp | Created |
| updated_at | timestamp | Updated |

## biometric_connections

Stores **ZKBioTime biometric system** connection details.

**File:** [D:\erp-sync-app\main.js#L700](file:///D:/erp-sync-app/main.js)

| Column | Type | Purpose |
|--------|------|---------|
| id | bigint (PK) | Record ID |
| branch_id | integer | Which branch |
| branch_name | text | Branch name |
| branch_location_code | text | 2-3 letter prefix (e.g., "ADA", "KHF") |
| server_ip | text | ZKBioTime server IP |
| server_name | text | Server hostname |
| database_name | text | Database name |
| username | text | Login username |
| password | text | Login password |
| device_id | text | Windows device ID |
| terminal_sn | text | Biometric terminal serial (optional filter) |
| is_active | boolean | Is active |
| last_sync_at | timestamp | Last sync timestamp |
| last_employee_sync_at | timestamp | Last employee sync |
| created_at | timestamp | Created |
| updated_at | timestamp | Updated |

---

## 🎨 Frontend Components Using Synced Data

### 1. Loyalty Details Page

**File:** [frontend/src/routes/loyalty/details/+page.svelte](file:///d:/Aqura/frontend/src/routes/loyalty/details/+page.svelte)

```typescript
// Reads from: privilege_cards_branch
const { data: branchDataArray } = await supabase
  .from('privilege_cards_branch')
  .select('*')
  .eq('card_number', cardNumber);

// Displays:
// - card_balance (customer points)
// - total_redemptions (total spent)
// - redemption_count (number of transactions)
// - last_sync_at (when updated)
```

### 2. Customer Login

**File:** [frontend/src/lib/components/customer-interface/common/CustomerLogin.svelte](file:///d:/Aqura/frontend/src/lib/components/customer-interface/common/CustomerLogin.svelte)

```typescript
// Validates card against: privilege_cards_master
const { data } = await supabase
  .from('privilege_cards_master')
  .select('id, card_number')
  .eq('card_number', cleanNumber)
  .maybeSingle();
```

### 3. Dashboard & Reports

**Uses:** `erp_daily_sales`

```typescript
// Daily sales metrics, revenue tracking, branch performance
const { data: salesData } = await supabase
  .from('erp_daily_sales')
  .select('*')
  .gte('sale_date', startDate)
  .lte('sale_date', endDate);
```

### 4. HR & Attendance System

**Uses:** `hr_employees`, `hr_fingerprint_transactions`

```typescript
// Employee records, punch clocks, attendance reports
const { data: punches } = await supabase
  .from('hr_fingerprint_transactions')
  .select('*')
  .eq('employee_id', empId)
  .gte('date', reportDate);
```

---

## ⏰ Sync Schedule - ALL Tables

| Table | Source | Frequency | Status | Notes |
|-------|--------|-----------|--------|-------|
| erp_daily_sales | SQL Server | Every 5 minutes | ✅ Continuous | Sales summaries (today + yesterday) |
| privilege_cards_master | SQL Server | Every 60 minutes | ✅ Continuous | Card number lookup |
| privilege_cards_branch | SQL Server | Every 60 minutes | ✅ Continuous | **29 MB - Customer points** |
| hr_employees | ZKBioTime | Every 60 minutes | ✅ Continuous | Employee master data |
| hr_fingerprint_transactions | ZKBioTime | Every 5 minutes | ✅ Continuous | Punch clock records (auto catch-up) |

### Startup Behavior

When sync service starts, **ALL syncs run immediately** in background, then on schedule:

```javascript
// On start:
await performSync();              // erp_daily_sales
syncPrivilegeCardsMaster();        // privilege_cards_master  
syncPrivilegeCardsByBranch();      // privilege_cards_branch
await syncBiometricEmployees();    // hr_employees
await syncBiometricTransactions(); // hr_fingerprint_transactions

// Then continuous intervals:
setInterval(() => performSync(), 5 * 60 * 1000);           // 5 min
setInterval(() => syncBiometricTransactions(), 5 * 60 * 1000); // 5 min
setInterval(() => syncPrivilegeCardsMaster(), 60 * 60 * 1000); // 60 min
setInterval(() => syncPrivilegeCardsByBranch(), 60 * 60 * 1000); // 60 min
setInterval(() => syncBiometricEmployees(), 60 * 60 * 1000);  // 60 min
```

---

## 🔧 Key Implementation Details

### 1. Batch Operations

All syncs use **batch operations** (not row-by-row):

```javascript
// Privilege cards
await supabase
  .from('privilege_cards_branch')
  .upsert(records, { onConflict: 'privilege_card_id,branch_id' });

// Fingerprints (100 records per batch)
for (let i = 0; i < newRecords.length; i += 100) {
  const batch = newRecords.slice(i, i + 100);
  await supabase.from('hr_fingerprint_transactions').insert(batch);
}

// Daily sales
await supabase
  .from('erp_daily_sales')
  .upsert(salesData, { onConflict: 'branch_id,sale_date' });
```

### 2. Conflict Resolution

Different strategies per table:

```javascript
// Privilege cards: Update if exists (match on ID + branch)
.upsert(records, { onConflict: 'privilege_card_id,branch_id' })

// Daily sales: Update if exists (match on branch + date)
.upsert(data, { onConflict: 'branch_id,sale_date' })

// HR Fingerprints: Insert only new (dedup via fast lookup set)
.insert(newRecords).select()

// HR Employees: Update or insert (check existing first)
if (existingIds.has(emp.employee_id)) {
  .update({...})
} else {
  .insert({...})
}
```

### 3. Data Transformation Pipeline

Example for privilege cards:

```javascript
// 1. Query ERP
const result = await pool.request().query(SQL_QUERY);

// 2. Transform
const records = result.recordset.map(row => ({
  privilege_card_id: row.PrivilegeCardsID,
  card_number: row.card_number.trim(),        // Clean
  card_balance: parseFloat(row.card_balance) || 0,  // Type convert
  updated_at: new Date().toISOString()
}));

// 3. Validate
const validRecords = records.filter(r => r.card_number && r.card_number.length > 0);

// 4. Upsert
await supabase.from('privilege_cards_branch').upsert(validRecords);
```

### 4. Error Handling & Logging

All errors are sent to UI in real-time:

```javascript
try {
  await supabase.from('privilege_cards_branch').upsert(records);
  mainWindow?.webContents.send('sync-log', {
    type: 'success',
    message: `✅ Synced ${records.length} privilege cards`
  });
} catch (error) {
  console.error('Sync error:', error);
  mainWindow?.webContents.send('sync-log', {
    type: 'error',
    message: `❌ Sync failed: ${error.message}`
  });
}
```

### 5. Smart Features

#### Auto Catch-up (Fingerprints)
```javascript
// If gap detected, automatically catch up
const lastSync = new Date(connData?.last_sync_at);
const gapDays = Math.ceil((now - lastSync) / (1000 * 60 * 60 * 24));
if (gapDays > 1) {
  daysToSync = Math.min(gapDays + 1, 30); // Max 30 days
  // Query last N days and sync everything
}
```

#### Duplicate Removal (Fingerprints)
```javascript
// Remove punches within 2 minutes of each other
if (nextTime - currentTime <= 2 * 60 * 1000) {
  console.log('⚠️ Duplicate detected, skipping');
  continue;
}
```

#### Offline Queue
```javascript
// If Supabase unavailable, queue locally
if (!isOnline) {
  saveToLocalQueue(salesData);
  return;
}

// When internet returns, process queue
if (isOnline && retryQueue.length > 0) {
  processOfflineQueue();
}
```

#### Location Code Prefixing
```javascript
// Biometric employee IDs prefixed with branch location code
const locationCode = bioConfig.branch_location_code; // e.g., "ADA"
employee_id: locationCode + emp.employee_id;  // "ADA001"
```

---

## 🚀 Starting & Managing Sync Service

### UI Flow (erp-sync-app)

1. **Configure Supabase** (one-time)
   - Enter `VITE_SUPABASE_URL`
   - Enter `VITE_SUPABASE_SERVICE_KEY`
   - Test connection

2. **Login** with access code
   - User auth via bcrypt-hashed quick access code

3. **Configure ERP Connection**
   - Select branch
   - Enter SQL Server IP
   - Enter database name
   - Enter SQL credentials
   - Test connection

4. **Configure Biometric Connection** (optional)
   - Select branch
   - Enter ZKBioTime server IP
   - Enter biometric database credentials
   - Enter location code (for employee ID prefix)
   - Test connection

5. **Start Sync**
   - Initializes SQL connection pools
   - Starts all sync intervals
   - Displays real-time sync logs

### From Code

```javascript
// Start all syncs
ipcMain.handle('start-sync', async () => {
  // 1. Initialize SQL pool for ERP
  sqlPool = await sql.connect(sqlConfig);
  
  // 2. Initialize SQL pool for biometrics
  bioSqlPool = await sql.connect(bioSqlConfig);
  
  // 3. Start interval syncs
  syncInterval = setInterval(async () => {
    await performSync();  // erp_daily_sales
  }, 5 * 60 * 1000);
  
  privCardMasterSyncInterval = setInterval(async () => {
    await syncPrivilegeCardsMaster();
  }, 60 * 60 * 1000);
  
  privCardBranchSyncInterval = setInterval(async () => {
    await syncPrivilegeCardsByBranch();
  }, 60 * 60 * 1000);
  
  bioSyncInterval = setInterval(async () => {
    await syncBiometricTransactions();
  }, 5 * 60 * 1000);
  
  bioEmployeeSyncInterval = setInterval(async () => {
    await syncBiometricEmployees();
  }, 60 * 60 * 1000);
  
  // 4. Perform initial syncs (non-blocking)
  performSync();
  syncPrivilegeCardsMaster();
  syncPrivilegeCardsByBranch();
  syncBiometricEmployees();
  syncBiometricTransactions();
  
  return { success: true };
});

// Stop all syncs
ipcMain.handle('stop-sync', async () => {
  clearInterval(syncInterval);
  clearInterval(privCardMasterSyncInterval);
  clearInterval(privCardBranchSyncInterval);
  clearInterval(bioSyncInterval);
  clearInterval(bioEmployeeSyncInterval);
  
  if (sqlPool) await sqlPool.close();
  if (bioSqlPool) await bioSqlPool.close();
  
  return { success: true };
});
```

---

## 🐛 Troubleshooting Guide

### Issue: Data Not Updating in Supabase

**Check List:**
- ✅ Is erp-sync-app running on Windows PC? (Check System Tray)
- ✅ Is Sync service **started**? (Green "Start Sync" → Red "Stop Sync")
- ✅ Check sync logs in app UI (should show ✅ success messages)
- ✅ Wait 5-60 minutes (depending on table)
- ✅ Manual refresh: Stop Sync → Start Sync

**Specific to Privilege Cards:**
- ✅ Wait **60 minutes** (not synced every 5 min like sales)
- ✅ Verify ERP SQL connection is working (test button)
- ✅ Check if cards exist in ERP's PrivilegeCards table

**Specific to Fingerprints:**
- ✅ Check if biometric terminal is connected
- ✅ Verify punch records exist in ZKBioTime database
- ✅ Check location code is set correctly
- ✅ Wait **5 minutes** for next sync

### Issue: Sync App Won't Start

**Solutions:**
- ✅ Check Node.js installed: `node --version`
- ✅ Reinstall dependencies: `cd D:\erp-sync-app && npm install`
- ✅ Clear npm cache: `npm cache clean --force`
- ✅ Check Windows Firewall allows SQL Server access
- ✅ Run as Administrator

### Issue: Can't Connect to SQL Server

**Check:**
- ✅ SQL Server IP is correct (try ping)
- ✅ SQL Server is running (check Windows services)
- ✅ Firewall allows port 1433
- ✅ Username/password is correct
- ✅ Database name exists
- ✅ Network connectivity between PC and server

### Issue: Supabase Connection Failed

**Check:**
- ✅ VITE_SUPABASE_URL is correct (should be `https://supabase.urbanaqura.com`)
- ✅ VITE_SUPABASE_SERVICE_KEY is valid (NOT anon key)
- ✅ Internet connectivity
- ✅ Test button shows success before starting sync

### Issue: Missing Employee Records

**Check:**
- ✅ Location code is set in biometric config
- ✅ Employee records exist in ZKBioTime personnel_employee table
- ✅ Biometric sync is running (should see log messages)
- ✅ Check employee IDs are prefixed with location code

### Issue: Duplicate Fingerprints

**This is Expected:**
- Duplicates within 2 minutes are automatically filtered
- Check app logs: "⚠️ Duplicate detected, skipping"
- If seeing same punch multiple times → sync may have failed mid-way

**Solution:**
- Stop sync
- Clear duplicates manually from database
- Start sync again

### Issue: High Memory Usage

**Causes:**
- Large batch sizes for fingerprints
- Too many syncs running simultaneously
- Old log data not cleared

**Solutions:**
- Reduce batch size (default 100, try 50)
- Restart app periodically
- Check disk space for log files

---

---

## 📝 Complete File & Function Reference

### erp-sync-app Files

| File | Purpose | Key Functions |
|------|---------|----------------|
| [D:\erp-sync-app\main.js](file:///D:/erp-sync-app/main.js) | **Main sync engine** | All sync functions, IPC handlers, SQL queries |
| [D:\erp-sync-app\renderer.js](file:///D:/erp-sync-app/renderer.js) | **UI component** | Configuration forms, log display, auth |
| [D:\erp-sync-app\preload.js](file:///D:/erp-sync-app/preload.js) | **IPC bridge** | Exposes electron API to renderer |
| [D:\erp-sync-app\package.json](file:///D:/erp-sync-app/package.json) | **Dependencies** | mssql, @supabase/supabase-js, electron |
| [D:\erp-sync-app\index.html](file:///D:/erp-sync-app/index.html) | **HTML UI** | Form layouts, log display area |

### Sync Functions (All in main.js)

**ERP Daily Sales:**
- `performSync()` - Main sync function (5 min interval)
- `syncDateData(dateStr)` - Syncs single day data

**Privilege Cards Master:**
- `syncPrivilegeCardsMaster()` - Unique card numbers (60 min interval)

**Privilege Cards Branch:**
- `syncPrivilegeCardsByBranch()` - Card balances + redemptions (60 min interval)

**Biometric Employees:**
- `syncBiometricEmployees()` - Employee master (60 min interval)

**Biometric Transactions:**
- `syncBiometricTransactions()` - Punch records (5 min interval + auto catch-up)
- `syncBiometricTransactionsCatchup(days)` - Manual catch-up

**Historical Sync:**
- `syncDateData()` - Syncs specific date range
- `ipcMain.handle('sync-historical-data')` - Manual historical sync

**Configuration:**
- `ipcMain.handle('save-config')` - Saves ERP connection
- `ipcMain.handle('save-bio-config')` - Saves biometric connection
- `ipcMain.handle('start-sync')` - Starts all sync intervals
- `ipcMain.handle('stop-sync')` - Stops all sync intervals

### Frontend Files (Using Synced Data)

| File | Purpose | Tables Used |
|------|---------|-------------|
| [frontend/src/routes/loyalty/details/+page.svelte](file:///d:/Aqura/frontend/src/routes/loyalty/details/+page.svelte) | Loyalty page | privilege_cards_branch |
| [frontend/src/lib/components/customer-interface/common/CustomerLogin.svelte](file:///d:/Aqura/frontend/src/lib/components/customer-interface/common/CustomerLogin.svelte) | Login validation | privilege_cards_master |
| [frontend/src/routes/dashboard/+page.svelte](file:///d:/Aqura/frontend/src/routes/dashboard) | Sales dashboard | erp_daily_sales |
| [frontend/src/lib/components/hr/...](file:///d:/Aqura/frontend/src/lib/components) | HR system | hr_employees, hr_fingerprint_transactions |

---

## 💡 Key Takeaways - COMPLETE PICTURE

### What Gets Synced (5 Tables)

1. **erp_daily_sales** - Daily sales summaries (5 min) 📊
2. **privilege_cards_master** - Card number lookup (60 min) 💳
3. **privilege_cards_branch** - Card balance + points (60 min) **← 29 MB**
4. **hr_employees** - Employee records (60 min) 👥
5. **hr_fingerprint_transactions** - Punch clock (5 min) 🕐

### How Sync Works

```
Windows PC (D:\erp-sync-app)
    ↓
Connects to TWO databases:
    ├─ SQL Server ERP (sales + loyalty cards)
    └─ ZKBioTime (biometrics + employees)
    ↓
Runs scheduled jobs (every 5/60 minutes)
    ↓
Transforms & batches data
    ↓
Upserts to Supabase
    ↓
Frontend reads synced data
```

### Critical Points

✅ **erp-sync-app MUST be running** for any data to sync  
✅ **Runs on Windows PC** - needs SQL Server access  
✅ **Offline mode** - queues data locally if Supabase unavailable  
✅ **Batch operations** - efficient, not row-by-row  
✅ **Auto catch-up** - detects sync gaps and catches up  
✅ **Branch-specific** - each branch has separate config  
✅ **Real-time logging** - errors shown in app UI immediately  

### Sync Sequence on Startup

```
App Start
    ↓
Load config from Supabase (erp_connections, biometric_connections)
    ↓
Initialize SQL pools (ERP + Biometric)
    ↓
RUN INITIAL SYNCS (all at once):
    ├─ performSync()                    → erp_daily_sales
    ├─ syncPrivilegeCardsMaster()       → privilege_cards_master
    ├─ syncPrivilegeCardsByBranch()     → privilege_cards_branch
    ├─ syncBiometricEmployees()         → hr_employees
    └─ syncBiometricTransactions()      → hr_fingerprint_transactions
    ↓
START CONTINUOUS INTERVALS:
    ├─ 5 min: ERP sales + fingerprints
    └─ 60 min: Privilege cards + employees
```

---

## 📞 Contact & Support

If syncing issues occur:

1. **Check app logs** (in erp-sync-app UI)
2. **Verify SQL connections** (test button in app)
3. **Check Supabase** (dashboard.supabase.com)
4. **Check database** (via SSH to server at 8.213.42.21)
5. **Restart app** (stop sync → start sync)
6. **Reinstall dependencies** (npm install in app folder)

---

**Last Updated:** May 9, 2026  
**Author:** Copilot  
**Version:** 2.0 - Complete Overview  
**Scope:** ALL sync tables in erp-sync-app
