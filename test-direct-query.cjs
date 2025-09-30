const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://postgres:%40%23Imanihayath120@db.vmypotfsyrvuublyddyt.supabase.co:5432/postgres'
});

async function checkEmployeeIds() {
  try {
    await client.connect();
    console.log('Checking employee ID mapping for shamsu...');

    // First, get shamsu's employee_id from users table
    const userQuery = `
      SELECT id, username, employee_id 
      FROM users 
      WHERE username = 'shamsu';
    `;
    const userResult = await client.query(userQuery);
    console.log('Shamsu user data:', userResult.rows);

    if (userResult.rows.length > 0) {
      const employeeId = userResult.rows[0].employee_id;
      console.log('Employee ID for shamsu:', employeeId);

      // Now check contacts for this employee_id
      const contactQuery = `
        SELECT * 
        FROM hr_employee_contacts 
        WHERE employee_id = $1;
      `;
      const contactResult = await client.query(contactQuery, [employeeId]);
      console.log('Contact data for employee ID:', JSON.stringify(contactResult.rows, null, 2));

      // Check if there are any contacts in the table at all
      const allContactsQuery = `
        SELECT employee_id, COUNT(*) as contact_count
        FROM hr_employee_contacts 
        GROUP BY employee_id;
      `;
      const allContactsResult = await client.query(allContactsQuery);
      console.log('All contacts summary:', allContactsResult.rows);
    }

  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    await client.end();
  }
}

checkEmployeeIds();