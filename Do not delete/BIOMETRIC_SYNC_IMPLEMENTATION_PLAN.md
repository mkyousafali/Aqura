# Biometric Sync Implementation Plan

**Project:** Add Biometric Attendance Sync to Aqura ERP Sync App  
**Date:** November 28, 2025  
**Target:** Sync ZKBioTime attendance data to Supabase

---

## 🎯 Overview

Add biometric attendance synchronization to the existing ERP sync app. The same desktop app will handle:
- ✅ ERP sales data sync (existing)
- 🆕 Biometric attendance sync (new)

**Design:** 1 Branch = 1 ERP Config + 1 Biometric Config

---

## 📊 Phase 1: Database Setup in Supabase

### 1.1 Create `biometric_connections` Table

```sql
-- Create biometric_connections table (similar to erp_connections)
CREATE TABLE biometric_connections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_id INTEGER NOT NULL REFERENCES branches(id),
  branch_name TEXT NOT NULL,
  server_ip TEXT NOT NULL,
  server_name TEXT,
  database_name TEXT NOT NULL,
  username TEXT NOT NULL,
  password TEXT NOT NULL,
  device_id TEXT NOT NULL,
  terminal_sn TEXT,
  is_active BOOLEAN DEFAULT true,
  last_sync_at TIMESTAMPTZ,
  last_employee_sync_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT unique_branch_device UNIQUE(branch_id, device_id)
);

-- Enable RLS
ALTER TABLE biometric_connections ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Enable read for authenticated users" ON biometric_connections
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Enable insert for authenticated users" ON biometric_connections
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Enable update for authenticated users" ON biometric_connections
  FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Enable delete for authenticated users" ON biometric_connections
  FOR DELETE USING (auth.role() = 'authenticated');

-- Create indexes
CREATE INDEX idx_biometric_connections_branch ON biometric_connections(branch_id);
CREATE INDEX idx_biometric_connections_active ON biometric_connections(is_active);
CREATE INDEX idx_biometric_connections_device ON biometric_connections(device_id);
```

### 1.2 Verify Target Tables Exist

**Check `hr_employees` table:**
```sql
-- Should already exist with structure:
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'hr_employees';

-- Expected columns:
-- - id (UUID)
-- - employee_id (text) ← Maps to ZKBioTime emp_code
-- - name (text) ← Maps to ZKBioTime first_name
-- - branch_id (integer)
-- - hire_date (date)
-- - status (text)
-- - created_at (timestamptz)
-- - updated_at (timestamptz)
```

**Check `hr_fingerprint_transactions` table:**
```sql
-- Should already exist with structure:
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'hr_fingerprint_transactions';

-- Expected columns:
-- - id (UUID)
-- - employee_id (text) ← Maps to ZKBioTime emp_code
-- - name (text) ← Maps to ZKBioTime first_name
-- - branch_id (integer)
-- - transaction_date (date) ← From punch_time
-- - transaction_time (text) ← From punch_time
-- - punch_state (text) ← "Check In" or "Check Out"
-- - device_id (text) ← Maps to terminal_alias or terminal_sn
-- - created_at (timestamptz)
```

---

## 🖥️ Phase 2: ERP Sync App UI Changes

### 2.1 Files to Modify

**Main Files:**
- `index.html` - Add Biometric Configuration section
- `renderer.js` - Add biometric UI logic
- `main.js` - Add biometric sync functions
- `preload.js` - Add biometric IPC handlers

### 2.2 UI Layout Changes

**Current Layout:**
```
┌─────────────────────────────────┐
│  📊 ERP Configuration           │
│  [Branch] [Server] [Save] [Sync]│
│  Status: Syncing...             │
└─────────────────────────────────┘
```

**New Layout:**
```
┌─────────────────────────────────┐
│  📊 ERP Configuration           │
│  [Branch] [Server] [Save] [Sync]│
│  Status: ✅ Active              │
├─────────────────────────────────┤
│  👆 Biometric Configuration     │
│  [Server] [Database] [Terminal] │
│  [Save] [Test] [Start Sync]     │
│  Status: ✅ Active              │
└─────────────────────────────────┘
│  📝 Sync Logs                   │
│  14:35 - ERP: 45 bills synced   │
│  14:33 - Bio: 23 punches synced │
└─────────────────────────────────┘
```

### 2.3 New UI Elements in `index.html`

Add after ERP configuration section:

