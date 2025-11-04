const { createClient } = require('@supabase/supabase-js');

// Supabase configuration - using your existing connection details
const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function analyzeRoleMismatch() {
    console.log('🔍 COMPREHENSIVE ROLE MISMATCH ANALYSIS');
    console.log('=' .repeat(50));

    try {
        // STEP 1: User Role Distribution
        console.log('\n📊 1. USER ROLE DISTRIBUTION:');
        const { data: userRoles, error: userRoleError } = await supabase.rpc('execute_sql', {
            sql: `
                SELECT 
                    role_type::text,
                    COUNT(*) as user_count
                FROM users 
                GROUP BY role_type::text
                ORDER BY user_count DESC;
            `
        });

        if (userRoleError) {
            // Try direct query instead
            const { data: userRoles2, error: userRoleError2 } = await supabase
                .from('users')
                .select('role_type')
                .not('role_type', 'is', null);
            
            if (userRoleError2) {
                console.error('❌ Error fetching user roles:', userRoleError2.message);
            } else {
                const roleCount = {};
                userRoles2.forEach(user => {
                    const role = user.role_type;
                    roleCount[role] = (roleCount[role] || 0) + 1;
                });
                console.log('User Role Distribution:');
                Object.entries(roleCount).forEach(([role, count]) => {
                    console.log(`  ${role}: ${count} users`);
                });
            }
        } else {
            console.log('User Role Distribution:');
            userRoles.forEach(row => {
                console.log(`  ${row.role_type}: ${row.user_count} users`);
            });
        }

        // STEP 2: Task Role Distribution
        console.log('\n📋 2. TASK ROLE DISTRIBUTION:');
        const { data: taskRoles, error: taskRoleError } = await supabase
            .from('receiving_tasks')
            .select('role_type')
            .eq('task_completed', false);

        if (taskRoleError) {
            console.error('❌ Error fetching task roles:', taskRoleError.message);
        } else {
            const taskRoleCount = {};
            taskRoles.forEach(task => {
                const role = task.role_type;
                taskRoleCount[role] = (taskRoleCount[role] || 0) + 1;
            });
            console.log('Task Role Distribution:');
            Object.entries(taskRoleCount).forEach(([role, count]) => {
                console.log(`  ${role}: ${count} tasks`);
            });
        }

        // STEP 3: Identify role mismatches
        console.log('\n⚠️  3. ROLE MISMATCH ANALYSIS:');
        const { data: mismatches, error: mismatchError } = await supabase
            .from('receiving_tasks')
            .select(`
                id,
                role_type,
                assigned_user_id,
                users!inner(username, role_type, branch_id)
            `)
            .eq('task_completed', false);

        if (mismatchError) {
            console.error('❌ Error fetching mismatches:', mismatchError.message);
            return;
        }

        const mismatchedTasks = mismatches.filter(task => 
            task.role_type !== task.users.role_type
        );

        console.log(`Total mismatched tasks: ${mismatchedTasks.length}`);
        console.log(`Total active tasks: ${mismatches.length}`);
        console.log(`Mismatch percentage: ${((mismatchedTasks.length / mismatches.length) * 100).toFixed(1)}%`);

        // STEP 4: User Assignment Patterns
        console.log('\n👥 4. USER ASSIGNMENT PATTERNS:');
        const userPatterns = {};
        
        mismatches.forEach(task => {
            const userId = task.assigned_user_id;
            const username = task.users.username;
            const userRole = task.users.role_type;
            const taskRole = task.role_type;
            
            if (!userPatterns[userId]) {
                userPatterns[userId] = {
                    username,
                    currentRole: userRole,
                    taskTypes: {},
                    totalTasks: 0
                };
            }
            
            userPatterns[userId].taskTypes[taskRole] = (userPatterns[userId].taskTypes[taskRole] || 0) + 1;
            userPatterns[userId].totalTasks++;
        });

        Object.entries(userPatterns)
            .sort(([,a], [,b]) => b.totalTasks - a.totalTasks)
            .slice(0, 10) // Top 10 users by task count
            .forEach(([userId, pattern]) => {
                console.log(`\n  👤 ${pattern.username} (Current role: ${pattern.currentRole})`);
                console.log(`     Total tasks: ${pattern.totalTasks}`);
                Object.entries(pattern.taskTypes).forEach(([taskRole, count]) => {
                    const isMismatch = taskRole !== pattern.currentRole;
                    const indicator = isMismatch ? '❌' : '✅';
                    console.log(`     ${indicator} ${taskRole}: ${count} tasks`);
                });
            });

        // STEP 5: Suggested Role Updates
        console.log('\n💡 5. SUGGESTED ROLE UPDATES:');
        console.log('Users who should probably have their role_type updated:\n');

        Object.entries(userPatterns).forEach(([userId, pattern]) => {
            // Find the most common task type for this user
            const taskTypeCounts = Object.entries(pattern.taskTypes);
            if (taskTypeCounts.length === 0) return;
            
            const mostCommonTaskType = taskTypeCounts
                .sort(([,a], [,b]) => b - a)[0];
            
            const [suggestedRole, count] = mostCommonTaskType;
            const percentage = ((count / pattern.totalTasks) * 100).toFixed(1);
            
            // Suggest role update if user has 5+ tasks and 70%+ are of one type
            if (pattern.totalTasks >= 5 && percentage >= 70 && suggestedRole !== pattern.currentRole) {
                console.log(`  📝 UPDATE: ${pattern.username}`);
                console.log(`     From: ${pattern.currentRole} → To: ${suggestedRole}`);
                console.log(`     Reason: ${count}/${pattern.totalTasks} (${percentage}%) tasks are ${suggestedRole}`);
                console.log(`     SQL: UPDATE users SET role_type = '${suggestedRole}'::role_type_enum WHERE username = '${pattern.username}';`);
                console.log('');
            }
        });

        // STEP 6: Specific problem case analysis
        console.log('\n🎯 6. SPECIFIC PROBLEM CASES:');
        const ayoobTasks = mismatchedTasks.filter(task => task.users.username === 'Ayoob');
        if (ayoobTasks.length > 0) {
            console.log(`\n  👤 Ayoob has ${ayoobTasks.length} mismatched tasks:`);
            const ayoobTaskTypes = {};
            ayoobTasks.forEach(task => {
                ayoobTaskTypes[task.role_type] = (ayoobTaskTypes[task.role_type] || 0) + 1;
            });
            Object.entries(ayoobTaskTypes).forEach(([taskType, count]) => {
                console.log(`     ${taskType}: ${count} tasks`);
            });
        }

        console.log('\n✅ Analysis complete!');
        console.log('\nNext steps:');
        console.log('1. Review the suggested role updates above');
        console.log('2. Update user role_type values to match their primary task assignments');
        console.log('3. Or alternatively, reassign tasks to users with matching roles');

    } catch (error) {
        console.error('❌ Error during analysis:', error.message);
    }
}

// Run the analysis
analyzeRoleMismatch();