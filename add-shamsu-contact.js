import { Client } from 'pg';

const client = new Client({
    connectionString: 'postgresql://postgres:%40%23Imanihayath120@db.vmypotfsyrvuublyddyt.supabase.co:5432/postgres'
});

async function addContactForShamsu() {
    try {
        await client.connect();
        console.log('Connected to database');
        
        // Add contact record for shamsu's employee
        const insertContactQuery = `
            INSERT INTO hr_employee_contacts (
                employee_id,
                email,
                contact_number,
                whatsapp_number,
                is_active
            ) VALUES (
                '62822d10-b910-4713-965f-63bd249b8b09',
                'shamsu@company.com',
                '+966123456789',
                '+966123456789',
                true
            )
            RETURNING *
        `;
        
        const insertResult = await client.query(insertContactQuery);
        console.log('Contact record added for shamsu:');
        console.log(JSON.stringify(insertResult.rows[0], null, 2));
        
        // Verify the data is now properly linked
        const verifyQuery = `
            SELECT 
                u.id, u.username, u.employee_id, u.status,
                e.id as emp_id, e.name as emp_name,
                c.email, c.contact_number, c.whatsapp_number, c.is_active as contact_active,
                pa.is_current, 
                p.position_title_en
            FROM users u
            LEFT JOIN hr_employees e ON u.employee_id = e.id
            LEFT JOIN hr_employee_contacts c ON e.id = c.employee_id
            LEFT JOIN hr_position_assignments pa ON e.id = pa.employee_id AND pa.is_current = true
            LEFT JOIN hr_positions p ON pa.position_id = p.id
            WHERE u.username = 'shamsu'
        `;
        
        const verifyResult = await client.query(verifyQuery);
        console.log('Updated shamsu data with contact info:');
        console.log(JSON.stringify(verifyResult.rows, null, 2));
        
        await client.end();
    } catch (err) {
        console.error('Error:', err.message);
        await client.end();
    }
}

addContactForShamsu();