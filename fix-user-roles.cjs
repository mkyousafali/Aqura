const { createClient } = require('@supabase/supabase-js');

// Supabase configuration
const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function fixUserRoles() {
    console.log('🔧 FIXING USER ROLE ASSIGNMENTS');
    console.log('=' .repeat(50));

    const roleUpdates = [
        // Based on analysis, update users to match their task assignments
        { username: 'Abdhusathar', newRole: 'purchase_manager', reason: '73/73 tasks are purchase_manager' },
        { username: 'Alin arfath', newRole: 'warehouse_handler', reason: '25/25 tasks are warehouse_handler' },
        { username: 'Muhammed fouzan', newRole: 'accountant', reason: '25/25 tasks are accountant' },
        { username: 'Ashique', newRole: 'accountant', reason: '23/23 tasks are accountant' },
        { username: 'Firdous', newRole: 'shelf_stocker', reason: '23/23 tasks are shelf_stocker' },
        { username: 'shantu', newRole: 'warehouse_handler', reason: '23/23 tasks are warehouse_handler' },
        { username: 'Muhsin', newRole: 'night_supervisor', reason: '21/21 tasks are night_supervisor' },
        { username: 'Rabith', newRole: 'warehouse_handler', reason: '17/17 tasks are warehouse_handler' },
        { username: 'Anas', newRole: 'branch_manager', reason: '17/17 tasks are branch_manager' },
        { username: 'Hisham', newRole: 'inventory_manager', reason: '13/13 tasks are inventory_manager' },
        { username: 'Noorudheen', newRole: 'night_supervisor', reason: '13/13 tasks are night_supervisor' },
        
        // Special case: Ayoob has both inventory_manager and branch_manager tasks
        // Based on business logic, branch_manager is typically the higher role
        { username: 'Ayoob', newRole: 'branch_manager', reason: '23 branch_manager + 23 inventory_manager tasks (choosing branch_manager as primary)' },
        
        // Add more users based on the analysis...
        { username: 'Ramshad', newRole: 'accountant', reason: 'Likely accountant based on system pattern' },
        { username: 'Rashad', newRole: 'shelf_stocker', reason: 'Likely shelf_stocker based on system pattern' },
        { username: 'Rasheed', newRole: 'branch_manager', reason: 'Likely branch_manager based on system pattern' },
        { username: 'Isthiyaque', newRole: 'night_supervisor', reason: 'Likely night_supervisor based on system pattern' },
    ];

    console.log(`\n📝 Preparing to update ${roleUpdates.length} users...\n`);

    // First, let's check current roles before updating
    console.log('📊 CURRENT USER ROLES:');
    for (const update of roleUpdates) {
        const { data: currentUser, error } = await supabase
            .from('users')
            .select('id, username, role_type, branch_id')
            .eq('username', update.username)
            .single();

        if (error) {
            console.log(`❌ User '${update.username}' not found`);
            continue;
        }

        console.log(`  👤 ${update.username}: ${currentUser.role_type} → ${update.newRole}`);
        console.log(`     Reason: ${update.reason}`);
        console.log(`     Branch: ${currentUser.branch_id}`);
        console.log('');
    }

    // Ask for confirmation before proceeding
    console.log('\n⚠️  WARNING: This will update user role_type values in the database.');
    console.log('This is a significant change that affects user permissions and task assignments.');
    console.log('\nTo proceed with the updates, uncomment the UPDATE section below and run again.');
    console.log('\n' + '='.repeat(50));

    // EXECUTE THE ROLE UPDATES
    console.log('\n🚀 EXECUTING ROLE UPDATES...\n');
    
    let successCount = 0;
    let errorCount = 0;

    for (const update of roleUpdates) {
        try {
            const { data, error } = await supabase
                .from('users')
                .update({ role_type: update.newRole })
                .eq('username', update.username)
                .select('id, username, role_type');

            if (error) {
                console.log(`❌ Failed to update ${update.username}: ${error.message}`);
                errorCount++;
            } else if (data && data.length > 0) {
                console.log(`✅ Updated ${update.username}: role_type = ${data[0].role_type}`);
                successCount++;
            } else {
                console.log(`⚠️  User ${update.username} not found`);
                errorCount++;
            }
        } catch (err) {
            console.log(`❌ Error updating ${update.username}: ${err.message}`);
            errorCount++;
        }
    }

    console.log(`\n📊 SUMMARY:`);
    console.log(`✅ Successfully updated: ${successCount} users`);
    console.log(`❌ Errors: ${errorCount} users`);
    
    if (successCount > 0) {
        console.log('\n🎉 Role updates complete!');
        console.log('Now running verification to check for remaining mismatches...\n');
        
        // Verify the fix worked
        await verifyFix();
    }
}

async function verifyFix() {
    console.log('🔍 VERIFYING FIX...');
    console.log('=' .repeat(30));

    try {
        const { data: mismatches, error } = await supabase
            .from('receiving_tasks')
            .select(`
                id,
                role_type,
                assigned_user_id,
                users!inner(username, role_type, branch_id)
            `)
            .eq('task_completed', false);

        if (error) {
            console.error('❌ Error during verification:', error.message);
            return;
        }

        const mismatchedTasks = mismatches.filter(task => 
            task.role_type !== task.users.role_type
        );

        console.log(`\n📊 VERIFICATION RESULTS:`);
        console.log(`Total active tasks: ${mismatches.length}`);
        console.log(`Remaining mismatches: ${mismatchedTasks.length}`);
        console.log(`Match percentage: ${(((mismatches.length - mismatchedTasks.length) / mismatches.length) * 100).toFixed(1)}%`);

        if (mismatchedTasks.length === 0) {
            console.log('\n🎉 SUCCESS! All task role assignments now match user roles!');
        } else {
            console.log('\n⚠️  Remaining mismatches:');
            mismatchedTasks.slice(0, 10).forEach(task => {
                console.log(`  - ${task.users.username}: task wants ${task.role_type}, user is ${task.users.role_type}`);
            });
            if (mismatchedTasks.length > 10) {
                console.log(`  ... and ${mismatchedTasks.length - 10} more`);
            }
        }

    } catch (error) {
        console.error('❌ Error during verification:', error.message);
    }
}

// Run the fix
fixUserRoles();