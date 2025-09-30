const { Client } = require('pg');

const client = new Client({
    connectionString: 'postgresql://postgres:%40%23Imanihayath120@db.vmypotfsyrvuublyddyt.supabase.co:5432/postgres'
});

async function checkFunction() {
    try {
        await client.connect();
        
        // Check what functions exist with similar names
        const result = await client.query(`
            SELECT proname, pg_get_functiondef(oid) as definition
            FROM pg_proc 
            WHERE proname LIKE '%scheduled%' OR proname LIKE '%assignment%';
        `);
        
        console.log('📋 Functions related to scheduling/assignments:');
        if (result.rows.length > 0) {
            result.rows.forEach((row, index) => {
                console.log(`\n${index + 1}. Function: ${row.proname}`);
                console.log('Definition:', row.definition.substring(0, 200) + '...');
            });
        } else {
            console.log('❌ No related functions found');
        }
        
        await client.end();
        
    } catch (error) {
        console.error('❌ Error:', error.message);
        await client.end();
    }
}

checkFunction();