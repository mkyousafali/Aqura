import { app, BrowserWindow, ipcMain } from 'electron';
import path from 'path';
import { fileURLToPath } from 'url';
import sql from 'mssql';
import { createClient } from '@supabase/supabase-js';
import Database from 'better-sqlite3';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

let mainWindow;
let syncInterval;
let sqlPool = null;
let config = null;
let isRunning = false;
let loggedInAccessCode = null;
let localDB = null;
let isOnline = true;
let retryQueue = [];

// Supabase client
const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';
const supabase = createClient(supabaseUrl, supabaseKey);

// Initialize local SQLite database for offline storage
function initLocalDB() {
  const dbPath = path.join(app.getPath('userData'), 'aqura-offline.db');
  localDB = new Database(dbPath);
  
  // Create offline queue table
  localDB.exec(`
    CREATE TABLE IF NOT EXISTS sync_queue (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      branch_id INTEGER NOT NULL,
      sale_date TEXT NOT NULL,
      total_bills INTEGER DEFAULT 0,
      gross_amount REAL DEFAULT 0,
      tax_amount REAL DEFAULT 0,
      discount_amount REAL DEFAULT 0,
      total_returns INTEGER DEFAULT 0,
      return_amount REAL DEFAULT 0,
      return_tax REAL DEFAULT 0,
      net_bills INTEGER DEFAULT 0,
      net_amount REAL DEFAULT 0,
      net_tax REAL DEFAULT 0,
      created_at TEXT NOT NULL,
      synced INTEGER DEFAULT 0,
      retry_count INTEGER DEFAULT 0,
      last_error TEXT
    );
    
    CREATE INDEX IF NOT EXISTS idx_synced ON sync_queue(synced);
    CREATE INDEX IF NOT EXISTS idx_date ON sync_queue(sale_date);
  `);
  
  console.log('✅ Local database initialized at:', dbPath);
}

// Check internet connectivity
async function checkInternetConnection() {
  try {
    const { data, error } = await supabase
      .from('branches')
      .select('id')
      .limit(1);
    
    const wasOffline = !isOnline;
    isOnline = !error;
    
    // If just came back online, process queue
    if (wasOffline && isOnline) {
      mainWindow?.webContents.send('sync-log', {
        type: 'success',
        message: '🌐 Internet restored! Processing queued data...'
      });
      await processOfflineQueue();
    }
    
    return isOnline;
  } catch (error) {
    isOnline = false;
    return false;
  }
}

// Process offline queue when internet returns
async function processOfflineQueue() {
  if (!localDB) return;
  
  try {
    const stmt = localDB.prepare('SELECT * FROM sync_queue WHERE synced = 0 ORDER BY created_at ASC');
    const queuedItems = stmt.all();
    
    if (queuedItems.length === 0) return;
    
    mainWindow?.webContents.send('sync-log', {
      type: 'info',
      message: `📤 Processing ${queuedItems.length} queued records...`
    });
    
    let successCount = 0;
    const updateStmt = localDB.prepare('UPDATE sync_queue SET synced = 1, last_error = NULL WHERE id = ?');
    const errorStmt = localDB.prepare('UPDATE sync_queue SET retry_count = retry_count + 1, last_error = ? WHERE id = ?');
    
    for (const item of queuedItems) {
      try {
        const salesData = {
          branch_id: item.branch_id,
          sale_date: item.sale_date,
          total_bills: item.total_bills,
          gross_amount: item.gross_amount,
          tax_amount: item.tax_amount,
          discount_amount: item.discount_amount,
          total_returns: item.total_returns,
          return_amount: item.return_amount,
          return_tax: item.return_tax,
          net_bills: item.net_bills,
          net_amount: item.net_amount,
          net_tax: item.net_tax,
          last_sync_at: new Date().toISOString()
        };
        
        const { error } = await supabase
          .from('erp_daily_sales')
          .upsert(salesData, {
            onConflict: 'branch_id,sale_date'
          });
        
        if (error) throw error;
        
        updateStmt.run(item.id);
        successCount++;
      } catch (err) {
        console.error(`Failed to sync queued item ${item.id}:`, err);
        errorStmt.run(err.message, item.id);
      }
    }
    
    mainWindow?.webContents.send('sync-log', {
      type: 'success',
      message: `✅ Synced ${successCount}/${queuedItems.length} queued records`
    });
    
    // Clean up old synced records (older than 7 days)
    const cleanupStmt = localDB.prepare(
      "DELETE FROM sync_queue WHERE synced = 1 AND created_at < date('now', '-7 days')"
    );
    cleanupStmt.run();
    
  } catch (error) {
    console.error('Error processing offline queue:', error);
  }
}