```html
<!-- Biometric Configuration Section -->
<div class="config-section" id="biometric-section" style="display: none;">
  <h2>👆 Biometric Configuration</h2>
  
  <div class="form-group">
    <label>Branch: <span id="bio-branch-name">-</span></label>
    <small>(Same as ERP configuration)</small>
  </div>

  <div class="form-group">
    <label>Server IP:</label>
    <input type="text" id="bio-server-ip" placeholder="192.168.0.3">
  </div>

  <div class="form-group">
    <label>Server Name (Optional):</label>
    <input type="text" id="bio-server-name" placeholder="WIN-D1D6EN8240A or SQLEXPRESS">
  </div>

  <div class="form-group">
    <label>Database Name:</label>
    <input type="text" id="bio-database-name" placeholder="Zkurbard">
  </div>

  <div class="form-group">
    <label>Username:</label>
    <input type="text" id="bio-username" placeholder="sa">
  </div>

  <div class="form-group">
    <label>Password:</label>
    <input type="password" id="bio-password">
  </div>

  <div class="form-group">
    <label>Terminal Serial Number (Optional):</label>
    <input type="text" id="bio-terminal-sn" placeholder="MFP3243700773 (leave empty for all)">
    <small>Leave empty to sync all terminals from this server</small>
  </div>

  <div class="button-group">
    <button id="test-bio-connection" class="secondary-btn">Test Connection</button>
    <button id="save-bio-config" class="primary-btn">Save Configuration</button>
  </div>

  <div class="status-box" id="bio-status">
    <strong>Status:</strong> <span id="bio-status-text">Not configured</span>
  </div>

  <div class="button-group">
    <button id="start-bio-sync" class="primary-btn" disabled>Start Biometric Sync</button>
    <button id="stop-bio-sync" class="secondary-btn" disabled>Stop Sync</button>
    <button id="sync-employees-now" class="secondary-btn" disabled>Sync Employees Now</button>
  </div>

  <div class="historical-sync-section">
    <h3>📅 Historical Transaction Sync</h3>
    <div class="form-group">
      <label>Start Date:</label>
      <input type="date" id="bio-historical-start-date">
      <small>Sync all transactions from this date onwards</small>
    </div>
    <button id="sync-bio-historical" class="secondary-btn" disabled>Sync Historical Data</button>
    <div id="bio-historical-progress" style="display: none;">
      <progress id="bio-historical-progress-bar" max="100" value="0"></progress>
      <span id="bio-historical-progress-text">0%</span>
    </div>
  </div>
</div>
```

---

## 🔧 Phase 3: Backend Implementation (`main.js`)

### 3.1 Add Biometric Configuration Variables

```javascript
// At the top with existing variables
let erpConfig = null;
let bioConfig = null;  // NEW
let bioSyncInterval = null;  // NEW
let employeeSyncInterval = null;  // NEW
let bioSqlPool = null;  // NEW
let isBioRunning = false;  // NEW
```

### 3.2 Add IPC Handlers for Biometric Config

```javascript
// Save biometric configuration
ipcMain.handle('save-bio-config', async (event, configData) => {
  try {
    // Check if config exists
    const { data: existing } = await supabase
      .from('biometric_connections')
      .select('id')
      .eq('branch_id', configData.branch_id)
      .eq('device_id', configData.device_id)
      .single();

    let result;
    if (existing) {
      // Update existing
      result = await supabase
        .from('biometric_connections')
        .update({
          branch_name: configData.branch_name,
          server_ip: configData.server_ip,
          server_name: configData.server_name,
          database_name: configData.database_name,
          username: configData.username,
          password: configData.password,
          terminal_sn: configData.terminal_sn || null,
          is_active: true,
          updated_at: new Date().toISOString()
        })
        .eq('id', existing.id)
        .select()
        .single();
    } else {
      // Insert new
      result = await supabase
        .from('biometric_connections')
        .insert({
          branch_id: configData.branch_id,
          branch_name: configData.branch_name,
          server_ip: configData.server_ip,
          server_name: configData.server_name,
          database_name: configData.database_name,
          username: configData.username,
          password: configData.password,
          terminal_sn: configData.terminal_sn || null,
          device_id: configData.device_id,
          is_active: true
        })
        .select()
        .single();
    }

    if (result.error) throw result.error;

    bioConfig = configData;
    return { success: true, config: result.data };
  } catch (error) {
    console.error('Save bio config error:', error);
    return { success: false, error: error.message };
  }
});

// Test biometric connection
ipcMain.handle('test-bio-connection', async (event, testConfig) => {
  try {
    const bioSqlConfig = {
      server: testConfig.server_ip,
      database: testConfig.database_name,
      user: testConfig.username,
      password: testConfig.password,
      options: {
        encrypt: false,
        trustServerCertificate: true,
        enableArithAbort: true,
        connectTimeout: 10000
      }
    };

    const pool = await sql.connect(bioSqlConfig);
    
    // Test query to verify it's a ZKBioTime database
    const testResult = await pool.request().query(`
      SELECT COUNT(*) as count FROM personnel_employee
    `);
    
    const employeeCount = testResult.recordset[0].count;
    
    await pool.close();

    return { 
      success: true, 
      message: `Connected successfully! Found ${employeeCount} employees in database.` 
    };
  } catch (error) {
    return { success: false, error: error.message };
  }
});
```

