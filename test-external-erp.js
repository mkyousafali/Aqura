// Test ERP SQL Server Connection from External Network
// Usage: node test-external-erp.js [PUBLIC_IP] [PORT]

import sql from 'mssql';
import { readFileSync } from 'fs';

// Default to local IP for testing, override with command line args
const serverIP = process.argv[2] || '192.168.0.3';
const serverPort = parseInt(process.argv[3]) || 1433;

console.log('=== Testing ERP SQL Server Connection ===\n');
console.log(`Server: ${serverIP}:${serverPort}`);
console.log(`Database: URBAN2_2025`);
console.log(`User: sa\n`);

const config = {
    user: 'sa',
    password: 'Polosys*123',
    server: serverIP,
    port: serverPort,
    database: 'URBAN2_2025',
    options: {
        encrypt: true,
        trustServerCertificate: true,
        enableArithAbort: true,
        connectionTimeout: 30000,
        requestTimeout: 30000
    },
    pool: {
        max: 10,
        min: 0,
        idleTimeoutMillis: 30000
    }
};

async function testConnection() {
    let pool = null;
    
    try {
        console.log('Attempting connection...');
        const startTime = Date.now();
        
        pool = await sql.connect(config);
        const connectionTime = Date.now() - startTime;
        
        console.log(`✅ Connected successfully! (${connectionTime}ms)\n`);
        
        // Test 1: Get SQL Server version
        console.log('Test 1: Getting SQL Server version...');
        const versionResult = await pool.request().query('SELECT @@VERSION AS version');
        console.log('Version:', versionResult.recordset[0].version.split('\n')[0]);
        console.log('✅ Version query successful\n');
        
        // Test 2: Get database name
        console.log('Test 2: Getting database name...');
        const dbResult = await pool.request().query('SELECT DB_NAME() AS database_name');
        console.log('Database:', dbResult.recordset[0].database_name);
        console.log('✅ Database query successful\n');
        
        // Test 3: Test actual sales query
        console.log('Test 3: Testing sales query...');
        const today = new Date().toISOString().split('T')[0];
        
        const salesQuery = `
            SELECT 
                COALESCE(SUM(CAST([Debit] AS DECIMAL(18,2))), 0) AS TotalSales
            FROM [dbo].[TrVoucher]
            WHERE [VouType] = 'SI'
            AND CAST([VouDate] AS DATE) = @date
        `;
        
        const salesResult = await pool.request()
            .input('date', sql.Date, today)
            .query(salesQuery);
        
        const totalSales = salesResult.recordset[0].TotalSales;
        console.log(`Total Sales for ${today}: ₹${totalSales.toLocaleString()}`);
        console.log('✅ Sales query successful\n');
        
        // Test 4: Connection pool status
        console.log('Test 4: Connection pool status...');
        console.log('Pool size:', pool.size);
        console.log('Pool available:', pool.available);
        console.log('Pool pending:', pool.pending);
        console.log('✅ Pool status retrieved\n');
        
        console.log('=== All Tests Passed ===');
        console.log('✅ Connection is working properly');
        console.log('✅ Database queries are executing');
        console.log('✅ Ready for production use\n');
        
        return true;
        
    } catch (err) {
        console.error('\n❌ Connection Test Failed\n');
        console.error('Error Details:');
        console.error(`  Type: ${err.name}`);
        console.error(`  Message: ${err.message}`);
        console.error(`  Code: ${err.code || 'N/A'}`);
        
        if (err.code === 'ETIMEOUT' || err.code === 'ESOCKET') {
            console.error('\n💡 Troubleshooting Tips:');
            console.error('  1. Check if SQL Server is running');
            console.error('  2. Verify TCP/IP is enabled in SQL Server Configuration');
            console.error('  3. Check Windows Firewall allows port ' + serverPort);
            console.error('  4. Verify router port forwarding is configured');
            console.error('  5. Test from external network (not same LAN)');
        } else if (err.code === 'ELOGIN') {
            console.error('\n💡 Authentication Error:');
            console.error('  1. Verify username and password are correct');
            console.error('  2. Check SQL Server authentication mode (Mixed Mode)');
            console.error('  3. Ensure sa account is enabled');
        }
        
        console.error('\n📋 Current Configuration:');
        console.error(`  Server: ${serverIP}:${serverPort}`);
        console.error(`  Database: URBAN2_2025`);
        console.error(`  User: sa`);
        console.error(`  Encrypt: true`);
        
        return false;
        
    } finally {
        if (pool) {
            try {
                await pool.close();
                console.log('\n🔌 Connection closed');
            } catch (closeErr) {
                console.error('Error closing connection:', closeErr.message);
            }
        }
    }
}

// Run the test
console.log('Starting connection test...\n');
testConnection()
    .then(success => {
        process.exit(success ? 0 : 1);
    })
    .catch(err => {
        console.error('Unexpected error:', err);
        process.exit(1);
    });
