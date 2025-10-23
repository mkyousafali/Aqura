import { createClient } from '@supabase/supabase-js';

// Supabase configuration
const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function analyzeAndFixPaymentTransactions() {
  console.log('🔍 Complete analysis and fix of payment_transactions table...\n');
  
  try {
    // 1. Get complete overview of payment_transactions table
    console.log('📊 Step 1: Getting complete payment_transactions data...');
    const { data: allTransactions, error: transactionError } = await supabase
      .from('payment_transactions')
      .select(`
        id,
        payment_schedule_id,
        receiving_record_id,
        receiver_user_id,
        accountant_user_id,
        task_id,
        task_assignment_id,
        transaction_date,
        amount,
        payment_method,
        bank_name,
        iban,
        vendor_name,
        bill_number,
        verification_status,
        created_at,
        updated_at
      `)
      .order('created_at', { ascending: false });
    
    if (transactionError) {
      console.log('❌ Error fetching transactions:', transactionError);
      return;
    }
    
    console.log(`📋 Total payment transactions: ${allTransactions.length}\n`);
    
    // 2. Analyze data quality issues
    console.log('🔍 Step 2: Analyzing data quality issues...');
    
    let issuesFound = {
      missingTaskId: [],
      missingTaskAssignmentId: [],
      missingAccountantUserId: [],
      missingPaymentMethod: [],
      missingBankInfo: [],
      invalidVerificationStatus: [],
      missingTransactionDate: []
    };
    
    allTransactions.forEach(transaction => {
      if (!transaction.task_id) {
        issuesFound.missingTaskId.push(transaction);
      }
      if (!transaction.task_assignment_id) {
        issuesFound.missingTaskAssignmentId.push(transaction);
      }
      if (!transaction.accountant_user_id) {
        issuesFound.missingAccountantUserId.push(transaction);
      }
      if (!transaction.payment_method) {
        issuesFound.missingPaymentMethod.push(transaction);
      }
      if (!transaction.bank_name || !transaction.iban) {
        issuesFound.missingBankInfo.push(transaction);
      }
      if (!['pending', 'verified', 'rejected'].includes(transaction.verification_status)) {
        issuesFound.invalidVerificationStatus.push(transaction);
      }
      if (!transaction.transaction_date) {
        issuesFound.missingTransactionDate.push(transaction);
      }
    });
    
    console.log('📊 Issues found:');
    console.log(`  - Missing task_id: ${issuesFound.missingTaskId.length}`);
    console.log(`  - Missing task_assignment_id: ${issuesFound.missingTaskAssignmentId.length}`);
    console.log(`  - Missing accountant_user_id: ${issuesFound.missingAccountantUserId.length}`);
    console.log(`  - Missing payment_method: ${issuesFound.missingPaymentMethod.length}`);
    console.log(`  - Missing bank info: ${issuesFound.missingBankInfo.length}`);
    console.log(`  - Invalid verification_status: ${issuesFound.invalidVerificationStatus.length}`);
    console.log(`  - Missing transaction_date: ${issuesFound.missingTransactionDate.length}\n`);
    
    // 3. Get corresponding vendor payment schedule data
    console.log('📋 Step 3: Getting vendor payment schedule data for comparison...');
    const paymentScheduleIds = allTransactions.map(t => t.payment_schedule_id);
    
    const { data: paymentSchedules, error: scheduleError } = await supabase
      .from('vendor_payment_schedule')
      .select(`
        id,
        receiving_record_id,
        bill_number,
        vendor_name,
        final_bill_amount,
        payment_method,
        bank_name,
        iban,
        is_paid,
        paid_date,
        due_date,
        created_at,
        updated_at
      `)
      .in('id', paymentScheduleIds);
    
    if (scheduleError) {
      console.log('❌ Error fetching payment schedules:', scheduleError);
    } else {
      console.log(`📋 Found ${paymentSchedules.length} corresponding payment schedules\n`);
    }
    
    // 4. Find an accountant user for assignments
    console.log('👤 Step 4: Finding accountant users...');
    const { data: accountants, error: accountantError } = await supabase
      .from('users')
      .select('id, name, email')
      .contains('role', ['accountant'])
      .eq('is_active', true);
    
    if (accountantError) {
      console.log('❌ Error fetching accountants:', accountantError);
    } else {
      console.log(`👤 Found ${accountants?.length || 0} active accountants`);
      accountants?.forEach(acc => {
        console.log(`  - ${acc.name} (${acc.email})`);
      });
    }
    
    const defaultAccountant = accountants?.[0];
    
    // 5. Fix missing task_ids by creating tasks
    console.log('\n🔧 Step 5: Fixing missing tasks...');
    for (const transaction of issuesFound.missingTaskId) {
      console.log(`⚡ Creating task for transaction ${transaction.bill_number}...`);
      
      const { data: taskData, error: taskError } = await supabase
        .from('tasks')
        .insert({
          title: `Payment Processing - ${transaction.bill_number}`,
          description: `Process payment transaction for ${transaction.vendor_name} - Amount: ${transaction.amount} SAR\n\nTransaction ID: ${transaction.id}\nPayment Method: ${transaction.payment_method || 'N/A'}\nBank: ${transaction.bank_name || 'N/A'}\n\nPlease verify payment details and complete the transaction processing.`,
          status: 'active',
          priority: 'high',
          require_task_finished: true,
          require_photo_upload: false,
          require_erp_reference: true,
          can_escalate: true,
          can_reassign: true,
          created_by: 'system',
          created_by_name: 'Payment Data Fix',
          created_by_role: 'system',
          due_date: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString().split('T')[0]
        })
        .select()
        .single();
      
      if (taskError) {
        console.log(`❌ Error creating task for ${transaction.bill_number}:`, taskError);
        continue;
      }
      
      // Update transaction with task_id
      const { error: updateError } = await supabase
        .from('payment_transactions')
        .update({ 
          task_id: taskData.id,
          updated_at: new Date().toISOString()
        })
        .eq('id', transaction.id);
      
      if (updateError) {
        console.log(`❌ Error updating transaction with task_id:`, updateError);
      } else {
        console.log(`✅ Created and linked task ${taskData.id} for transaction ${transaction.bill_number}`);
      }
      
      // Create task assignment if we have an accountant
      if (defaultAccountant) {
        const { error: assignmentError } = await supabase
          .from('task_assignments')
          .insert({
            task_id: taskData.id,
            assignment_type: 'user',
            assigned_by: 'system',
            assigned_by_name: 'Payment Data Fix',
            assigned_by_role: 'system',
            assigned_to_user_id: defaultAccountant.id,
            status: 'active',
            notes: `Auto-assigned for payment processing of bill: ${transaction.bill_number}`
          })
          .select()
          .single();
        
        if (!assignmentError) {
          // Update transaction with assignment_id
          await supabase
            .from('payment_transactions')
            .update({ 
              task_assignment_id: assignmentError.data?.id,
              accountant_user_id: defaultAccountant.id
            })
            .eq('id', transaction.id);
          
          console.log(`✅ Assigned task to ${defaultAccountant.name}`);
        }
      }
    }
    
    // 6. Fix missing data from payment schedules
    console.log('\n🔧 Step 6: Fixing missing data from payment schedules...');
    const scheduleMap = new Map(paymentSchedules?.map(ps => [ps.id, ps]) || []);
    
    for (const transaction of allTransactions) {
      const schedule = scheduleMap.get(transaction.payment_schedule_id);
      if (!schedule) continue;
      
      const updates = {};
      let needsUpdate = false;
      
      // Fix missing payment method
      if (!transaction.payment_method && schedule.payment_method) {
        updates.payment_method = schedule.payment_method;
        needsUpdate = true;
      }
      
      // Fix missing bank info
      if (!transaction.bank_name && schedule.bank_name) {
        updates.bank_name = schedule.bank_name;
        needsUpdate = true;
      }
      
      if (!transaction.iban && schedule.iban) {
        updates.iban = schedule.iban;
        needsUpdate = true;
      }
      
      // Fix missing transaction date
      if (!transaction.transaction_date && schedule.paid_date) {
        updates.transaction_date = schedule.paid_date;
        needsUpdate = true;
      }
      
      // Fix missing accountant if we have one
      if (!transaction.accountant_user_id && defaultAccountant) {
        updates.accountant_user_id = defaultAccountant.id;
        needsUpdate = true;
      }
      
      // Fix verification status
      if (!['pending', 'verified', 'rejected'].includes(transaction.verification_status)) {
        updates.verification_status = 'pending';
        needsUpdate = true;
      }
      
      if (needsUpdate) {
        updates.updated_at = new Date().toISOString();
        
        const { error: updateError } = await supabase
          .from('payment_transactions')
          .update(updates)
          .eq('id', transaction.id);
        
        if (updateError) {
          console.log(`❌ Error updating transaction ${transaction.bill_number}:`, updateError);
        } else {
          console.log(`✅ Updated transaction ${transaction.bill_number} with missing data`);
        }
      }
    }
    
    // 7. Test automation by creating a new payment schedule
    console.log('\n🧪 Step 7: Testing automation with new payment...');
    
    // First, get a receiving record to use
    const { data: receivingRecord, error: receivingError } = await supabase
      .from('receiving_records')
      .select('id, user_id, branch_id')
      .limit(1)
      .single();
    
    if (!receivingError && receivingRecord) {
      // Create a test payment schedule
      const { data: testPayment, error: testPaymentError } = await supabase
        .from('vendor_payment_schedule')
        .insert({
          receiving_record_id: receivingRecord.id,
          bill_number: `TEST-${Date.now()}`,
          vendor_name: 'Test Vendor for Automation',
          final_bill_amount: 100.00,
          payment_method: 'Bank Transfer',
          bank_name: 'Test Bank',
          iban: 'SA123456789',
          due_date: new Date().toISOString().split('T')[0],
          is_paid: false // Start as unpaid
        })
        .select()
        .single();
      
      if (!testPaymentError) {
        console.log(`🧪 Created test payment: ${testPayment.bill_number}`);
        
        // Wait a moment then mark as paid to trigger automation
        await new Promise(resolve => setTimeout(resolve, 2000));
        
        const { error: markPaidError } = await supabase
          .from('vendor_payment_schedule')
          .update({ 
            is_paid: true,
            paid_date: new Date().toISOString()
          })
          .eq('id', testPayment.id);
        
        if (!markPaidError) {
          console.log('✅ Marked test payment as paid - automation should trigger');
          
          // Wait and check if transaction was created
          await new Promise(resolve => setTimeout(resolve, 3000));
          
          const { data: createdTransaction, error: checkError } = await supabase
            .from('payment_transactions')
            .select('*')
            .eq('payment_schedule_id', testPayment.id)
            .single();
          
          if (!checkError && createdTransaction) {
            console.log('🎉 SUCCESS: Automation created transaction automatically!');
            console.log(`   Transaction ID: ${createdTransaction.id}`);
            console.log(`   Task ID: ${createdTransaction.task_id || 'NULL'}`);
            
            // Clean up test data
            await supabase.from('payment_transactions').delete().eq('id', createdTransaction.id);
            if (createdTransaction.task_id) {
              await supabase.from('tasks').delete().eq('id', createdTransaction.task_id);
            }
          } else {
            console.log('⚠️  Automation may not be working - no transaction created automatically');
          }
          
          // Clean up test payment
          await supabase.from('vendor_payment_schedule').delete().eq('id', testPayment.id);
          console.log('🧹 Cleaned up test data');
        }
      }
    }
    
    console.log('\n🎉 Complete payment_transactions analysis and fix completed!');
    
  } catch (error) {
    console.error('❌ Error during analysis and fix:', error);
  }
}

analyzeAndFixPaymentTransactions();