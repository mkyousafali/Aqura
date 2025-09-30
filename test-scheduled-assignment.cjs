const { Client } = require('pg');

const client = new Client({
    connectionString: 'postgresql://postgres:%40%23Imanihayath120@db.vmypotfsyrvuublyddyt.supabase.co:5432/postgres'
});

async function testScheduledAssignment() {
    try {
        await client.connect();
        console.log('✅ Connected to database');
        
        // Get a sample task and user
        const taskResult = await client.query('SELECT id FROM tasks LIMIT 1;');
        const userResult = await client.query('SELECT id FROM users WHERE username = $1 LIMIT 1;', ['madmin']);
        
        if (taskResult.rows.length === 0) {
            console.log('❌ No tasks found for testing');
            return;
        }
        
        if (userResult.rows.length === 0) {
            console.log('❌ No test user found');
            return;
        }
        
        const taskId = taskResult.rows[0].id;
        const userId = userResult.rows[0].id;
        
        console.log(`📋 Testing with Task ID: ${taskId.slice(0, 8)}...`);
        console.log(`👤 Testing with User ID: ${userId.slice(0, 8)}...`);
        
        // Test the createScheduledAssignment function
        const testDate = '2025-10-01';
        const testTime = '14:30:00';
        const deadlineDate = '2025-10-05';
        const deadlineTime = '17:00:00';
        
        console.log(`🕐 Testing schedule: ${testDate} ${testTime}`);
        console.log(`⏰ Testing deadline: ${deadlineDate} ${deadlineTime}`);
        
        const result = await client.query(`
            SELECT create_scheduled_assignment(
                $1::uuid,  -- task_id
                $2::text,  -- assignment_type
                $3::text,  -- assigned_by
                $4::text,  -- assigned_by_name
                $5::date,  -- schedule_date
                $6::time,  -- schedule_time
                $7::date,  -- deadline_date
                $8::time,  -- deadline_time
                $9::text,  -- assigned_to_user_id
                NULL       -- assigned_to_branch_id
            ) as assignment_id;
        `, [
            taskId,
            'user',
            userId,
            'Test Admin',
            testDate,
            testTime,
            deadlineDate,
            deadlineTime,
            userId
        ]);
        
        if (result.rows.length > 0 && result.rows[0].assignment_id) {
            const assignmentId = result.rows[0].assignment_id;
            console.log(`✅ Assignment created successfully!`);
            console.log(`   Assignment ID: ${assignmentId.slice(0, 8)}...`);
            
            // Verify the assignment was created with schedule data
            const verifyResult = await client.query(`
                SELECT schedule_date, schedule_time, deadline_date, deadline_time, assigned_at
                FROM task_assignments
                WHERE id = $1;
            `, [assignmentId]);
            
            if (verifyResult.rows.length > 0) {
                const assignment = verifyResult.rows[0];
                console.log('📋 Verification:');
                console.log(`   Schedule: ${assignment.schedule_date} ${assignment.schedule_time}`);
                console.log(`   Deadline: ${assignment.deadline_date} ${assignment.deadline_time}`);
                console.log(`   Created: ${assignment.assigned_at}`);
                
                if (assignment.schedule_date && assignment.deadline_date) {
                    console.log('✅ Schedule data saved correctly!');
                } else {
                    console.log('❌ Schedule data NOT saved properly');
                }
            }
        } else {
            console.log('❌ Failed to create scheduled assignment');
            console.log('Result:', result.rows);
        }
        
        await client.end();
        
    } catch (error) {
        console.error('❌ Error:', error.message);
        console.error('Details:', error);
        await client.end();
    }
}

testScheduledAssignment();