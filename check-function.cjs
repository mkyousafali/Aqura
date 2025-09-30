const { Client } = require('pg');

const client = new Client({
    connectionString: 'postgresql://postgres:%40%23Imanihayath120@db.vmypotfsyrvuublyddyt.supabase.co:5432/postgres'
});

async function checkFunction() {
    try {
        await client.connect();
        
        // Check if function exists
        const functionResult = await client.query(`
            SELECT routine_name, routine_type 
            FROM information_schema.routines 
            WHERE routine_name = 'create_scheduled_assignment';
        `);
        
        if (functionResult.rows.length > 0) {
            console.log('✅ create_scheduled_assignment function exists');
        } else {
            console.log('❌ create_scheduled_assignment function NOT found');
            console.log('🔧 This function needs to be created in the database');
        }
        
        await client.end();
        
    } catch (error) {
        console.error('❌ Error:', error.message);
        await client.end();
    }
}

checkFunction();