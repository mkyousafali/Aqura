const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://gfydhbrbuxlprjnpwuqn.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdmeWRoYnJidXhscHJqbnB3dXFuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzIwMzIzNTUsImV4cCI6MjA0NzYwODM1NX0.aMH0OMRHDgSJfXGFEm3UUKAA4JmMKIpWG3H7f8v_LD4';

const supabase = createClient(supabaseUrl, supabaseKey);

async function testScheduledAssignmentFixed() {
    try {
        console.log('🧪 Testing Fixed Scheduled Assignment Function...');
        
        // Get sample data
        const { data: tasks, error: taskError } = await supabase
            .from('tasks')
            .select('id')
            .limit(1);
            
        const { data: users, error: userError } = await supabase
            .from('users')
            .select('id, username')
            .eq('username', 'madmin')
            .limit(1);
            
        if (taskError || userError || !tasks?.length || !users?.length) {
            console.log('❌ Failed to get test data');
            return;
        }
        
        const taskId = tasks[0].id;
        const userId = users[0].id;
        
        console.log(`📋 Task ID: ${taskId.slice(0, 8)}...`);
        console.log(`👤 User ID: ${userId.slice(0, 8)}...`);
        
        // Test the corrected function call
        const { data, error } = await supabase.rpc('create_scheduled_assignment', {
            p_task_id: taskId,
            p_assignment_type: 'user',
            p_assigned_by: userId,
            p_assigned_to_user_id: userId,
            p_assigned_to_branch_id: null,
            p_assigned_by_name: 'Test Admin',
            p_schedule_date: '2025-10-02',
            p_schedule_time: '10:00:00',
            p_deadline_date: '2025-10-05',
            p_deadline_time: '17:00:00'
        });
        
        if (error) {
            console.log('❌ Function call failed:', error.message);
        } else {
            console.log('✅ Function call successful!');
            console.log(`   New Assignment ID: ${data.slice(0, 8)}...`);
            
            // Verify the assignment
            const { data: assignment, error: verifyError } = await supabase
                .from('task_assignments')
                .select('schedule_date, schedule_time, deadline_date, deadline_time')
                .eq('id', data)
                .single();
                
            if (verifyError) {
                console.log('❌ Verification failed:', verifyError.message);
            } else {
                console.log('📋 Verification Results:');
                console.log(`   Schedule: ${assignment.schedule_date} ${assignment.schedule_time}`);
                console.log(`   Deadline: ${assignment.deadline_date} ${assignment.deadline_time}`);
                
                if (assignment.schedule_date && assignment.deadline_date) {
                    console.log('🎉 SUCCESS! Schedule and deadline data saved correctly!');
                } else {
                    console.log('❌ Schedule data still not saved properly');
                }
            }
        }
        
    } catch (error) {
        console.error('❌ Test failed:', error.message);
    }
}

testScheduledAssignmentFixed();