### 3.3 Employee Sync Function

```javascript
// Sync employees from ZKBioTime to Supabase hr_employees
async function syncEmployees() {
  if (!bioSqlPool || !bioConfig) return;

  try {
    mainWindow.webContents.send('sync-log', {
      type: 'info',
      message: '👥 Syncing employees from ZKBioTime...'
    });

    // Get all employees from ZKBioTime
    const employeeQuery = `
      SELECT 
        emp_code,
        first_name,
        last_name,
        email,
        hire_date,
        create_time
      FROM personnel_employee
      ORDER BY emp_code
    `;

    const result = await bioSqlPool.request().query(employeeQuery);
    const employees = result.recordset;

    if (employees.length === 0) {
      mainWindow.webContents.send('sync-log', {
        type: 'info',
        message: '⚠️ No employees found in ZKBioTime'
      });
      return;
    }

    // Prepare data for Supabase
    const employeesToSync = employees.map(emp => ({
      employee_id: emp.emp_code.toString(),
      name: emp.last_name 
        ? `${emp.first_name} ${emp.last_name}`.trim() 
        : emp.first_name,
      branch_id: bioConfig.branch_id,
      hire_date: emp.hire_date ? emp.hire_date.toISOString().split('T')[0] : null,
      status: 'active',
      created_at: emp.create_time ? emp.create_time.toISOString() : new Date().toISOString()
    }));

    // Upsert to Supabase (insert or update)
    let syncedCount = 0;
    let errorCount = 0;

    for (const employee of employeesToSync) {
      try {
        // Check if employee exists
        const { data: existing } = await supabase
          .from('hr_employees')
          .select('id')
          .eq('employee_id', employee.employee_id)
          .eq('branch_id', employee.branch_id)
          .single();

        if (existing) {
          // Update existing employee
          const { error } = await supabase
            .from('hr_employees')
            .update({
              name: employee.name,
              hire_date: employee.hire_date,
              updated_at: new Date().toISOString()
            })
            .eq('id', existing.id);

          if (error) throw error;
        } else {
          // Insert new employee
          const { error } = await supabase
            .from('hr_employees')
            .insert(employee);

          if (error) throw error;
        }

        syncedCount++;
      } catch (err) {
        console.error(`Failed to sync employee ${employee.employee_id}:`, err);
        errorCount++;
      }
    }

    // Update last_employee_sync_at timestamp
    await supabase
      .from('biometric_connections')
      .update({ last_employee_sync_at: new Date().toISOString() })
      .eq('branch_id', bioConfig.branch_id)
      .eq('device_id', bioConfig.device_id);

    mainWindow.webContents.send('sync-log', {
      type: 'success',
      message: `✅ Employee sync complete: ${syncedCount} synced${errorCount > 0 ? `, ${errorCount} failed` : ''}`
    });

  } catch (error) {
    console.error('Employee sync error:', error);
    mainWindow.webContents.send('sync-log', {
      type: 'error',
      message: `❌ Employee sync failed: ${error.message}`
    });
  }
}
```

### 3.4 Punch Transaction Sync Function

