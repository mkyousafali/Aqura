const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function investigateRoleTypes() {
    console.log('🔍 INVESTIGATING ROLE TYPE SCHEMAS');
    console.log('=' .repeat(50));

    try {
        // Check users table schema
        console.log('\n📋 USERS TABLE SCHEMA:');
        const { data: usersSchema, error: usersError } = await supabase
            .from('users')
            .select('*')
            .limit(1);
            
        if (usersError) {
            console.log('❌ Error fetching users schema:', usersError.message);
        } else {
            console.log('Sample user record:');
            if (usersSchema.length > 0) {
                Object.entries(usersSchema[0]).forEach(([key, value]) => {
                    console.log(`  ${key}: ${typeof value} = ${value}`);
                });
            }
        }

        // Check receiving_tasks table schema  
        console.log('\n📋 RECEIVING_TASKS TABLE SCHEMA:');
        const { data: tasksSchema, error: tasksError } = await supabase
            .from('receiving_tasks')
            .select('*')
            .limit(1);
            
        if (tasksError) {
            console.log('❌ Error fetching tasks schema:', tasksError.message);
        } else {
            console.log('Sample task record:');
            if (tasksSchema.length > 0) {
                Object.entries(tasksSchema[0]).forEach(([key, value]) => {
                    console.log(`  ${key}: ${typeof value} = ${value}`);
                });
            }
        }

        // Try to understand the role type mismatch
        console.log('\n🔍 ROLE TYPE ANALYSIS:');
        console.log('The issue appears to be:');
        console.log('1. Users table has generic role types: Master Admin, Admin, Position-based');
        console.log('2. Tasks table has specific role types: accountant, branch_manager, etc.');
        console.log('3. These are incompatible - they seem to be different enum types or different concepts');
        
        console.log('\n💡 POSSIBLE SOLUTIONS:');
        console.log('Option 1: Add missing enum values to role_type_enum');
        console.log('Option 2: Use a different field for functional roles');
        console.log('Option 3: Create a mapping between user types and functional roles');
        console.log('Option 4: Update the task assignment logic to work with existing user roles');

        // Let's see if there are other role-related columns
        console.log('\n🔍 CHECKING FOR OTHER ROLE FIELDS:');
        const { data: sampleUser, error: userFieldError } = await supabase
            .from('users')
            .select('*')
            .limit(1);
            
        if (!userFieldError && sampleUser.length > 0) {
            const userFields = Object.keys(sampleUser[0]);
            const roleFields = userFields.filter(field => 
                field.toLowerCase().includes('role') || 
                field.toLowerCase().includes('type') ||
                field.toLowerCase().includes('position')
            );
            
            if (roleFields.length > 0) {
                console.log('Fields that might be role-related:');
                roleFields.forEach(field => {
                    console.log(`  - ${field}: ${sampleUser[0][field]}`);
                });
            }
        }

    } catch (error) {
        console.error('❌ Error:', error.message);
    }
}

investigateRoleTypes();