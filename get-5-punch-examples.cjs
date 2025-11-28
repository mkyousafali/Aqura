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

async function get5PunchExamples() {
    try {
        console.log('Connecting to Zkurbard database...\n');

        const pool = await sql.connect(config);
        
        // Get 5 latest punch records
        const result = await pool.request().query(`
            SELECT TOP 5
                t.emp_code,
                e.first_name,
                CONVERT(VARCHAR(10), t.punch_time, 120) as punch_date,
                CONVERT(VARCHAR(8), t.punch_time, 108) as punch_time,
                CASE 
                    WHEN t.punch_state = '0' THEN 'Check In'
                    WHEN t.punch_state = '1' THEN 'Check Out'
                    WHEN t.punch_state = '2' THEN 'Break Out'
                    WHEN t.punch_state = '3' THEN 'Break In'
                    WHEN t.punch_state = 'I' THEN 'In'
                    WHEN t.punch_state = 'O' THEN 'Out'
                    ELSE t.punch_state
                END as punch_state_label
            FROM iclock_transaction t
            LEFT JOIN personnel_employee e ON t.emp_code = e.emp_code
            ORDER BY t.punch_time DESC
        `);

        console.log('┌─────────────┬──────────────────────┬────────────┬──────────┬─────────────┐');
        console.log('│ Employee ID │ First Name           │ Date       │ Time     │ Punch State │');
        console.log('├─────────────┼──────────────────────┼────────────┼──────────┼─────────────┤');

        result.recordset.forEach((record) => {
            const empId = String(record.emp_code || '').padEnd(11);
            const firstName = String(record.first_name || 'N/A').padEnd(20);
            const date = String(record.punch_date || '').padEnd(10);
            const time = String(record.punch_time || '').padEnd(8);
            const punchState = String(record.punch_state_label || '').padEnd(11);
            
            console.log(`│ ${empId} │ ${firstName} │ ${date} │ ${time} │ ${punchState} │`);
        });

        console.log('└─────────────┴──────────────────────┴────────────┴──────────┴─────────────┘');

        await pool.close();

    } catch (err) {
        console.error('❌ Error:', err.message);
    }
}

get5PunchExamples();
