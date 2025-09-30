import { Client } from 'pg';

const client = new Client({
    connectionString: 'postgresql://postgres:%40%23Imanihayath120@db.vmypotfsyrvuublyddyt.supabase.co:5432/postgres'
});

async function testShamsuData() {
    try {
        await client.connect();
        console.log('Connected to database');
        
        const query = `
            SELECT 
                u.id, u.username, u.employee_id, u.status,
                e.id as emp_id, e.name as emp_name,
                c.email, c.contact_number, c.whatsapp_number, c.is_active as contact_active,
                pa.is_current, 
                p.position_title_en
            FROM users u
            LEFT JOIN hr_employees e ON u.employee_id = e.id
            LEFT JOIN hr_employee_contacts c ON e.id = c.employee_id AND c.is_active = true
            LEFT JOIN hr_position_assignments pa ON e.id = pa.employee_id AND pa.is_current = true
            LEFT JOIN hr_positions p ON pa.position_id = p.id
            WHERE u.username = 'shamsu'
        `;
        
        const result = await client.query(query);
        console.log('User shamsu data:');
        console.log(JSON.stringify(result.rows, null, 2));
        
        await client.end();
    } catch (err) {
        console.error('Error:', err.message);
        await client.end();
    }
}

testShamsuData();