```javascript
// Sync punch transactions from ZKBioTime to Supabase
async function syncBiometricTransactions() {
  if (isBioRunning || !bioSqlPool || !bioConfig) return;

  isBioRunning = true;
  const startTime = Date.now();

  try {
    // Get last sync timestamp
    const { data: configData } = await supabase
      .from('biometric_connections')
      .select('last_sync_at')
      .eq('branch_id', bioConfig.branch_id)
      .eq('device_id', bioConfig.device_id)
      .single();

    // Default to 24 hours ago if no last sync
    const lastSyncTime = configData?.last_sync_at 
      ? new Date(configData.last_sync_at)
      : new Date(Date.now() - 24 * 60 * 60 * 1000);

    mainWindow.webContents.send('sync-log', {
      type: 'info',
      message: `👆 Syncing punches since ${lastSyncTime.toLocaleString()}...`
    });

    // Build query with optional terminal filter
    let punchQuery = `
      SELECT 
        t.emp_code,
        e.first_name,
        e.last_name,
        t.punch_time,
        t.punch_state,
        t.terminal_sn,
        t.terminal_alias,
        t.area_alias,
        t.verify_type,
        t.work_code
      FROM iclock_transaction t
      LEFT JOIN personnel_employee e ON t.emp_code = e.emp_code
      WHERE t.punch_time > @lastSyncTime
    `;

    // Add terminal filter if specified
    if (bioConfig.terminal_sn) {
      punchQuery += ` AND t.terminal_sn = @terminalSn`;
    }

    punchQuery += ` ORDER BY t.punch_time DESC`;

    const request = bioSqlPool.request()
      .input('lastSyncTime', sql.DateTime, lastSyncTime);

    if (bioConfig.terminal_sn) {
      request.input('terminalSn', sql.NVarChar, bioConfig.terminal_sn);
    }

    const result = await request.query(punchQuery);
    const punches = result.recordset;

    if (punches.length === 0) {
      mainWindow.webContents.send('sync-log', {
        type: 'info',
        message: '✅ No new punch records to sync'
      });
      
      // Update last sync timestamp even if no records
      await supabase
        .from('biometric_connections')
        .update({ last_sync_at: new Date().toISOString() })
        .eq('branch_id', bioConfig.branch_id)
        .eq('device_id', bioConfig.device_id);

      return;
    }

    // Transform and insert punch records
    const transactionsToSync = punches.map(punch => {
      const punchDateTime = new Date(punch.punch_time);
      const employeeName = punch.last_name 
        ? `${punch.first_name} ${punch.last_name}`.trim()
        : punch.first_name;

      return {
        employee_id: punch.emp_code.toString(),
        name: employeeName,
        branch_id: bioConfig.branch_id,
        transaction_date: punchDateTime.toISOString().split('T')[0],
        transaction_time: punchDateTime.toLocaleTimeString('en-US', { 
          hour12: true, 
          hour: '2-digit', 
          minute: '2-digit' 
        }),
        punch_state: punch.punch_state === 0 ? 'Check In' : 'Check Out',
        device_id: punch.terminal_alias || punch.terminal_sn || 'Unknown',
        created_at: new Date().toISOString()
      };
    });

    // Batch insert to Supabase
    const { data: insertedData, error: insertError } = await supabase
      .from('hr_fingerprint_transactions')
      .insert(transactionsToSync)
      .select();

    if (insertError) throw insertError;

    // Update last sync timestamp
    await supabase
      .from('biometric_connections')
      .update({ last_sync_at: new Date().toISOString() })
      .eq('branch_id', bioConfig.branch_id)
      .eq('device_id', bioConfig.device_id);

    const duration = Date.now() - startTime;
    
    mainWindow.webContents.send('sync-log', {
      type: 'success',
      message: `✅ Synced ${punches.length} punch records in ${duration}ms`
    });

  } catch (error) {
    console.error('Biometric sync error:', error);
    mainWindow.webContents.send('sync-log', {
      type: 'error',
      message: `❌ Biometric sync failed: ${error.message}`
    });
  } finally {
    isBioRunning = false;
  }
}
```

### 3.5 Start/Stop Biometric Sync

