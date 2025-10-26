// Test script to check users table structure
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkUsersTable() {
    console.log('🔍 Checking users table structure...\n');

    // Get users with all columns
    const { data: userData, error: userError } = await supabase
        .from('users')
        .select('*')
        .limit(5);

    if (userError) {
        console.error('❌ Error:', userError.message);
        console.error('Details:', userError);
        return;
    }

    console.log(`✅ Found ${userData.length} users\n`);

    if (userData.length > 0) {
        console.log('📋 Table Structure (columns found in first user):');
        console.log('=====================================');
        
        const firstUser = userData[0];
        Object.keys(firstUser).forEach((key, index) => {
            const value = firstUser[key];
            const type = typeof value;
            const displayValue = value === null ? 'NULL' : 
                                type === 'string' && value.length > 30 ? value.substring(0, 30) + '...' : 
                                value;
            console.log(`${index + 1}. ${key}: ${type} = ${displayValue}`);
        });

        console.log('\n📊 Sample Users:');
        console.log('=====================================');
        userData.forEach((user, index) => {
            console.log(`\nUser ${index + 1}:`);
            console.log(`  ID: ${user.id}`);
            console.log(`  Username: ${user.username || 'N/A'}`);
            console.log(`  Employee ID: ${user.employee_id || 'N/A'}`);
            console.log(`  User Type: ${user.user_type || 'N/A'}`);
            console.log(`  Branch ID: ${user.branch_id || 'N/A'}`);
            console.log(`  Status: ${user.status || 'N/A'}`);
            console.log(`  Device ID: ${user.device_id || 'N/A'}`);
            console.log(`  Created At: ${user.created_at || 'N/A'}`);
        });
    } else {
        console.log('⚠️  No users found in the table');
    }

    // Count total users
    const { count, error: countError } = await supabase
        .from('users')
        .select('*', { count: 'exact', head: true });

    if (!countError) {
        console.log(`\n📈 Total users in database: ${count}`);
    }
}

checkUsersTable().then(() => {
    console.log('\n✨ Check complete!');
    process.exit(0);
}).catch(err => {
    console.error('💥 Fatal error:', err);
    process.exit(1);
});
