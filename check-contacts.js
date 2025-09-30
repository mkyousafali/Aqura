import { Client } from 'pg';

const client = new Client({
    connectionString: 'postgresql://postgres:%40%23Imanihayath120@db.vmypotfsyrvuublyddyt.supabase.co:5432/postgres'
});

async function checkContactData() {
    try {
        await client.connect();
        console.log('Connected to database');
        
        // Check if there are any contact records for shamsu's employee
        const contactQuery = `
            SELECT 
                e.id as employee_id,
                e.name,
                c.*
            FROM hr_employees e
            LEFT JOIN hr_employee_contacts c ON e.id = c.employee_id
            WHERE e.id = '62822d10-b910-4713-965f-63bd249b8b09'
        `;
        
        const contactResult = await client.query(contactQuery);
        console.log('Contact records for shamsu employee:');
        console.log(JSON.stringify(contactResult.rows, null, 2));
        
        // Check total contact records in the table
        const totalContactsQuery = `SELECT COUNT(*) as total_contacts FROM hr_employee_contacts`;
        const totalResult = await client.query(totalContactsQuery);
        console.log('Total contact records in hr_employee_contacts:', totalResult.rows[0].total_contacts);
        
        // Show sample contact records
        const sampleContactsQuery = `
            SELECT c.*, e.name as employee_name 
            FROM hr_employee_contacts c 
            JOIN hr_employees e ON c.employee_id = e.id 
            LIMIT 5
        `;
        const sampleResult = await client.query(sampleContactsQuery);
        console.log('Sample contact records:');
        console.log(JSON.stringify(sampleResult.rows, null, 2));
        
        await client.end();
    } catch (err) {
        console.error('Error:', err.message);
        await client.end();
    }
}

checkContactData();