```javascript
// Start biometric sync service
ipcMain.handle('start-bio-sync', async () => {
  if (!bioConfig) {
    return { success: false, error: 'No biometric configuration set' };
  }

  try {
    // Initialize SQL connection to ZKBioTime
    const bioSqlConfig = {
      server: bioConfig.server_ip,
      database: bioConfig.database_name,
      user: bioConfig.username,
      password: bioConfig.password,
      options: {
        encrypt: false,
        trustServerCertificate: true,
        enableArithAbort: true,
        connectionTimeout: 30000,
        requestTimeout: 30000
      },
      pool: {
        max: 5,
        min: 1,
        idleTimeoutMillis: 30000
      }
    };

    bioSqlPool = await sql.connect(bioSqlConfig);

    // Sync employees immediately
    await syncEmployees();

    // Start punch sync every 5 minutes (300000ms)
    bioSyncInterval = setInterval(async () => {
      await syncBiometricTransactions();
    }, 300000);

    // Start employee sync every 30 minutes (1800000ms)
    employeeSyncInterval = setInterval(async () => {
      await syncEmployees();
    }, 1800000);

    // Perform initial punch sync
    await syncBiometricTransactions();

    return { success: true, message: 'Biometric sync started successfully' };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

// Stop biometric sync service
ipcMain.handle('stop-bio-sync', async () => {
  if (bioSyncInterval) {
    clearInterval(bioSyncInterval);
    bioSyncInterval = null;
  }

  if (employeeSyncInterval) {
    clearInterval(employeeSyncInterval);
    employeeSyncInterval = null;
  }

  if (bioSqlPool) {
    await bioSqlPool.close();
    bioSqlPool = null;
  }

  return { success: true, message: 'Biometric sync stopped' };
});

// Manual employee sync trigger
ipcMain.handle('sync-employees-now', async () => {
  try {
    await syncEmployees();
    return { success: true };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

// Sync historical biometric data
ipcMain.handle('sync-bio-historical-data', async (event, startDate) => {
  if (!bioConfig || !bioSqlPool) {
    return { success: false, error: 'Biometric sync not configured or not running' };
  }

  try {
    mainWindow.webContents.send('sync-log', {
      type: 'info',
      message: `🔄 Starting historical biometric sync from ${startDate}...`
    });

    // Parse start date
    const startDateTime = new Date(startDate + 'T00:00:00');
    const endDateTime = new Date(); // Today

    // Calculate total days
    const totalDays = Math.ceil((endDateTime - startDateTime) / (1000 * 60 * 60 * 24));
    
    mainWindow.webContents.send('sync-log', {
      type: 'info',
      message: `📅 Will sync ${totalDays} days of data...`
    });

    let daysProcessed = 0;
    let totalRecordsProcessed = 0;
    let totalErrors = 0;

    // Process day by day
    const currentDate = new Date(startDateTime);
    
    while (currentDate <= endDateTime) {
      const dateStr = currentDate.toISOString().split('T')[0];
      
      try {
        // Get punch records for this specific date
        let punchQuery = `
          SELECT 
            t.emp_code,
            e.first_name,
            e.last_name,
            t.punch_time,
            t.punch_state,
            t.terminal_sn,
            t.terminal_alias,
            t.area_alias
          FROM iclock_transaction t
          LEFT JOIN personnel_employee e ON t.emp_code = e.emp_code
          WHERE CAST(t.punch_time AS DATE) = @date
        `;

        // Add terminal filter if specified
        if (bioConfig.terminal_sn) {
          punchQuery += ` AND t.terminal_sn = @terminalSn`;
        }

        punchQuery += ` ORDER BY t.punch_time ASC`;

        const request = bioSqlPool.request()
          .input('date', sql.Date, dateStr);

        if (bioConfig.terminal_sn) {
          request.input('terminalSn', sql.NVarChar, bioConfig.terminal_sn);
        }

        const result = await request.query(punchQuery);
        const punches = result.recordset;

        if (punches.length > 0) {
          // Transform punch records
          const transactionsToSync = punches.map(punch => {
            const punchDateTime = new Date(punch.punch_time);
            const employeeName = punch.last_name 
              ? `${punch.first_name} ${punch.last_name}`.trim()
              : punch.first_name;

            return {
              employee_id: punch.emp_code.toString(),
              name: employeeName,
              branch_id: bioConfig.branch_id,
              transaction_date: punchDateTime.toISOString().split('T')[0],
              transaction_time: punchDateTime.toLocaleTimeString('en-US', { 
                hour12: true, 
                hour: '2-digit', 
                minute: '2-digit' 
              }),
              punch_state: punch.punch_state === 0 ? 'Check In' : 'Check Out',
              device_id: punch.terminal_alias || punch.terminal_sn || 'Unknown',
              created_at: new Date().toISOString()
            };
          });

          // Batch insert (upsert to avoid duplicates)
          const { error: insertError } = await supabase
            .from('hr_fingerprint_transactions')
            .upsert(transactionsToSync, {
              onConflict: 'employee_id,transaction_date,transaction_time,branch_id',
              ignoreDuplicates: true
            });

          if (insertError) {
            console.error(`Error syncing ${dateStr}:`, insertError);
            totalErrors++;
          } else {
            totalRecordsProcessed += punches.length;
          }
        }

        daysProcessed++;

        // Send progress update every 10 days
        if (daysProcessed % 10 === 0 || currentDate >= endDateTime) {
          const progress = Math.round((daysProcessed / totalDays) * 100);
          
          mainWindow.webContents.send('bio-historical-progress', {
            progress: progress,
            daysProcessed: daysProcessed,
            totalDays: totalDays,
            recordsProcessed: totalRecordsProcessed
          });

          mainWindow.webContents.send('sync-log', {
            type: 'info',
            message: `⏳ Progress: ${daysProcessed}/${totalDays} days (${totalRecordsProcessed} records)`
          });
        }

      } catch (err) {
        console.error(`Error processing ${dateStr}:`, err);
        totalErrors++;
      }

      // Move to next day
      currentDate.setDate(currentDate.getDate() + 1);
    }

    // Update last sync timestamp
    await supabase
      .from('biometric_connections')
      .update({ last_sync_at: new Date().toISOString() })
      .eq('branch_id', bioConfig.branch_id)
      .eq('device_id', bioConfig.device_id);

    mainWindow.webContents.send('sync-log', {
      type: 'success',
      message: `✅ Historical sync complete! Processed ${daysProcessed} days, ${totalRecordsProcessed} records${totalErrors > 0 ? `, ${totalErrors} errors` : ''}`
    });

    return { 
      success: true, 
      daysProcessed,
      recordsProcessed: totalRecordsProcessed,
      errors: totalErrors
    };

  } catch (error) {
    console.error('Historical sync error:', error);
    mainWindow.webContents.send('sync-log', {
      type: 'error',
      message: `❌ Historical sync failed: ${error.message}`
    });
    return { success: false, error: error.message };
  }
});
```

