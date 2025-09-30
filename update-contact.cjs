const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://postgres:%40%23Imanihayath120@db.vmypotfsyrvuublyddyt.supabase.co:5432/postgres'
});

async function updateContactRecord() {
  try {
    await client.connect();
    console.log('Updating contact record for shamsu employee...');

    const result = await client.query(
      'UPDATE hr_employee_contacts SET employee_id = $1 WHERE employee_id = $2;',
      ['62822d10-b910-4713-965f-63bd249b8b09', 'fa348d70-eabc-4c6c-a5c6-f8b53484f2c5']
    );

    console.log('Updated contact record. Rows affected:', result.rowCount);

  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    await client.end();
  }
}

updateContactRecord();