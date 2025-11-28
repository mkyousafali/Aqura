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

async function checkEmployees() {
    try {
        console.log('Connecting to SQL Server...');
        console.log(`Server: ${config.server}`);
        console.log(`Database: ${config.database}`);
        console.log('-----------------------------------\n');

        const pool = await sql.connect(config);
        console.log('✅ Connected successfully!\n');

        // Check if personnel_employee table exists
        const tableCheck = await pool.request().query(`
            SELECT COUNT(*) as tableExists 
            FROM INFORMATION_SCHEMA.TABLES 
            WHERE TABLE_NAME = 'personnel_employee'
        `);

        if (tableCheck.recordset[0].tableExists === 0) {
            console.log('❌ Table "personnel_employee" not found.');
            console.log('\nLet me check what tables exist in this database...\n');

            const tables = await pool.request().query(`
                SELECT TABLE_NAME 
                FROM INFORMATION_SCHEMA.TABLES 
                WHERE TABLE_TYPE = 'BASE TABLE'
                ORDER BY TABLE_NAME
            `);

            console.log('Available tables:');
            tables.recordset.forEach((table, index) => {
                console.log(`${index + 1}. ${table.TABLE_NAME}`);
            });
            
            await pool.close();
            return;
        }

        // Get total employee count
        const totalCount = await pool.request().query(`
            SELECT COUNT(*) as total_employees 
            FROM personnel_employee
        `);

        console.log('📊 EMPLOYEE COUNT:');
        console.log(`Total Employees: ${totalCount.recordset[0].total_employees}`);
        console.log('-----------------------------------\n');

        // Get sample employee data
        const sampleData = await pool.request().query(`
            SELECT TOP 10 
                id, 
                emp_code, 
                first_name, 
                last_name, 
                email,
                department_id
            FROM personnel_employee
            ORDER BY emp_code
        `);

        if (sampleData.recordset.length > 0) {
            console.log('📋 SAMPLE EMPLOYEE DATA (First 10):');
            console.log('-----------------------------------');
            sampleData.recordset.forEach((emp, index) => {
                console.log(`${index + 1}. EMP Code: ${emp.emp_code || 'N/A'}`);
                console.log(`   Name: ${emp.first_name || ''} ${emp.last_name || ''}`);
                console.log(`   Email: ${emp.email || 'N/A'}`);
                console.log(`   Department ID: ${emp.department_id || 'N/A'}`);
                console.log('-----------------------------------');
            });
        }

        // Get employee count by department
        const deptCount = await pool.request().query(`
            SELECT 
                d.dept_name,
                COUNT(e.id) as employee_count
            FROM personnel_employee e
            LEFT JOIN personnel_department d ON e.department_id = d.id
            GROUP BY d.dept_name
            ORDER BY employee_count DESC
        `);

        if (deptCount.recordset.length > 0) {
            console.log('\n📊 EMPLOYEES BY DEPARTMENT:');
            console.log('-----------------------------------');
            deptCount.recordset.forEach((dept, index) => {
                console.log(`${index + 1}. ${dept.dept_name || 'No Department'}: ${dept.employee_count} employees`);
            });
        }

        await pool.close();
        console.log('\n✅ Query completed successfully!');

    } catch (err) {
        console.error('❌ Error:', err.message);
        console.error('\nFull error details:', err);
    }
}

checkEmployees();