---

## 🎨 Phase 4: Frontend Implementation (`renderer.js`)

### 4.1 Add Biometric UI Event Listeners

```javascript
// After ERP configuration code, add:

// Biometric configuration variables
let bioConfig = null;

// Show biometric section after ERP is configured
function showBiometricSection(branchName) {
  document.getElementById('biometric-section').style.display = 'block';
  document.getElementById('bio-branch-name').textContent = branchName;
}

// Test biometric connection
document.getElementById('test-bio-connection').addEventListener('click', async () => {
  const testConfig = {
    server_ip: document.getElementById('bio-server-ip').value,
    server_name: document.getElementById('bio-server-name').value,
    database_name: document.getElementById('bio-database-name').value,
    username: document.getElementById('bio-username').value,
    password: document.getElementById('bio-password').value
  };

  if (!testConfig.server_ip || !testConfig.database_name || !testConfig.username || !testConfig.password) {
    alert('Please fill in all required fields');
    return;
  }

  document.getElementById('test-bio-connection').disabled = true;
  document.getElementById('test-bio-connection').textContent = 'Testing...';

  const result = await window.api.testBioConnection(testConfig);

  if (result.success) {
    alert('✅ ' + result.message);
    document.getElementById('save-bio-config').disabled = false;
  } else {
    alert('❌ Connection failed: ' + result.error);
  }

  document.getElementById('test-bio-connection').disabled = false;
  document.getElementById('test-bio-connection').textContent = 'Test Connection';
});

// Save biometric configuration
document.getElementById('save-bio-config').addEventListener('click', async () => {
  if (!erpConfig) {
    alert('Please configure ERP first');
    return;
  }

  bioConfig = {
    branch_id: erpConfig.branch_id,
    branch_name: erpConfig.branch_name,
    server_ip: document.getElementById('bio-server-ip').value,
    server_name: document.getElementById('bio-server-name').value,
    database_name: document.getElementById('bio-database-name').value,
    username: document.getElementById('bio-username').value,
    password: document.getElementById('bio-password').value,
    terminal_sn: document.getElementById('bio-terminal-sn').value || null,
    device_id: 'desktop-' + Date.now() + '-' + Math.random().toString(36).substring(7)
  };

  const result = await window.api.saveBioConfig(bioConfig);

  if (result.success) {
    alert('✅ Biometric configuration saved!');
    document.getElementById('bio-status-text').textContent = '✅ Configured';
    document.getElementById('start-bio-sync').disabled = false;
    document.getElementById('sync-employees-now').disabled = false;
  } else {
    alert('❌ Save failed: ' + result.error);
  }
});

// Start biometric sync
document.getElementById('start-bio-sync').addEventListener('click', async () => {
  const result = await window.api.startBioSync();

  if (result.success) {
    document.getElementById('bio-status-text').textContent = '✅ Syncing...';
    document.getElementById('start-bio-sync').disabled = true;
    document.getElementById('stop-bio-sync').disabled = false;
  } else {
    alert('❌ Failed to start sync: ' + result.error);
  }
});

// Stop biometric sync
document.getElementById('stop-bio-sync').addEventListener('click', async () => {
  const result = await window.api.stopBioSync();

  if (result.success) {
    document.getElementById('bio-status-text').textContent = '⏸️ Stopped';
    document.getElementById('start-bio-sync').disabled = false;
    document.getElementById('stop-bio-sync').disabled = true;
  }
});

// Sync employees now
document.getElementById('sync-employees-now').addEventListener('click', async () => {
  document.getElementById('sync-employees-now').disabled = true;
  document.getElementById('sync-employees-now').textContent = 'Syncing...';
  
  await window.api.syncEmployeesNow();
  
  document.getElementById('sync-employees-now').disabled = false;
  document.getElementById('sync-employees-now').textContent = 'Sync Employees Now';
});

// Sync historical biometric data
document.getElementById('sync-bio-historical').addEventListener('click', async () => {
  const startDate = document.getElementById('bio-historical-start-date').value;
  
  if (!startDate) {
    alert('Please select a start date');
    return;
  }

  const confirmMsg = `This will sync all punch transactions from ${startDate} to today. This may take several minutes. Continue?`;
  if (!confirm(confirmMsg)) {
    return;
  }

  document.getElementById('sync-bio-historical').disabled = true;
  document.getElementById('sync-bio-historical').textContent = 'Syncing...';
  document.getElementById('bio-historical-progress').style.display = 'block';

  const result = await window.api.syncBioHistoricalData(startDate);

  if (result.success) {
    alert(`✅ Historical sync complete!\n\nDays processed: ${result.daysProcessed}\nRecords synced: ${result.recordsProcessed}\nErrors: ${result.errors || 0}`);
  } else {
    alert('❌ Historical sync failed: ' + result.error);
  }

  document.getElementById('sync-bio-historical').disabled = false;
  document.getElementById('sync-bio-historical').textContent = 'Sync Historical Data';
  document.getElementById('bio-historical-progress').style.display = 'none';
});

// Listen for historical sync progress
window.api.onBioHistoricalProgress((data) => {
  document.getElementById('bio-historical-progress-bar').value = data.progress;
  document.getElementById('bio-historical-progress-text').textContent = 
    `${data.progress}% - ${data.daysProcessed}/${data.totalDays} days - ${data.recordsProcessed} records`;
});
```

