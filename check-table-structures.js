import { createClient } from '@supabase/supabase-js';

// Supabase configuration
const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function checkTableStructures() {
  console.log('🔍 Checking table structures...\n');
  
  try {
    // Check users table structure
    console.log('👤 Users table structure:');
    const { data: users, error: usersError } = await supabase
      .from('users')
      .select('*')
      .limit(1);
    
    if (usersError) {
      console.log('❌ Error fetching users:', usersError);
    } else if (users && users.length > 0) {
      console.log('📋 Users table columns:', Object.keys(users[0]));
    }
    
    // Check user_roles table
    console.log('\n🔐 User roles table:');
    const { data: userRoles, error: rolesError } = await supabase
      .from('user_roles')
      .select('*')
      .limit(3);
    
    if (rolesError) {
      console.log('❌ Error fetching user roles:', rolesError);
    } else {
      console.log('📋 User roles found:', userRoles?.length || 0);
      userRoles?.forEach(role => {
        console.log(`  - User ${role.user_id}: ${role.role_name}`);
      });
    }
    
    // Find accountant users properly
    console.log('\n👤 Finding accountant users:');
    const { data: accountantRoles, error: accountantError } = await supabase
      .from('user_roles')
      .select(`
        user_id,
        role_name,
        users (
          id,
          email,
          is_active,
          created_at
        )
      `)
      .eq('role_name', 'accountant');
    
    if (accountantError) {
      console.log('❌ Error fetching accountant roles:', accountantError);
    } else {
      console.log(`📋 Found ${accountantRoles?.length || 0} accountant role assignments`);
      accountantRoles?.forEach(role => {
        console.log(`  - User ${role.user_id} (${role.users?.email}): Active = ${role.users?.is_active}`);
      });
    }
    
    // Check payment_transactions table issues
    console.log('\n💳 Payment transactions missing data:');
    const { data: transactions, error: transError } = await supabase
      .from('payment_transactions')
      .select(`
        id,
        bill_number,
        vendor_name,
        task_id,
        task_assignment_id,
        accountant_user_id
      `)
      .or('task_assignment_id.is.null,accountant_user_id.is.null');
    
    if (transError) {
      console.log('❌ Error fetching transactions:', transError);
    } else {
      console.log(`📋 Transactions with missing data: ${transactions?.length || 0}`);
      transactions?.forEach(trans => {
        console.log(`  - ${trans.bill_number}: Task=${trans.task_id ? '✅' : '❌'}, Assignment=${trans.task_assignment_id ? '✅' : '❌'}, Accountant=${trans.accountant_user_id ? '✅' : '❌'}`);
      });
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

checkTableStructures();