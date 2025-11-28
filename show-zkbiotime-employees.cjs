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

async function showEmployeeData() {
    try {
        console.log('🔍 Connecting to Zkurbard database...\n');
        const pool = await sql.connect(config);
        
        // Get 5 employee examples with ID and First Name
        const result = await pool.request().query(`
            SELECT TOP 5
                emp_code as 'Employee ID',
                first_name as 'First Name',
                last_name as 'Last Name',
                email as 'Email',
                hire_date as 'Hire Date'
            FROM personnel_employee
            ORDER BY emp_code
        `);
        
        console.log('📋 TABLE: personnel_employee');
        console.log('📌 KEY COLUMNS: emp_code (Employee ID), first_name (First Name)\n');
        console.log('=' .repeat(80));
        
        if (result.recordset.length > 0) {
            console.log('5 EXAMPLE EMPLOYEES:\n');
            
            result.recordset.forEach((emp, index) => {
                console.log(`${index + 1}. Employee ID: ${emp['Employee ID']}`);
                console.log(`   First Name:   ${emp['First Name']}`);
                console.log(`   Last Name:    ${emp['Last Name'] || 'N/A'}`);
                console.log(`   Email:        ${emp['Email'] || 'N/A'}`);
                console.log(`   Hire Date:    ${emp['Hire Date'] ? emp['Hire Date'].toISOString().split('T')[0] : 'N/A'}`);
                console.log('-'.repeat(80));
            });
            
            console.log('\n✅ Employee data is stored in: personnel_employee table');
            console.log('📊 Column Names:');
            console.log('   - emp_code     → Employee ID (unique identifier)');
            console.log('   - first_name   → Employee First Name');
            console.log('   - last_name    → Employee Last Name');
        } else {
            console.log('⚠️  No employees found in database');
        }
        
        await pool.close();
    } catch (err) {
        console.error('❌ Error:', err.message);
    }
}

showEmployeeData();