### 4.2 Update `preload.js`

```javascript
// Add to existing API exposure:
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('api', {
  // ... existing ERP methods ...
  
  // Biometric methods
  testBioConnection: (config) => ipcRenderer.invoke('test-bio-connection', config),
  saveBioConfig: (config) => ipcRenderer.invoke('save-bio-config', config),
  startBioSync: () => ipcRenderer.invoke('start-bio-sync'),
  stopBioSync: () => ipcRenderer.invoke('stop-bio-sync'),
  syncEmployeesNow: () => ipcRenderer.invoke('sync-employees-now'),
  syncBioHistoricalData: (startDate) => ipcRenderer.invoke('sync-bio-historical-data', startDate),
  
  // Progress listener for historical sync
  onBioHistoricalProgress: (callback) => {
    ipcRenderer.on('bio-historical-progress', (event, data) => callback(data));
  }
});
```

---

## 🧪 Phase 5: Testing

### 5.1 Test Database Connection

1. Open ERP Sync App
2. Login with access code
3. Configure ERP (existing)
4. Configure Biometric section:
   - Server IP: 192.168.0.3
   - Database: Zkurbard
   - Username: sa
   - Password: Polosys*123
5. Click "Test Connection"
6. Verify message shows employee count

### 5.2 Test Employee Sync

