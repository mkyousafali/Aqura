import { createClient } from '@supabase/supabase-js';

// Supabase configuration
const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function diagnoseMigration59Issues() {
  console.log('🔍 Diagnosing Migration 59 Issues...\n');
  
  try {
    // 1. Check if the function exists and triggers are active
    console.log('📋 Step 1: Checking function and trigger existence...');
    
    // 2. Check user_roles table structure and data
    console.log('\n📋 Step 2: Checking user_roles structure...');
    const { data: userRoles, error: rolesError } = await supabase
      .from('user_roles')
      .select('*');
    
    if (rolesError) {
      console.log('❌ Error fetching user_roles:', rolesError);
    } else {
      console.log(`📊 Total user_roles records: ${userRoles?.length || 0}`);
      if (userRoles && userRoles.length > 0) {
        console.log('📋 User roles structure:', Object.keys(userRoles[0]));
        console.log('📋 Sample user roles:');
        userRoles.slice(0, 5).forEach(role => {
          console.log(`  - User: ${role.user_id}, Role: ${role.role_name || role.role_type || 'undefined'}`);
        });
        
        // Check if there are any 'accountant' roles
        const accountantRoles = userRoles.filter(role => 
          (role.role_name && role.role_name.toLowerCase().includes('account')) ||
          (role.role_type && role.role_type.toLowerCase().includes('account'))
        );
        console.log(`📊 Accountant roles found: ${accountantRoles.length}`);
      }
    }
    
    // 3. Check users table and their roles
    console.log('\n📋 Step 3: Checking users table...');
    const { data: users, error: usersError } = await supabase
      .from('users')
      .select('id, username, role_type, status, branch_id')
      .eq('status', 'active')
      .limit(10);
    
    if (usersError) {
      console.log('❌ Error fetching users:', usersError);
    } else {
      console.log(`📊 Active users: ${users?.length || 0}`);
      users?.forEach(user => {
        console.log(`  - ${user.username}: ${user.role_type} (Branch: ${user.branch_id || 'None'})`);
      });
    }
    
    // 4. Check what happens when we simulate the trigger logic
    console.log('\n🧪 Step 4: Simulating trigger logic...');
    
    // Get a sample payment schedule that's paid
    const { data: samplePayment, error: paymentError } = await supabase
      .from('vendor_payment_schedule')
      .select('*')
      .eq('is_paid', true)
      .limit(1)
      .single();
    
    if (paymentError) {
      console.log('❌ Error fetching sample payment:', paymentError);
    } else {
      console.log(`📋 Sample paid payment: ${samplePayment.bill_number}`);
      
      // Check if receiving record exists
      const { data: receivingRecord, error: receivingError } = await supabase
        .from('receiving_records')
        .select('*')
        .eq('id', samplePayment.receiving_record_id)
        .single();
      
      if (receivingError) {
        console.log('❌ Receiving record not found:', receivingError);
      } else {
        console.log(`✅ Receiving record exists: ID ${receivingRecord.id}, Branch: ${receivingRecord.branch_id}`);
        
        // Try to find accountant using the same logic as the trigger
        const { data: accountantCheck, error: accountantError } = await supabase
          .from('users')
          .select(`
            id, 
            username, 
            role_type, 
            status, 
            branch_id,
            user_roles (
              role_name
            )
          `)
          .eq('status', 'active');
        
        if (accountantError) {
          console.log('❌ Error checking accountant logic:', accountantError);
        } else {
          console.log('👥 Users with roles check:');
          accountantCheck?.slice(0, 3).forEach(user => {
            console.log(`  - ${user.username}: Role=${user.role_type}, Roles=${JSON.stringify(user.user_roles)}`);
          });
        }
      }
    }
    
    // 5. Check recent payment transaction creation patterns
    console.log('\n📋 Step 5: Checking recent transaction patterns...');
    const { data: recentTransactions, error: transError } = await supabase
      .from('payment_transactions')
      .select(`
        id,
        bill_number,
        task_id,
        task_assignment_id,
        accountant_user_id,
        verification_status,
        created_at
      `)
      .order('created_at', { ascending: false })
      .limit(10);
    
    if (transError) {
      console.log('❌ Error fetching recent transactions:', transError);
    } else {
      console.log(`📊 Recent transactions: ${recentTransactions?.length || 0}`);
      recentTransactions?.forEach(trans => {
        const created = new Date(trans.created_at);
        const isRecent = Date.now() - created.getTime() < 24 * 60 * 60 * 1000; // Within 24 hours
        console.log(`  - ${trans.bill_number} (${created.toISOString().substring(0, 19)})`);
        console.log(`    Task: ${trans.task_id ? '✅' : '❌'}, Assignment: ${trans.task_assignment_id ? '✅' : '❌'}, Accountant: ${trans.accountant_user_id ? '✅' : '❌'}`);
        console.log(`    Recent: ${isRecent ? '🕐' : '📅'}`);
      });
    }
    
    // 6. Test the trigger by creating and updating a payment
    console.log('\n🧪 Step 6: Testing trigger with real data...');
    
    // Get a receiving record
    const { data: testReceivingRecord, error: testReceivingError } = await supabase
      .from('receiving_records')
      .select('id, user_id, branch_id')
      .limit(1)
      .single();
    
    if (!testReceivingError && testReceivingRecord) {
      const testBillNumber = `DIAG-TEST-${Date.now()}`;
      
      // Create test payment schedule
      const { data: testPayment, error: createError } = await supabase
        .from('vendor_payment_schedule')
        .insert({
          receiving_record_id: testReceivingRecord.id,
          bill_number: testBillNumber,
          vendor_name: 'Diagnostic Test Vendor',
          final_bill_amount: 123.45,
          payment_method: 'Bank Transfer',
          bank_name: 'Test Bank',
          iban: 'SA1234567890',
          due_date: new Date().toISOString().split('T')[0],
          is_paid: false
        })
        .select()
        .single();
      
      if (!createError) {
        console.log(`🧪 Created test payment: ${testBillNumber}`);
        
        // Wait a moment
        await new Promise(resolve => setTimeout(resolve, 2000));
        
        // Update to paid (this should trigger the automation)
        console.log('⚡ Marking payment as paid to trigger automation...');
        const { error: updateError } = await supabase
          .from('vendor_payment_schedule')
          .update({ 
            is_paid: true,
            paid_date: new Date().toISOString()
          })
          .eq('id', testPayment.id);
        
        if (!updateError) {
          console.log('✅ Updated payment to paid status');
          
          // Wait for trigger to process
          await new Promise(resolve => setTimeout(resolve, 5000));
          
          // Check if transaction was created
          const { data: createdTransaction, error: checkError } = await supabase
            .from('payment_transactions')
            .select('*')
            .eq('payment_schedule_id', testPayment.id)
            .single();
          
          if (!checkError && createdTransaction) {
            console.log('🎉 SUCCESS: Trigger created transaction!');
            console.log(`   Transaction ID: ${createdTransaction.id}`);
            console.log(`   Task ID: ${createdTransaction.task_id || 'NULL'}`);
            console.log(`   Assignment ID: ${createdTransaction.task_assignment_id || 'NULL'}`);
            console.log(`   Accountant ID: ${createdTransaction.accountant_user_id || 'NULL'}`);
            
            // Check if task was created
            if (createdTransaction.task_id) {
              const { data: createdTask, error: taskCheckError } = await supabase
                .from('tasks')
                .select('id, title, status')
                .eq('id', createdTransaction.task_id)
                .single();
              
              if (!taskCheckError && createdTask) {
                console.log(`✅ Task created: ${createdTask.title} (${createdTask.status})`);
              }
            }
            
            // Cleanup test data
            console.log('🧹 Cleaning up test data...');
            await supabase.from('payment_transactions').delete().eq('id', createdTransaction.id);
            if (createdTransaction.task_id) {
              await supabase.from('tasks').delete().eq('id', createdTransaction.task_id);
            }
            if (createdTransaction.task_assignment_id) {
              await supabase.from('task_assignments').delete().eq('id', createdTransaction.task_assignment_id);
            }
            
          } else {
            console.log('❌ FAILED: No transaction created by trigger');
            console.log('Error:', checkError);
          }
          
          // Cleanup test payment
          await supabase.from('vendor_payment_schedule').delete().eq('id', testPayment.id);
        } else {
          console.log('❌ Error updating payment:', updateError);
        }
      } else {
        console.log('❌ Error creating test payment:', createError);
      }
    }
    
    console.log('\n📊 Diagnosis Complete!');
    
  } catch (error) {
    console.error('❌ Error during diagnosis:', error);
  }
}

diagnoseMigration59Issues();