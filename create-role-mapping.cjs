const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function createRoleMapping() {
    console.log('🔧 CREATING POSITION-TO-ROLE MAPPING');
    console.log('=' .repeat(50));

    try {
        // Based on our analysis, create a mapping of users to their functional roles
        const positionRoleMapping = {
            // Branch managers
            '91686ffe-58ac-4c42-9da4-66e0e7b13b80': 'branch_manager', // Ayoob
            'a27a28e1-a99d-4d10-bb9f-931cbcd30c11': 'branch_manager', // Anas
            
            // Inventory managers
            'fd146e59-6875-40b1-bccd-0806e1bbd956': 'inventory_manager', // Hisham
            
            // Accountants
            '4f7d8239-4c59-4dad-ab40-b854f875ffe2': 'accountant', // Ashique
            
            // Shelf stockers
            '172d87af-6224-455b-9c7c-741761ec4ac3': 'shelf_stocker', // Firdous
        };

        // Special case: Admin users like Abdhusathar (no position_id) -> purchase_manager
        const adminUserMapping = {
            'Abdhusathar': 'purchase_manager'
        };

        // Check the current position IDs and their usage
        console.log('\n📊 ANALYZING CURRENT ASSIGNMENTS:');
        
        const { data: allUsers, error: usersError } = await supabase
            .from('users')
            .select('id, username, position_id, role_type, branch_id')
            .not('position_id', 'is', null);
            
        if (usersError) {
            console.log('❌ Error fetching users:', usersError.message);
            return;
        }

        // Group by position_id to see patterns
        const positionGroups = {};
        allUsers.forEach(user => {
            if (!positionGroups[user.position_id]) {
                positionGroups[user.position_id] = [];
            }
            positionGroups[user.position_id].push(user);
        });

        console.log('\nPosition ID groupings:');
        Object.entries(positionGroups).forEach(([positionId, users]) => {
            console.log(`\n  Position ID: ${positionId}`);
            console.log(`  Users (${users.length}):`);
            users.forEach(user => {
                console.log(`    - ${user.username} (Branch ${user.branch_id})`);
            });
        });

        // SOLUTION 1: Create a position_role_mapping table
        console.log('\n💡 SOLUTION 1: Create position_role_mapping table');
        console.log('This table will map position_id to functional role_type for task assignment');
        
        const mappingTableSQL = `
        CREATE TABLE IF NOT EXISTS position_role_mapping (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            position_id UUID NOT NULL,
            functional_role_type TEXT NOT NULL,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
        
        -- Insert the mappings we discovered
        INSERT INTO position_role_mapping (position_id, functional_role_type) VALUES
        ('91686ffe-58ac-4c42-9da4-66e0e7b13b80', 'branch_manager'),
        ('a27a28e1-a99d-4d10-bb9f-931cbcd30c11', 'branch_manager'),
        ('fd146e59-6875-40b1-bccd-0806e1bbd956', 'inventory_manager'),
        ('4f7d8239-4c59-4dad-ab40-b854f875ffe2', 'accountant'),
        ('172d87af-6224-455b-9c7c-741761ec4ac3', 'shelf_stocker')
        ON CONFLICT (position_id) DO UPDATE SET 
            functional_role_type = EXCLUDED.functional_role_type,
            updated_at = NOW();
        `;

        console.log('\nSQL to create the mapping table:');
        console.log(mappingTableSQL);

        // SOLUTION 2: Update the task assignment logic
        console.log('\n💡 SOLUTION 2: Fix task assignment logic');
        console.log('Update the code that creates receiving tasks to use position_role_mapping');
        
        const fixedAssignmentLogic = `
        -- Instead of assigning based on role_type, use position mapping:
        SELECT u.id as user_id 
        FROM users u
        JOIN position_role_mapping prm ON u.position_id = prm.position_id
        WHERE prm.functional_role_type = $1  -- The task's role_type
        AND u.branch_id = $2  -- The task's branch
        AND u.status = 'active'
        LIMIT 1;
        
        -- For admin users without position_id (like purchase managers):
        SELECT u.id as user_id
        FROM users u  
        WHERE u.role_type = 'Admin'
        AND u.username = 'Abdhusathar'  -- Or other logic to identify purchase managers
        LIMIT 1;
        `;

        console.log('\nFixed assignment query logic:');
        console.log(fixedAssignmentLogic);

        // SOLUTION 3: Temporary fix - reassign existing tasks
        console.log('\n💡 SOLUTION 3: Immediate fix for existing tasks');
        console.log('Reassign current mismatched tasks to correct users based on our mapping');

        // For now, let's create the quick fix for Ayoob's specific case
        console.log('\n🎯 QUICK FIX FOR AYOOB:');
        console.log('Since Ayoob should be handling branch_manager tasks, not inventory_manager tasks,');
        console.log('we need to either:');
        console.log('1. Reassign his inventory_manager tasks to the actual inventory manager');
        console.log('2. Or update his role to allow both branch_manager and inventory_manager tasks');

        // Check if there's a proper inventory manager in branch 2
        const { data: inventoryManagers, error: imError } = await supabase
            .from('users')
            .select('id, username, position_id, branch_id')
            .eq('branch_id', 2);  // Ayoob's branch
            
        if (!imError) {
            console.log('\nUsers in Branch 2 (Ayoob\'s branch):');
            inventoryManagers.forEach(user => {
                const mappedRole = positionRoleMapping[user.position_id] || 'unknown';
                console.log(`  - ${user.username}: position_id=${user.position_id} -> ${mappedRole}`);
            });
        }

        console.log('\n✅ NEXT STEPS:');
        console.log('1. Create the position_role_mapping table (SQL above)');
        console.log('2. Update task assignment logic to use the mapping');
        console.log('3. For immediate fix: reassign Ayoob\'s inventory tasks to proper inventory manager');
        console.log('   OR designate Ayoob as both branch_manager AND inventory_manager for his branch');

    } catch (error) {
        console.error('❌ Error:', error.message);
    }
}

createRoleMapping();