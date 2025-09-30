const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://gfydhbrbuxlprjnpwuqn.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdmeWRoYnJidXhscHJqbnB3dXFuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzIwMzIzNTUsImV4cCI6MjA0NzYwODM1NX0.aMH0OMRHDgSJfXGFEm3UUKAA4JmMKIpWG3H7f8v_LD4';

const supabase = createClient(supabaseUrl, supabaseKey);

async function debugTestData() {
    try {
        console.log('🔍 Debugging test data availability...');
        
        // Check tasks
        const { data: tasks, error: taskError } = await supabase
            .from('tasks')
            .select('id, title')
            .limit(3);
            
        console.log('\n📋 Tasks:');
        if (taskError) {
            console.log('❌ Task Error:', taskError.message);
        } else {
            console.log(`   Found ${tasks?.length || 0} tasks`);
            tasks?.forEach((task, i) => {
                console.log(`   ${i + 1}. ${task.id.slice(0, 8)}... - ${task.title}`);
            });
        }
        
        // Check users
        const { data: users, error: userError } = await supabase
            .from('users')
            .select('id, username')
            .limit(3);
            
        console.log('\n👤 Users:');
        if (userError) {
            console.log('❌ User Error:', userError.message);
        } else {
            console.log(`   Found ${users?.length || 0} users`);
            users?.forEach((user, i) => {
                console.log(`   ${i + 1}. ${user.id.slice(0, 8)}... - ${user.username}`);
            });
        }
        
        // Check for madmin specifically
        const { data: madminUser, error: madminError } = await supabase
            .from('users')
            .select('id, username')
            .eq('username', 'madmin')
            .single();
            
        console.log('\n🔍 Madmin user:');
        if (madminError) {
            console.log('❌ Madmin Error:', madminError.message);
        } else {
            console.log(`   Found: ${madminUser.id.slice(0, 8)}... - ${madminUser.username}`);
        }
        
        // If we have both task and user, test the function
        if (tasks?.length && users?.length) {
            console.log('\n🧪 Testing function with available data...');
            
            const taskId = tasks[0].id;
            const userId = users[0].id;
            
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
                console.log('❌ Function Error:', error.message);
            } else {
                console.log('✅ Function Success! Assignment ID:', data?.slice(0, 8) + '...');
            }
        }
        
    } catch (error) {
        console.error('❌ Debug failed:', error.message);
    }
}

debugTestData();