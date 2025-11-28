const sql = require('mssql');

const config = {
    user: 'sa',
    password: 'Polosys*123',
    server: 'WIN-D1D6EN8240A',
    database: 'Zkurbard',
    options: {
        encrypt: false,
        trustServerCertificate: true
    }
};

async function checkDeviceInfo() {
    try {
        console.log('🔍 Connecting to Zkurbard database...\n');
        const pool = await sql.connect(config);
        
        // Check iclock_transaction table for device/terminal info
        console.log('📊 TABLE: iclock_transaction');
        console.log('=' .repeat(80));
        
        const transactionResult = await pool.request().query(`
            SELECT TOP 5
                emp_code as 'Employee ID',
                punch_time as 'Punch Time',
                punch_state as 'Punch State',
                terminal_sn as 'Terminal Serial Number',
                terminal_alias as 'Terminal Alias',
                area_alias as 'Area Alias',
                verify_type as 'Verify Type',
                work_code as 'Work Code'
            FROM iclock_transaction
            ORDER BY punch_time DESC
        `);
        
        console.log('\n📌 PUNCH TRANSACTION COLUMNS (5 examples):\n');
        transactionResult.recordset.forEach((row, index) => {
            console.log(`${index + 1}. Employee ID: ${row['Employee ID']}`);
            console.log(`   Punch Time: ${row['Punch Time']}`);
            console.log(`   Punch State: ${row['Punch State']}`);
            console.log(`   Terminal SN: ${row['Terminal Serial Number'] || 'NULL'}`);
            console.log(`   Terminal Alias: ${row['Terminal Alias'] || 'NULL'}`);
            console.log(`   Area Alias: ${row['Area Alias'] || 'NULL'}`);
            console.log(`   Verify Type: ${row['Verify Type']}`);
            console.log(`   Work Code: ${row['Work Code'] || 'NULL'}`);
            console.log('-'.repeat(80));
        });
        
        // Check iclock_terminal table for device registry
        console.log('\n📊 TABLE: iclock_terminal (Device Registry)');
        console.log('=' .repeat(80));
        
        const terminalResult = await pool.request().query(`
            SELECT 
                id,
                sn as 'Serial Number',
                alias as 'Device Name',
                ip_address as 'IP Address',
                terminal_model as 'Model',
                area_alias as 'Area'
            FROM iclock_terminal
        `);
        
        if (terminalResult.recordset.length > 0) {
            console.log('\n📌 REGISTERED DEVICES:\n');
            terminalResult.recordset.forEach((device, index) => {
                console.log(`${index + 1}. Device ID: ${device.id}`);
                console.log(`   Serial Number: ${device['Serial Number']}`);
                console.log(`   Device Name: ${device['Device Name'] || 'N/A'}`);
                console.log(`   IP Address: ${device['IP Address'] || 'N/A'}`);
                console.log(`   Model: ${device['Model'] || 'N/A'}`);
                console.log(`   Area: ${device['Area'] || 'N/A'}`);
                console.log('-'.repeat(80));
            });
        } else {
            console.log('\n⚠️  No devices registered in iclock_terminal table');
        }
        
        // Summary
        console.log('\n✅ DEVICE ID STORAGE LOCATIONS:');
        console.log('   1. iclock_transaction.terminal_sn     → Terminal Serial Number');
        console.log('   2. iclock_transaction.terminal_alias  → Terminal Display Name');
        console.log('   3. iclock_terminal.sn                 → Device Serial Number (Registry)');
        console.log('   4. iclock_terminal.alias              → Device Alias/Name (Registry)');
        console.log('   5. iclock_terminal.id                 → Internal Device ID');
        
        await pool.close();
    } catch (err) {
        console.error('❌ Error:', err.message);
    }
}

checkDeviceInfo();
