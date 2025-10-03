const { createClient } = require('@supabase/supabase-js');

// Initialize Supabase client
const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY0ODI0ODksImV4cCI6MjA3MjA1ODQ4OX0.-HBW0CJM4sO35WjCf0flxuvLLEeQ_eeUnWmLQMlkWQs';

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkUsersData() {
    console.log('🔍 Checking Users and Employee Data...\n');

    try {
        // 1. Get users with their employee_id and branch_id
        console.log('1. Users Data (first 5 rows):');
        const { data: users, error: usersError } = await supabase
            .from('users')
            .select('id, username, employee_id, branch_id, role_type')
            .limit(5);

        if (usersError) {
            console.error('Users Error:', usersError);
        } else {
            console.table(users);
        }

        // 2. Get hr_employees data
        console.log('\n2. HR Employees Data (first 5 rows):');
        const { data: employees, error: employeesError } = await supabase
            .from('hr_employees')
            .select('id, employee_id, name, branch_id')
            .limit(5);

        if (employeesError) {
            console.error('Employees Error:', employeesError);
        } else {
            console.table(employees);
        }

        // 3. Get branches data
        console.log('\n3. Branches Data:');
        const { data: branches, error: branchesError } = await supabase
            .from('branches')
            .select('id, name_en')
            .eq('is_active', true)
            .limit(5);

        if (branchesError) {
            console.error('Branches Error:', branchesError);
        } else {
            console.table(branches);
        }

        // 4. Check if any users have matching employee records
        console.log('\n4. Checking User-Employee Relationships:');
        if (users && employees) {
            users.forEach(user => {
                if (user.employee_id) {
                    const employee = employees.find(emp => emp.id === user.employee_id);
                    if (employee) {
                        console.log(`✅ ${user.username} -> ${employee.name} (ID: ${employee.employee_id})`);
                    } else {
                        console.log(`❌ ${user.username} -> No employee found for ID: ${user.employee_id}`);
                    }
                } else {
                    console.log(`⚠️  ${user.username} -> No employee_id set`);
                }
            });
        }

        // 5. Try the exact query that's failing in the component
        console.log('\n5. Testing Component Query (Simple):');
        const { data: simpleUsers, error: simpleError } = await supabase
            .from('users')
            .select(`
                id,
                username,
                role_type,
                employee_id,
                branch_id
            `)
            .limit(3);

        if (simpleError) {
            console.error('Simple Query Error:', simpleError);
        } else {
            console.log('Simple query results:');
            console.table(simpleUsers);
        }

        // 6. Try query with left joins
        console.log('\n6. Testing Query with Left Joins:');
        const { data: joinedUsers, error: joinError } = await supabase
            .from('users')
            .select(`
                id,
                username,
                role_type,
                employee_id,
                branch_id,
                hr_employees(id, name, employee_id),
                branches(id, name_en)
            `)
            .limit(3);

        if (joinError) {
            console.error('Joined Query Error:', joinError);
            console.log('Error details:', JSON.stringify(joinError, null, 2));
        } else {
            console.log('Joined query results:');
            console.log(JSON.stringify(joinedUsers, null, 2));
        }

    } catch (error) {
        console.error('❌ Script Error:', error);
    }
}

// Run the check
checkUsersData().then(() => {
    console.log('\n✅ Check completed!');
    process.exit(0);
}).catch(error => {
    console.error('❌ Script failed:', error);
    process.exit(1);
});