const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function checkPositions() {
    console.log('🔍 CHECKING POSITIONS TABLE');
    console.log('=' .repeat(40));

    try {
        // Check if positions table exists and get structure
        const { data: positions, error: positionsError } = await supabase
            .from('positions')
            .select('*')
            .limit(10);
            
        if (positionsError) {
            console.log('❌ Positions table error:', positionsError.message);
            
            // Try other potential table names
            const potentialTables = ['position', 'roles', 'job_positions', 'user_positions'];
            for (const tableName of potentialTables) {
                const { data, error } = await supabase
                    .from(tableName)
                    .select('*')
                    .limit(5);
                    
                if (!error) {
                    console.log(`\n✅ Found ${tableName} table:`, data);
                    break;
                }
            }
        } else {
            console.log('\n📋 POSITIONS TABLE DATA:');
            positions.forEach(position => {
                console.log(`  ID: ${position.id}`);
                Object.entries(position).forEach(([key, value]) => {
                    if (key !== 'id') {
                        console.log(`    ${key}: ${value}`);
                    }
                });
                console.log('');
            });
        }

        // Now let's see the user-position mappings for our key users
        console.log('\n👥 USER-POSITION MAPPINGS:');
        const keyUsers = ['Ayoob', 'Abdhusathar', 'Anas', 'Hisham', 'Ashique', 'Firdous'];
        
        for (const username of keyUsers) {
            const { data: user, error: userError } = await supabase
                .from('users')
                .select('id, username, role_type, position_id, branch_id')
                .eq('username', username)
                .single();
                
            if (userError) {
                console.log(`❌ ${username}: ${userError.message}`);
                continue;
            }
            
            // If we found positions table, join with it
            if (!positionsError) {
                const { data: userWithPosition, error: joinError } = await supabase
                    .from('users')
                    .select(`
                        username, 
                        role_type, 
                        branch_id,
                        position_id,
                        positions(*)
                    `)
                    .eq('username', username)
                    .single();
                    
                if (!joinError) {
                    console.log(`\n  👤 ${userWithPosition.username}:`);
                    console.log(`     Role Type: ${userWithPosition.role_type}`);
                    console.log(`     Branch: ${userWithPosition.branch_id}`);
                    console.log(`     Position ID: ${userWithPosition.position_id}`);
                    if (userWithPosition.positions) {
                        console.log(`     Position Details:`, userWithPosition.positions);
                    }
                }
            } else {
                console.log(`\n  👤 ${user.username}:`);
                console.log(`     Role Type: ${user.role_type}`);
                console.log(`     Position ID: ${user.position_id}`);
                console.log(`     Branch: ${user.branch_id}`);
            }
        }

        // Check task assignment logic - maybe there's a mapping table
        console.log('\n🔍 TASK ASSIGNMENT ANALYSIS:');
        console.log('The system must have a way to map position_id to task role_type');
        console.log('Let\'s see if there are any other related tables...');
        
        // Try to find task template or role mapping tables
        const potentialMappingTables = [
            'receiving_task_templates', 
            'role_mappings', 
            'position_roles',
            'task_role_mappings'
        ];
        
        for (const tableName of potentialMappingTables) {
            const { data, error } = await supabase
                .from(tableName)
                .select('*')
                .limit(5);
                
            if (!error && data.length > 0) {
                console.log(`\n✅ Found ${tableName} table:`, data);
            }
        }

    } catch (error) {
        console.error('❌ Error:', error.message);
    }
}

checkPositions();