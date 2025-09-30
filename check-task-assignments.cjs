const { Client } = require('pg');

const client = new Client({
    connectionString: 'postgresql://postgres:%40%23Imanihayath120@db.vmypotfsyrvuublyddyt.supabase.co:5432/postgres'
});

async function checkTaskAssignments() {
    try {
        await client.connect();
        console.log('✅ Connected to database');
        
        // Check schedule-related columns
        const columnsResult = await client.query(`
            SELECT column_name, data_type, is_nullable 
            FROM information_schema.columns 
            WHERE table_name = 'task_assignments' 
            AND (column_name LIKE '%schedule%' OR column_name LIKE '%deadline%')
            ORDER BY ordinal_position;
        `);
        
        console.log('\n📋 Schedule-related columns in task_assignments:');
        if (columnsResult.rows.length > 0) {
            columnsResult.rows.forEach(row => {
                console.log(`  - ${row.column_name} (${row.data_type}, ${row.is_nullable === 'YES' ? 'nullable' : 'not null'})`);
            });
        } else {
            console.log('  ❌ No schedule-related columns found!');
        }
        
        // Check if there are any assignments with schedule data
        const assignmentsResult = await client.query(`
            SELECT COUNT(*) as total_assignments,
                   COUNT(schedule_date) as with_schedule_date,
                   COUNT(deadline_date) as with_deadline_date
            FROM task_assignments;
        `);
        
        console.log('\n📊 Assignment counts:');
        const stats = assignmentsResult.rows[0];
        console.log(`  - Total assignments: ${stats.total_assignments}`);
        console.log(`  - With schedule_date: ${stats.with_schedule_date}`);
        console.log(`  - With deadline_date: ${stats.with_deadline_date}`);
        
        // Show sample assignment data
        const sampleResult = await client.query(`
            SELECT id, task_id, assigned_to_user_id, schedule_date, schedule_time, 
                   deadline_date, deadline_time, assigned_at
            FROM task_assignments 
            ORDER BY assigned_at DESC 
            LIMIT 5;
        `);
        
        console.log('\n📋 Sample recent assignments:');
        if (sampleResult.rows.length > 0) {
            sampleResult.rows.forEach((row, index) => {
                console.log(`  ${index + 1}. Assignment ID: ${row.id.slice(0, 8)}...`);
                console.log(`     Task ID: ${row.task_id.slice(0, 8)}...`);
                console.log(`     User ID: ${row.assigned_to_user_id?.slice(0, 8)}...`);
                console.log(`     Schedule: ${row.schedule_date || 'Not set'} ${row.schedule_time || ''}`);
                console.log(`     Deadline: ${row.deadline_date || 'Not set'} ${row.deadline_time || ''}`);
                console.log(`     Assigned at: ${row.assigned_at}`);
                console.log('');
            });
        } else {
            console.log('  ❌ No assignments found');
        }
        
        await client.end();
        
    } catch (error) {
        console.error('❌ Error:', error.message);
        await client.end();
    }
}

checkTaskAssignments();