// Save data to local queue
function saveToLocalQueue(salesData) {
  if (!localDB) return;
  
  try {
    const stmt = localDB.prepare(`
      INSERT INTO sync_queue (
        branch_id, sale_date, total_bills, gross_amount, tax_amount, 
        discount_amount, total_returns, return_amount, return_tax,
        net_bills, net_amount, net_tax, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);
    
    stmt.run(
      salesData.branch_id,
      salesData.sale_date,
      salesData.total_bills,
      salesData.gross_amount,
      salesData.tax_amount,
      salesData.discount_amount,
      salesData.total_returns,
      salesData.return_amount,
      salesData.return_tax,
      salesData.net_bills,
      salesData.net_amount,
      salesData.net_tax,
      new Date().toISOString()
    );
    
    console.log('✅ Data saved to local queue for later sync');
  } catch (error) {
    console.error('Error saving to local queue:', error);
  }
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 800,
    height: 600,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js')
    },
    icon: path.join(__dirname, 'icon.png')
  });

  // Set app to run on Windows startup
  if (process.platform === 'win32') {
    app.setLoginItemSettings({
      openAtLogin: true,
      path: process.execPath,
      args: []
    });
  }

  mainWindow.loadFile('index.html');
  
  // Prevent closing without access code verification
  mainWindow.on('close', function (event) {
    if (loggedInAccessCode) {
      event.preventDefault();
      mainWindow.webContents.send('request-logout-verification');
    }
  });
  
  mainWindow.on('closed', function () {
    mainWindow = null;
  });
}

app.whenReady().then(() => {
  initLocalDB();
  createWindow();
});

app.on('window-all-closed', function () {
  if (process.platform !== 'darwin') {
    if (syncInterval) clearInterval(syncInterval);
    if (sqlPool) sqlPool.close();
    if (localDB) localDB.close();
    app.quit();
  }
});

app.on('activate', function () {
  if (mainWindow === null) createWindow();
});

// IPC Handlers

// Login with access code
ipcMain.handle('login', async (event, { accessCode }) => {
  try {
    console.log('Login attempt with access code:', accessCode);
    
    // Verify access code against users table
    const { data: users, error } = await supabase
      .from('users')
      .select('id, username, role_type, quick_access_code, status')
      .eq('quick_access_code', accessCode)
      .eq('status', 'active');

    console.log('Query result:', { users, error });

    if (error) {
      console.error('Database error:', error);
      throw new Error('Database error: ' + error.message);
    }

    if (!users || users.length === 0) {
      throw new Error('Invalid access code or inactive user');
    }

    console.log('Login successful for user:', users[0].username);
    loggedInAccessCode = accessCode; // Store for logout verification
    return { success: true, user: users[0] };
  } catch (error) {
    console.error('Login error:', error);
    return { success: false, error: error.message };
  }
});

// Verify logout access code
ipcMain.handle('verify-logout', async (event, { accessCode }) => {
  try {
    if (accessCode === loggedInAccessCode) {
      loggedInAccessCode = null; // Clear access code
      if (syncInterval) clearInterval(syncInterval);
      if (sqlPool) await sqlPool.close();
      return { success: true };
    } else {
      return { success: false, error: 'Invalid access code' };
    }
  } catch (error) {
    return { success: false, error: error.message };
  }
});

// Force close application (after successful verification)
ipcMain.handle('force-close', async () => {
  loggedInAccessCode = null; // Ensure it's cleared
  mainWindow.destroy(); // Force close without triggering close event
  app.quit();
  return { success: true };
});

// Get auto-start status
ipcMain.handle('get-autostart-status', async () => {
  if (process.platform !== 'win32') {
    return { success: false, enabled: false, message: 'Auto-start only available on Windows' };
  }
  
  const settings = app.getLoginItemSettings();
  return { success: true, enabled: settings.openAtLogin };
});

// Set auto-start
ipcMain.handle('set-autostart', async (event, { enabled }) => {
  if (process.platform !== 'win32') {
    return { success: false, error: 'Auto-start only available on Windows' };
  }
  
  try {
    app.setLoginItemSettings({
      openAtLogin: enabled,
      path: process.execPath,
      args: []
    });
    
    return { success: true, enabled };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

// Load branches from Supabase
ipcMain.handle('load-branches', async () => {
  try {
    const { data, error } = await supabase
      .from('branches')
      .select('*')
      .order('name_en');

    if (error) throw error;
    return { success: true, branches: data };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

// Save configuration
ipcMain.handle('save-config', async (event, configData) => {
  try {
    // Check if a connection already exists for this branch and device
    const { data: existing } = await supabase
      .from('erp_connections')
      .select('id')
      .eq('branch_id', configData.branch_id)
      .eq('device_id', configData.device_id)
      .single();

    let result;
    if (existing) {
      // Update existing record
      result = await supabase
        .from('erp_connections')
        .update({
          branch_name: configData.branch_name,
          server_ip: configData.server_ip,
          server_name: configData.server_name,
          database_name: configData.database_name,
          username: configData.username,
          password: configData.password,
          is_active: true,
          updated_at: new Date().toISOString()
        })
        .eq('id', existing.id)
        .select()
        .single();
    } else {
      // Insert new record
      result = await supabase
        .from('erp_connections')
        .insert({
          branch_id: configData.branch_id,
          branch_name: configData.branch_name,
          server_ip: configData.server_ip,
          server_name: configData.server_name,
          database_name: configData.database_name,
          username: configData.username,
          password: configData.password,
          device_id: configData.device_id,
          is_active: true
        })
        .select()
        .single();
    }

    if (result.error) throw result.error;

    config = configData;
    return { success: true, config: result.data };
  } catch (error) {
    console.error('Save config error:', error);
    return { success: false, error: error.message };
  }
});

// Test SQL Server connection
ipcMain.handle('test-connection', async (event, testConfig) => {
  try {
    const sqlConfig = {
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

    const pool = await sql.connect(sqlConfig);
    await pool.close();

    return { success: true };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

// Sync historical data
ipcMain.handle('sync-historical-data', async () => {
  if (!config) {
    return { success: false, error: 'No configuration set' };
  }

  try {
    mainWindow.webContents.send('sync-log', {
      type: 'info',
      message: '🔄 Starting historical data sync...'
    });

    // Initialize SQL connection if not already connected
    if (!sqlPool) {
      const sqlConfig = {
        server: config.server_ip,
        database: config.database_name,
        user: config.username,
        password: config.password,
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
      sqlPool = await sql.connect(sqlConfig);
    }

    // Get date range from SQL Server
    const dateRangeQuery = `
      SELECT 
        MIN(CAST(TransactionDate AS DATE)) AS FirstDate,
        MAX(CAST(TransactionDate AS DATE)) AS LastDate
      FROM InvTransactionMaster
      WHERE VoucherType = 'SI'
    `;

    const dateRangeResult = await sqlPool.request().query(dateRangeQuery);
    const { FirstDate, LastDate } = dateRangeResult.recordset[0];

    if (!FirstDate || !LastDate) {
      return { success: false, error: 'No sales data found in ERP system' };
    }

    mainWindow.webContents.send('sync-log', {
      type: 'info',
      message: `📅 Found data from ${FirstDate.toISOString().split('T')[0]} to ${LastDate.toISOString().split('T')[0]}`
    });

    // Sync data for each date
    let daysProcessed = 0;
    let recordsProcessed = 0;
    const currentDate = new Date(FirstDate);
    const endDate = new Date(LastDate);

    while (currentDate <= endDate) {
      const dateStr = currentDate.toISOString().split('T')[0];
      
      try {
        await syncDateData(dateStr);
        daysProcessed++;
        recordsProcessed++;

        if (daysProcessed % 10 === 0) {
          mainWindow.webContents.send('sync-log', {
            type: 'info',
            message: `⏳ Processed ${daysProcessed} days...`
          });
        }
      } catch (err) {
        console.error(`Error syncing ${dateStr}:`, err);
      }

      currentDate.setDate(currentDate.getDate() + 1);
    }

    mainWindow.webContents.send('sync-log', {
      type: 'success',
      message: `✅ Historical sync complete! Synced ${daysProcessed} days`
    });

    return { 
      success: true, 
      daysProcessed,
      recordsProcessed 
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

// Start sync service
ipcMain.handle('start-sync', async () => {
  if (!config) {
    return { success: false, error: 'No configuration set' };
  }

  try {
    // Initialize SQL connection
    const sqlConfig = {
      server: config.server_ip,
      database: config.database_name,
      user: config.username,
      password: config.password,
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

    sqlPool = await sql.connect(sqlConfig);

    // Start syncing every 10 seconds (today and yesterday)
    syncInterval = setInterval(async () => {
      await performSync();
    }, 10000);

    // Perform initial sync
    await performSync();

    return { success: true, message: 'Sync started successfully' };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

// Stop sync service
ipcMain.handle('stop-sync', async () => {
  if (syncInterval) {
    clearInterval(syncInterval);
    syncInterval = null;
  }

  if (sqlPool) {
    await sqlPool.close();
    sqlPool = null;
  }

  return { success: true, message: 'Sync stopped' };
});

// Get sync status
ipcMain.handle('get-status', async () => {
  return {
    isRunning: syncInterval !== null,
    config: config
  };
});

// Helper function to sync data for a specific date
async function syncDateData(dateStr) {
  if (!sqlPool || !config) return;

  // Get sales data from SQL Server
  const salesQuery = `
    SELECT 
      COALESCE(COUNT(*), 0) AS TotalBills,
      COALESCE(SUM(CAST([GrandTotal] AS DECIMAL(18,2))), 0) AS GrossAmount,
      COALESCE(SUM(CAST([VatAmount] AS DECIMAL(18,2))), 0) AS TaxAmount,
      COALESCE(SUM(CAST([TotalDiscount] AS DECIMAL(18,2))), 0) AS DiscountAmount
    FROM [dbo].[InvTransactionMaster]
    WHERE [VoucherType] = 'SI'
    AND CAST([TransactionDate] AS DATE) = @date
  `;

  const salesResult = await sqlPool.request()
    .input('date', sql.Date, dateStr)
    .query(salesQuery);

  const returnsQuery = `
    SELECT 
      COALESCE(COUNT(*), 0) AS TotalReturns,
      COALESCE(SUM(CAST([GrandTotal] AS DECIMAL(18,2))), 0) AS ReturnAmount,
      COALESCE(SUM(CAST([VatAmount] AS DECIMAL(18,2))), 0) AS ReturnTax
    FROM [dbo].[InvTransactionMaster]
    WHERE [VoucherType] = 'SR'
    AND CAST([TransactionDate] AS DATE) = @date
  `;

  const returnsResult = await sqlPool.request()
    .input('date', sql.Date, dateStr)
    .query(returnsQuery);

  const sales = salesResult.recordset[0];
  const returns = returnsResult.recordset[0];

  const salesData = {
    branch_id: config.branch_id,
    sale_date: dateStr,
    total_bills: sales.TotalBills,
    gross_amount: sales.GrossAmount,
    tax_amount: sales.TaxAmount,
    discount_amount: sales.DiscountAmount,
    total_returns: returns.TotalReturns,
    return_amount: returns.ReturnAmount,
    return_tax: returns.ReturnTax,
    net_bills: sales.TotalBills - returns.TotalReturns,
    net_amount: sales.GrossAmount - returns.ReturnAmount,
    net_tax: sales.TaxAmount - returns.ReturnTax,
    last_sync_at: new Date().toISOString()
  };

  // Try to sync to Supabase, fallback to local queue if offline
  try {
    // Check if online first
    await checkInternetConnection();
    
    if (isOnline) {
      const { error } = await supabase
        .from('erp_daily_sales')
        .upsert(salesData, {
          onConflict: 'branch_id,sale_date'
        });

      if (error) throw error;
    } else {
      // Save to local queue when offline
      saveToLocalQueue(salesData);
      mainWindow?.webContents.send('sync-log', {
        type: 'info',
        message: '📥 Offline mode - data saved locally'
      });
    }
  } catch (error) {
    // If sync fails, save to local queue
    isOnline = false;
    saveToLocalQueue(salesData);
    mainWindow?.webContents.send('sync-log', {
      type: 'info',
      message: '⚠️ Sync failed - data queued for retry'
    });
  }
  
  return salesData;
}

// Sync function (syncs today and yesterday)
async function performSync() {
  if (isRunning || !sqlPool || !config) return;

  isRunning = true;
  const startTime = Date.now();

  try {
    const today = new Date();
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);

    const todayStr = today.toISOString().split('T')[0];
    const yesterdayStr = yesterday.toISOString().split('T')[0];

    // Check internet connectivity
    await checkInternetConnection();
    
    const statusIcon = isOnline ? '🌐' : '📡';
    const statusText = isOnline ? 'Online' : 'Offline';

    // Log to renderer
    mainWindow.webContents.send('sync-log', {
      type: 'info',
      message: `${statusIcon} ${statusText} - Syncing ${todayStr} and ${yesterdayStr}...`
    });

    // Sync today
    const todayData = await syncDateData(todayStr);
    
    // Sync yesterday
    const yesterdayData = await syncDateData(yesterdayStr);

    const duration = Date.now() - startTime;
    
    const queueInfo = localDB ? localDB.prepare('SELECT COUNT(*) as count FROM sync_queue WHERE synced = 0').get() : { count: 0 };
    const queueText = queueInfo.count > 0 ? ` [${queueInfo.count} queued]` : '';
    
    mainWindow.webContents.send('sync-log', {
      type: 'success',
      message: `${statusIcon} ${statusText} - Synced in ${duration}ms - Today: ${todayData.net_bills} bills (${todayData.net_amount.toFixed(2)}), Yesterday: ${yesterdayData.net_bills} bills${queueText}`
    });

  } catch (error) {
    mainWindow.webContents.send('sync-log', {
      type: 'error',
      message: `Sync failed: ${error.message}`
    });
  } finally {
    isRunning = false;
  }
}
