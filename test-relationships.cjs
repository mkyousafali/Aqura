const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY0ODI0ODksImV4cCI6MjA3MjA1ODQ4OX0.-HBW0CJM4sO35WjCf0flxuvLLEeQ_eeUnWmLQMlkWQs';

const supabase = createClient(supabaseUrl, supabaseKey);

async function testRelationships() {
    console.log('🔍 Testing Different Relationship Queries...\n');

    try {
        // Test 1: Current component query (this one is failing)
        console.log('1. Component Query (Current - may not work):');
        const { data: componentQuery, error: componentError } = await supabase
            .from('users')
            .select(`
                id,
                username,
                role_type,
                employee_id,
                branch_id,
                hr_employees(
                    id,
                    name,
                    employee_id
                )
            `)
            .limit(2);

        if (componentError) {
            console.error('❌ Component Query Error:', componentError);
        } else {
            console.log('✅ Component Query Works:');
            console.log(JSON.stringify(componentQuery, null, 2));
        }

        // Test 2: Try with explicit foreign key reference
        console.log('\n2. Explicit Foreign Key Query:');
        const { data: explicitQuery, error: explicitError } = await supabase
            .from('users')
            .select(`
                id,
                username,
                role_type,
                employee_id,
                branch_id,
                hr_employees!employee_id(
                    id,
                    name,
                    employee_id
                )
            `)
            .limit(2);

        if (explicitError) {
            console.error('❌ Explicit Query Error:', explicitError);
        } else {
            console.log('✅ Explicit Query Works:');
            console.log(JSON.stringify(explicitQuery, null, 2));
        }

        // Test 3: Manual join approach
        console.log('\n3. Manual Join Approach:');
        
        // Get users first
        const { data: users, error: usersError } = await supabase
            .from('users')
            .select('id, username, role_type, employee_id, branch_id')
            .limit(3);

        if (usersError) {
            console.error('❌ Users fetch error:', usersError);
            return;
        }

        console.log('Users:');
        console.table(users);

        // For each user with employee_id, get employee data
        const enrichedUsers = [];
        for (const user of users) {
            if (user.employee_id) {
                const { data: employee, error: empError } = await supabase
                    .from('hr_employees')
                    .select('id, name, employee_id')
                    .eq('id', user.employee_id)
                    .single();

                enrichedUsers.push({
                    ...user,
                    employee_data: employee,
                    employee_error: empError
                });
            } else {
                enrichedUsers.push({
                    ...user,
                    employee_data: null,
                    employee_error: null
                });
            }
        }

        console.log('\nEnriched Users with Manual Join:');
        console.log(JSON.stringify(enrichedUsers, null, 2));

    } catch (error) {
        console.error('❌ Script Error:', error);
    }
}

// Run the test
testRelationships().then(() => {
    console.log('\n✅ Relationship test completed!');
    process.exit(0);
}).catch(error => {
    console.error('❌ Script failed:', error);
    process.exit(1);
});