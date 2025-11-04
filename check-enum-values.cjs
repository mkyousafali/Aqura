const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function checkEnumValues() {
    console.log('🔍 CHECKING ENUM VALUES');
    console.log('=' .repeat(40));

    try {
        // Check the role_type_enum definition
        const { data: enumValues, error } = await supabase.rpc('execute_sql', {
            sql: `
                SELECT enumlabel 
                FROM pg_enum 
                WHERE enumtypid = (
                    SELECT oid 
                    FROM pg_type 
                    WHERE typname = 'role_type_enum'
                );
            `
        });

        if (error) {
            console.log('❌ Error fetching enum values:', error.message);
            
            // Try alternative query
            const { data: typeInfo, error: typeError } = await supabase.rpc('execute_sql', {
                sql: `
                    SELECT column_name, data_type, udt_name
                    FROM information_schema.columns 
                    WHERE table_name = 'users' AND column_name = 'role_type';
                `
            });
            
            if (typeError) {
                console.log('❌ Error fetching column info:', typeError.message);
            } else {
                console.log('📊 Column info:', typeInfo);
            }
            
            // Try to see current user role values
            const { data: currentRoles, error: roleError } = await supabase
                .from('users')
                .select('role_type')
                .not('role_type', 'is', null);
                
            if (roleError) {
                console.log('❌ Error fetching current roles:', roleError.message);
            } else {
                console.log('\n📋 Current role_type values in users table:');
                const uniqueRoles = [...new Set(currentRoles.map(u => u.role_type))];
                uniqueRoles.forEach(role => {
                    console.log(`  - ${role}`);
                });
            }
            
        } else {
            console.log('\n📋 Available role_type_enum values:');
            enumValues.forEach(value => {
                console.log(`  - ${value.enumlabel}`);
            });
        }

        // Also check what task role_type values exist
        const { data: taskRoles, error: taskError } = await supabase
            .from('receiving_tasks')
            .select('role_type')
            .not('role_type', 'is', null);
            
        if (taskError) {
            console.log('❌ Error fetching task roles:', taskError.message);
        } else {
            console.log('\n📋 Task role_type values in receiving_tasks table:');
            const uniqueTaskRoles = [...new Set(taskRoles.map(t => t.role_type))];
            uniqueTaskRoles.forEach(role => {
                console.log(`  - ${role}`);
            });
        }

    } catch (error) {
        console.error('❌ Error:', error.message);
    }
}

checkEnumValues();