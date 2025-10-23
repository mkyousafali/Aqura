#!/usr/bin/env node

import { createClient } from '@supabase/supabase-js';

// Supabase configuration
const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function checkAndFixAutomation() {
  console.log('🔍 Checking payment automation system...');
  
  try {
    // Check if we have paid payments that should have transactions
    console.log('📊 Checking paid vendor payments without transactions...');
    
    const { data: paidPayments, error: paidError } = await supabase
      .from('vendor_payment_schedule')
      .select(`
        id,
        final_bill_amount,
        receiving_record_id,
        vendor_id,
        branch_id,
        is_paid,
        paid_date,
        bill_number,
        vendor_name,
        payment_method,
        bank_name,
        iban
      `)
      .eq('is_paid', true);
      
    if (paidError) {
      console.error('❌ Error checking paid payments:', paidError);
      return;
    }
    
    console.log(`📋 Found ${paidPayments?.length || 0} paid payments`);
    
    if (!paidPayments || paidPayments.length === 0) {
      console.log('ℹ️  No paid payments found to process');
      return;
    }
    
    // Check how many of these have payment transactions
    const paymentScheduleIds = paidPayments.map(p => p.id);
    
    const { data: existingTransactions, error: transError } = await supabase
      .from('payment_transactions')
      .select('payment_schedule_id')
      .in('payment_schedule_id', paymentScheduleIds);
      
    if (transError) {
      console.error('❌ Error checking existing transactions:', transError);
      return;
    }
    
    const existingTransactionScheduleIds = existingTransactions?.map(t => t.payment_schedule_id) || [];
    const missingTransactions = paidPayments.filter(p => !existingTransactionScheduleIds.includes(p.id));
    
    console.log(`🔍 Found ${missingTransactions.length} paid payments without transactions`);
    
    if (missingTransactions.length === 0) {
      console.log('✅ All paid payments already have transactions!');
      return;
    }
    
    // Manually create missing payment transactions and tasks
    for (const payment of missingTransactions) {
      console.log(`⚡ Creating transaction for payment ${payment.id}...`);
      
      try {
        // Create payment transaction
        const transactionData = {
          receiving_record_id: payment.receiving_record_id,
          payment_schedule_id: payment.id,
          amount: payment.final_bill_amount,
          transaction_date: payment.paid_date || new Date().toISOString(),
          reference_number: `AUTO-${payment.id.slice(-8)}-${Date.now()}`,
          payment_method: payment.payment_method || 'Cash on Delivery',
          bank_name: payment.bank_name,
          iban: payment.iban,
          vendor_name: payment.vendor_name,
          bill_number: payment.bill_number,
          verification_status: 'pending',
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        };
        
        const { data: newTransaction, error: transactionError } = await supabase
          .from('payment_transactions')
          .insert(transactionData)
          .select()
          .single();
          
        if (transactionError) {
          console.error(`❌ Error creating transaction for payment ${payment.id}:`, transactionError);
          continue;
        }
        
        console.log(`✅ Created transaction ${newTransaction.id} for payment ${payment.id}`);
        
        // Create task for accountant
        const taskData = {
          title: `Payment Processing - ${payment.bill_number}`,
          description: `Process payment transaction for ${payment.vendor_name} - Amount: ${payment.final_bill_amount} SAR. Transaction ID: ${transactionResult.data[0].id}`,
          status: 'pending',
          priority: 'medium',
          require_task_finished: false,
          require_photo_upload: false,
          require_erp_reference: true,
          can_escalate: true,
          can_reassign: true,
          created_by: 'system',
          created_by_name: 'Payment Automation System',
          created_by_role: 'system',
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        };
        
        const { data: newTask, error: taskError } = await supabase
          .from('tasks')
          .insert(taskData)
          .select()
          .single();
          
        if (taskError) {
          console.error(`❌ Error creating task for payment ${payment.id}:`, taskError);
          continue;
        }
        
        console.log(`✅ Created task ${newTask.id} for payment ${payment.id}`);
        
        // Assign task to accountants (you may need to modify this based on your user roles)
        // For now, we'll just create the task without assignment
        
      } catch (error) {
        console.error(`❌ Error processing payment ${payment.id}:`, error);
      }
    }
    
    console.log('🎉 Payment automation fix completed!');
    
  } catch (error) {
    console.error('❌ Automation check failed:', error);
  }
}

// Run the check and fix
checkAndFixAutomation();