1. Click "Sync Employees Now"
2. Check logs for success message
3. Verify in Supabase:
```sql
SELECT * FROM hr_employees 
WHERE branch_id = 3 
ORDER BY employee_id;
```

### 5.3 Test Punch Transaction Sync

1. Click "Start Biometric Sync"
2. Wait 5 minutes for first sync
3. Check logs for synced records
4. Verify in Supabase:
```sql
SELECT * FROM hr_fingerprint_transactions 
WHERE branch_id = 3 
ORDER BY transaction_date DESC, transaction_time DESC 
LIMIT 20;
```

### 5.4 Test Terminal Filter (Optional)

1. Edit biometric config
2. Add Terminal SN: "MFP3243700773"
3. Save and restart sync
4. Verify only that terminal's punches are synced

### 5.5 Test Historical Sync

1. Stop regular biometric sync (if running)
2. Select start date (e.g., 30 days ago)
3. Click "Sync Historical Data"
4. Monitor progress bar and logs
5. Verify in Supabase:
```sql
SELECT 
  transaction_date,
  COUNT(*) as punch_count
FROM hr_fingerprint_transactions 
WHERE branch_id = 3 
GROUP BY transaction_date 
ORDER BY transaction_date DESC;
```
6. Check for records starting from selected date

**Expected Behavior:**
- Progress bar shows percentage complete
- Logs show "Processing X/Y days"
- Final message shows total days and records processed
- Can take several minutes for large date ranges

**Note:** Historical sync uses upsert with conflict handling to avoid duplicate records if run multiple times.

---

## 📦 Phase 6: Deployment

### 6.1 Build Updated App

```bash
cd erp-sync-app
npm run build
```

### 6.2 Package for Distribution

- Installer will be in `dist/` folder
- Copy `win-unpacked/` folder to branches

### 6.3 Installation Steps

1. Install on SQL Server PC
2. Configure ERP settings
3. Configure Biometric settings
4. Start both syncs
5. Monitor logs

---

## 📊 Data Flow Summary

### Employee Data Flow:
```
ZKBioTime (personnel_employee)
  ↓ emp_code, first_name, last_name
Employee Sync Function (every 30 min)
  ↓ Transform to Supabase format
Supabase (hr_employees)
  ↓ employee_id, name, branch_id
Aqura HR Interface
```

### Punch Transaction Flow:
```
ZKBioTime (iclock_transaction)
  ↓ emp_code, punch_time, punch_state, terminal_alias
Punch Sync Function (every 5 min)
  ↓ Filter by last_sync_at timestamp
  ↓ Transform date/time, map punch state
Supabase (hr_fingerprint_transactions)
  ↓ employee_id, date, time, punch_state, device_id
Aqura HR Attendance Reports
```

---

## 🎯 Success Criteria

- ✅ Biometric connections table created in Supabase
- ✅ UI shows biometric configuration section
- ✅ Can test ZKBioTime connection successfully
- ✅ Can save biometric configuration
- ✅ Employees sync from ZKBioTime to hr_employees
- ✅ Punch transactions sync to hr_fingerprint_transactions
- ✅ Historical sync with date picker works correctly
- ✅ Progress bar shows historical sync progress
- ✅ Both ERP and Biometric sync run independently
- ✅ Logs show successful sync operations
- ✅ Data visible in Aqura HR interface
- ✅ No duplicate records after multiple historical syncs

---

## 🔄 Maintenance

### Regular Tasks:
- Monitor sync logs daily
- Check for failed sync attempts
- Verify data accuracy weekly
- Update terminal_sn if devices change

### Troubleshooting:
- Connection errors: Check SQL Server is running
- No data synced: Verify last_sync_at timestamp
- Duplicate records: Check unique constraints
- Missing employees: Run manual employee sync

---

## 📝 Notes

- Employee sync runs less frequently (30 min) as employee data changes rarely
- Punch sync runs more frequently (5 min) to capture real-time attendance
- Terminal filter is optional - leave empty to sync all terminals
- Same branch_id used for both ERP and Biometric data
- Both syncs are independent and can run simultaneously
- **Historical sync processes day-by-day to avoid memory issues with large datasets**
- **Historical sync uses upsert with conflict detection to prevent duplicate records**
- **Progress updates sent every 10 days to avoid UI lag**
- **Historical sync can be interrupted and rerun from same date - will skip duplicates**
