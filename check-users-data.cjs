const { createClient } = require('@supabase/supabase-js');

// Initialize Supabase client
const supabaseUrl = 'https://pqmjfwmbitodwtpedlle.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBxbWpmd21iaXRvZHd0cGVkbGxlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjI1OTAyOTQsImV4cCI6MjAzODE2NjI5NH0.lZ5zLJSzjrQnwUIkjxOlgr7F5Xl81WTz6wWMdS6cgJo';

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkUsersData() {
    console.log('🔍 Checking Users Table Structure and Data...\n');

    try {
        // 1. Check users table structure
        console.log('1. Users Table Structure:');
        const { data: usersStructure, error: structureError } = await supabase
            .rpc('exec_sql', { 
                sql: `
                    SELECT column_name, data_type, is_nullable, column_default 
                    FROM information_schema.columns 
                    WHERE table_name = 'users' 
                    ORDER BY ordinal_position;
                `
            });

        if (structureError) {
            console.error('Structure Error:', structureError);
        } else {
            console.table(usersStructure);
        }

        // 2. Check sample users data
        console.log('\n2. Sample Users Data:');
        const { data: sampleUsers, error: usersError } = await supabase
            .from('users')
            .select('id, username, employee_id, branch_id, role_type')
            .limit(5);

        if (usersError) {
            console.error('Users Error:', usersError);
        } else {
            console.table(sampleUsers);
        }

        // 3. Check hr_employees table
        console.log('\n3. Sample HR Employees Data:');
        const { data: sampleEmployees, error: employeesError } = await supabase
            .from('hr_employees')
            .select('id, employee_id, name, branch_id')
            .limit(5);

        if (employeesError) {
            console.error('Employees Error:', employeesError);
        } else {
            console.table(sampleEmployees);
        }

        // 4. Check branches table
        console.log('\n4. Sample Branches Data:');
        const { data: sampleBranches, error: branchesError } = await supabase
            .from('branches')
            .select('id, name_en')
            .limit(5);

        if (branchesError) {
            console.error('Branches Error:', branchesError);
        } else {
            console.table(sampleBranches);
        }

        // 5. Check users with employee relationships
        console.log('\n5. Users with Employee Relationships:');
        const { data: usersWithEmployees, error: relationError } = await supabase
            .from('users')
            .select(`
                username,
                employee_id,
                branch_id,
                role_type,
                hr_employees(id, name, employee_id, branch_id),
                branches(id, name_en)
            `)
            .limit(5);

        if (relationError) {
            console.error('Relation Error:', relationError);
            console.error('Full Error Details:', JSON.stringify(relationError, null, 2));
        } else {
            console.log('Users with relationships:');
            console.log(JSON.stringify(usersWithEmployees, null, 2));
        }

        // 6. Check if employee_id fields match
        console.log('\n6. Check Employee ID Matching:');
        const { data: userEmployeeIds, error: userIdsError } = await supabase
            .from('users')
            .select('username, employee_id')
            .not('employee_id', 'is', null);

        const { data: hrEmployeeIds, error: hrIdsError } = await supabase
            .from('hr_employees')
            .select('id, employee_id, name');

        if (!userIdsError && !hrIdsError) {
            console.log('Users with employee_id:');
            console.table(userEmployeeIds);
            console.log('\nHR Employees:');
            console.table(hrEmployeeIds);
            
            // Check for matches
            console.log('\n7. Looking for matches:');
            if (userEmployeeIds && hrEmployeeIds) {
                userEmployeeIds.forEach(user => {
                    const matchingEmployee = hrEmployeeIds.find(emp => emp.id === user.employee_id);
                    if (matchingEmployee) {
                        console.log(`✅ ${user.username} -> ${matchingEmployee.name} (${matchingEmployee.employee_id})`);
                    } else {
                        console.log(`❌ ${user.username} -> No matching employee for ID: ${user.employee_id}`);
                    }
                });
            }
        }

        // 8. Test the exact query used in the component
        console.log('\n8. Testing Component Query:');
        const { data: componentQuery, error: componentError } = await supabase
            .from('users')
            .select(`
                id,
                username,
                role_type,
                employee_id,
                branch_id,
                hr_employees!inner(
                    id,
                    name,
                    employee_id,
                    branch_id
                ),
                branches(
                    id,
                    name_en
                )
            `)
            .limit(3);

        if (componentError) {
            console.error('Component Query Error:', componentError);
            console.error('Full Error Details:', JSON.stringify(componentError, null, 2));
            
            // Try without inner join
            console.log('\n8b. Testing without inner join:');
            const { data: simpleQuery, error: simpleError } = await supabase
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
                console.table(simpleQuery);
            }
        } else {
            console.log('Component query results:');
            console.log(JSON.stringify(componentQuery, null, 2));
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