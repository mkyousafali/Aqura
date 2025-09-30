const { Client } = require('pg');

const client = new Client({
    connectionString: 'postgresql://postgres:%40%23Imanihayath120@db.vmypotfsyrvuublyddyt.supabase.co:5432/postgres'
});

async function checkFunctionSignature() {
    try {
        await client.connect();
        
        // Get the exact function signature
        const result = await client.query(`
            SELECT 
                routine_name,
                data_type,
                ordinal_position,
                parameter_name,
                parameter_mode
            FROM information_schema.parameters 
            WHERE specific_name IN (
                SELECT specific_name 
                FROM information_schema.routines 
                WHERE routine_name = 'create_scheduled_assignment'
            )
            ORDER BY ordinal_position;
        `);
        
        console.log('📋 create_scheduled_assignment function parameters:');
        if (result.rows.length > 0) {
            result.rows.forEach(row => {
                console.log(`  ${row.ordinal_position}. ${row.parameter_name || 'unnamed'}: ${row.data_type} (${row.parameter_mode})`);
            });
        } else {
            console.log('❌ No parameters found or function doesn\'t exist');
        }
        
        // Also check the function definition
        const funcDef = await client.query(`
            SELECT pg_get_functiondef(oid) as definition
            FROM pg_proc 
            WHERE proname = 'create_scheduled_assignment';
        `);
        
        if (funcDef.rows.length > 0) {
            console.log('\n📜 Function definition:');
            console.log(funcDef.rows[0].definition);
        }
        
        await client.end();
        
    } catch (error) {
        console.error('❌ Error:', error.message);
        await client.end();
    }
}

checkFunctionSignature();