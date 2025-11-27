// ERP Sales Sync Service
// Run this on the SQL Server machine (192.168.0.3)
// Syncs sales data to Supabase every minute

import sql from 'mssql';
import { createClient } from '@supabase/supabase-js';

// Supabase credentials (hardcoded for service)
const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

// SQL Server configuration (local connection)
const sqlConfig = {
  user: 'sa',
  password: 'Polosys*123',
  server: '192.168.0.3', // Local SQL Server
  port: 1433,
  database: 'URBAN2_2025',
  options: {
    encrypt: true,
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

let sqlPool = null;
let isRunning = false;

// Initialize SQL connection pool
async function initSqlPool() {
  try {
    console.log('🔌 Connecting to SQL Server...');
    sqlPool = await sql.connect(sqlConfig);
    console.log('✅ Connected to URBAN2_2025 database');
    return true;
  } catch (err) {
    console.error('❌ SQL Server connection failed:', err.message);
    return false;
  }
}

// Get sales data for a specific date
async function getSalesData(date) {
  try {
    // Query for sales (SI vouchers)
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
      .input('date', sql.Date, date)
      .query(salesQuery);

    // Query for returns (SR vouchers)
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
      .input('date', sql.Date, date)
      .query(returnsQuery);

    const sales = salesResult.recordset[0];
    const returns = returnsResult.recordset[0];

    return {
      date: date,
      total_bills: sales.TotalBills,
      gross_amount: sales.GrossAmount,
      tax_amount: sales.TaxAmount,
      discount_amount: sales.DiscountAmount,
      total_returns: returns.TotalReturns,
      return_amount: returns.ReturnAmount,
      return_tax: returns.ReturnTax,
      net_bills: sales.TotalBills - returns.TotalReturns,
      net_amount: sales.GrossAmount - returns.ReturnAmount,
      net_tax: sales.TaxAmount - returns.ReturnTax
    };
  } catch (err) {
    console.error('❌ Error fetching sales data:', err.message);
    throw err;
  }
}

// Sync sales data to Supabase
async function syncSalesToSupabase(salesData) {
  try {
    const { error } = await supabase
      .from('erp_daily_sales')
      .upsert({
        branch_id: 3, // Urban Market (Araidah)
        sale_date: salesData.date,
        total_bills: salesData.total_bills,
        gross_amount: salesData.gross_amount,
        tax_amount: salesData.tax_amount,
        discount_amount: salesData.discount_amount,
        total_returns: salesData.total_returns,
        return_amount: salesData.return_amount,
        return_tax: salesData.return_tax,
        net_bills: salesData.net_bills,
        net_amount: salesData.net_amount,
        net_tax: salesData.net_tax,
        last_sync_at: new Date().toISOString()
      }, {
        onConflict: 'branch_id,sale_date'
      });

    if (error) throw error;
    return true;
  } catch (err) {
    console.error('❌ Error syncing to Supabase:', err.message);
    throw err;
  }
}

// Main sync function
async function performSync() {
  if (isRunning) {
    console.log('⏭️  Previous sync still running, skipping...');
    return;
  }

  isRunning = true;
  const startTime = Date.now();

  try {
    // Get today's date
    const today = new Date().toISOString().split('T')[0];
    
    console.log(`\n⏰ [${new Date().toLocaleTimeString()}] Starting sync for ${today}...`);

    // Fetch sales data from SQL Server
    const salesData = await getSalesData(today);
    
    console.log(`💰 Sales: ${salesData.net_bills} bills, ₹${salesData.net_amount.toLocaleString()}`);

    // Sync to Supabase
    await syncSalesToSupabase(salesData);

    const duration = Date.now() - startTime;
    console.log(`✅ Sync completed in ${duration}ms`);

  } catch (err) {
    console.error('❌ Sync failed:', err.message);
  } finally {
    isRunning = false;
  }
}

// Start the service
async function startService() {
  console.log('🚀 ERP Sales Sync Service Starting...');
  console.log('📊 Database: URBAN2_2025');
  console.log('🔄 Sync Interval: Every 1 minute');
  console.log('📍 Branch: Urban Market (Araidah) - Branch ID 3');
  console.log('');

  // Initialize SQL connection
  const connected = await initSqlPool();
  if (!connected) {
    console.error('❌ Failed to connect to SQL Server. Exiting...');
    process.exit(1);
  }

  // Perform initial sync
  await performSync();

  // Schedule sync every 1 minute (60000ms)
  setInterval(performSync, 60000);

  console.log('\n✅ Service is running. Press Ctrl+C to stop.');
}

// Handle graceful shutdown
process.on('SIGINT', async () => {
  console.log('\n\n🛑 Shutting down service...');
  
  if (sqlPool) {
    await sqlPool.close();
    console.log('🔌 SQL Server connection closed');
  }
  
  console.log('👋 Goodbye!');
  process.exit(0);
});

// Handle uncaught errors
process.on('unhandledRejection', (err) => {
  console.error('❌ Unhandled error:', err);
});

// Start the service
startService().catch(err => {
  console.error('❌ Service failed to start:', err);
  process.exit(1);
});
