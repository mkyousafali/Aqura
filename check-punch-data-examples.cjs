const sql = require('mssql');

const config = {
    user: 'sa',
    password: 'Polosys*123',
    server: 'WIN-D1D6EN8240A',
    database: 'Zkurbard',
    options: {
        encrypt: false,
        trustServerCertificate: true,
        connectTimeout: 30000
    }
};

async function showPunchDataExamples() {
    try {
        console.log('Connecting to Zkurbard database...');
        console.log('-----------------------------------\n');

        const pool = await sql.connect(config);
        console.log('✅ Connected successfully!\n');

        // Check if iclock_transaction table exists
        const tableCheck = await pool.request().query(`
            SELECT COUNT(*) as tableExists 
            FROM INFORMATION_SCHEMA.TABLES 
            WHERE TABLE_NAME = 'iclock_transaction'
        `);

        if (tableCheck.recordset[0].tableExists === 0) {
            console.log('❌ Table "iclock_transaction" not found in this database.');
            await pool.close();
            return;
        }

        // Get total punch records count
        const countResult = await pool.request().query(`
            SELECT COUNT(*) as total_punches FROM iclock_transaction
        `);
        console.log(`📊 Total Punch Records: ${countResult.recordset[0].total_punches}\n`);

        // Get latest 10 punch records
        console.log('📋 LATEST 10 PUNCH RECORDS:');
        console.log('='.repeat(100));
        const latestPunches = await pool.request().query(`
            SELECT TOP 10 
                emp_code,
                punch_time,
                punch_state,
                verify_type,
                work_code,
                terminal_sn,
                terminal_alias,
                area_alias,
                longitude,
                latitude,
                gps_location
            FROM iclock_transaction
            ORDER BY punch_time DESC
        `);

        if (latestPunches.recordset.length > 0) {
            latestPunches.recordset.forEach((punch, index) => {
                console.log(`\n${index + 1}. Employee Code: ${punch.emp_code}`);
                console.log(`   Punch Time: ${punch.punch_time}`);
                console.log(`   Punch State: ${punch.punch_state} (${getPunchStateLabel(punch.punch_state)})`);
                console.log(`   Verify Type: ${punch.verify_type || 'N/A'} (${getVerifyTypeLabel(punch.verify_type)})`);
                console.log(`   Work Code: ${punch.work_code || 'N/A'}`);
                console.log(`   Terminal: ${punch.terminal_alias || punch.terminal_sn || 'N/A'}`);
                console.log(`   Area: ${punch.area_alias || 'N/A'}`);
                console.log(`   GPS: ${punch.gps_location || 'N/A'}`);
                if (punch.latitude && punch.longitude) {
                    console.log(`   Coordinates: ${punch.latitude}, ${punch.longitude}`);
                }
                console.log('-'.repeat(100));
            });
        } else {
            console.log('No punch records found.');
        }

        // Get today's punch records
        console.log('\n\n📅 TODAY\'S PUNCH RECORDS:');
        console.log('='.repeat(100));
        const todayPunches = await pool.request().query(`
            SELECT 
                emp_code,
                punch_time,
                punch_state,
                terminal_alias
            FROM iclock_transaction
            WHERE CAST(punch_time AS DATE) = CAST(GETDATE() AS DATE)
            ORDER BY punch_time DESC
        `);

        if (todayPunches.recordset.length > 0) {
            console.log(`Found ${todayPunches.recordset.length} punches today:\n`);
            todayPunches.recordset.forEach((punch, index) => {
                const timeStr = new Date(punch.punch_time).toLocaleTimeString('en-US', { 
                    hour: '2-digit', 
                    minute: '2-digit',
                    hour12: true 
                });
                console.log(`${index + 1}. Emp ${punch.emp_code} - ${timeStr} - ${getPunchStateLabel(punch.punch_state)} - Terminal: ${punch.terminal_alias || 'N/A'}`);
            });
        } else {
            console.log('No punch records found for today.');
        }

        // Get punch statistics by employee (top 10 most active)
        console.log('\n\n📊 TOP 10 EMPLOYEES BY PUNCH COUNT (LAST 7 DAYS):');
        console.log('='.repeat(100));
        const empStats = await pool.request().query(`
            SELECT TOP 10
                t.emp_code,
                e.first_name,
                e.last_name,
                COUNT(*) as total_punches,
                MIN(t.punch_time) as first_punch,
                MAX(t.punch_time) as last_punch
            FROM iclock_transaction t
            LEFT JOIN personnel_employee e ON t.emp_code = e.emp_code
            WHERE t.punch_time >= DATEADD(day, -7, GETDATE())
            GROUP BY t.emp_code, e.first_name, e.last_name
            ORDER BY total_punches DESC
        `);

        if (empStats.recordset.length > 0) {
            empStats.recordset.forEach((emp, index) => {
                const name = emp.first_name ? `${emp.first_name} ${emp.last_name || ''}`.trim() : 'N/A';
                console.log(`\n${index + 1}. Employee: ${emp.emp_code} - ${name}`);
                console.log(`   Total Punches: ${emp.total_punches}`);
                console.log(`   First Punch: ${emp.first_punch}`);
                console.log(`   Last Punch: ${emp.last_punch}`);
            });
        }

        // Get punch state distribution
        console.log('\n\n📊 PUNCH STATE DISTRIBUTION (LAST 30 DAYS):');
        console.log('='.repeat(100));
        const stateStats = await pool.request().query(`
            SELECT 
                punch_state,
                COUNT(*) as count
            FROM iclock_transaction
            WHERE punch_time >= DATEADD(day, -30, GETDATE())
            GROUP BY punch_state
            ORDER BY count DESC
        `);

        if (stateStats.recordset.length > 0) {
            stateStats.recordset.forEach((state) => {
                console.log(`${getPunchStateLabel(state.punch_state)}: ${state.count} records`);
            });
        }

        // Get available columns in iclock_transaction table
        console.log('\n\n📋 AVAILABLE COLUMNS IN iclock_transaction TABLE:');
        console.log('='.repeat(100));
        const columns = await pool.request().query(`
            SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_NAME = 'iclock_transaction'
            ORDER BY ORDINAL_POSITION
        `);

        columns.recordset.forEach((col) => {
            console.log(`• ${col.COLUMN_NAME} (${col.DATA_TYPE}) ${col.IS_NULLABLE === 'YES' ? '- Nullable' : '- Required'}`);
        });

        await pool.close();
        console.log('\n\n✅ Query completed successfully!');

    } catch (err) {
        console.error('❌ Error:', err.message);
        console.error('\nFull error details:', err);
    }
}

function getPunchStateLabel(state) {
    const states = {
        '0': 'Check In',
        '1': 'Check Out',
        '2': 'Break Out',
        '3': 'Break In',
        '4': 'OT In',
        '5': 'OT Out',
        'I': 'In',
        'O': 'Out'
    };
    return states[state] || `Unknown (${state})`;
}

function getVerifyTypeLabel(type) {
    const types = {
        '0': 'Password',
        '1': 'Fingerprint',
        '2': 'Card',
        '3': 'Palm',
        '4': 'Face',
        '15': 'Face + Fingerprint',
        '16': 'Face + Password',
        '17': 'Face + Card'
    };
    return types[type] || 'Unknown';
}

showPunchDataExamples();
