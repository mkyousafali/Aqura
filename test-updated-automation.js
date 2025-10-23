// Comprehensive Test Script for Updated Payment Automation
// Tests cash-on-delivery auto-payment and manual payment processing
// File: test-updated-automation.js

import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcyOTY5NjkzNCwiZXhwIjoyMDQ1MjcyOTM0fQ.d8lXMGXhWVNjV3dT_C4l4mQlbtGV3UBqG6FKyYGUu_o';

const supabase = createClient(supabaseUrl, supabaseKey);

async function testUpdatedAutomation() {
    console.log('🧪 COMPREHENSIVE PAYMENT AUTOMATION TEST');
    console.log('==========================================');
    
    try {
        // Test 1: Cash-on-Delivery Auto-Payment
        console.log('\n📋 TEST 1: Cash-on-Delivery Auto-Payment');
        console.log('------------------------------------------');
        
        // Get a receiving record with accountant
        const { data: receivingRecords } = await supabase
            .from('receiving_records')
            .select('id, user_id, accountant_user_id, branch_id, vendor_name, bill_number, bill_amount, final_bill_amount')
            .not('accountant_user_id', 'is', null)
            .limit(1);
        
        if (!receivingRecords || receivingRecords.length === 0) {
            console.log('❌ No receiving records with accountant found');
            return;
        }
        
        const receivingRecord = receivingRecords[0];
        console.log('✓ Using receiving record:', receivingRecord.id);
        console.log('✓ Accountant assigned:', receivingRecord.accountant_user_id);
        
        // Create cash-on-delivery payment schedule
        const codPayment = {
            receiving_record_id: receivingRecord.id,
            bill_number: 'COD-TEST-' + Date.now(),
            vendor_name: receivingRecord.vendor_name || 'Test Vendor COD',
            branch_id: receivingRecord.branch_id,
            bill_amount: 1500.00,
            final_bill_amount: receivingRecord.final_bill_amount || 1500.00,
            payment_method: 'cash-on-delivery', // This should trigger auto-payment
            due_date: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
            is_paid: false // Should be auto-changed to true
        };
        
        console.log('🔄 Creating cash-on-delivery payment...');
        const { data: codPaymentResult, error: codError } = await supabase
            .from('vendor_payment_schedule')
            .insert([codPayment])
            .select()
            .single();
        
        if (codError) {
            console.error('❌ COD Payment creation failed:', codError);
            return;
        }
        
        console.log('✅ COD Payment created:', codPaymentResult.id);
        console.log('✓ Auto-marked as paid:', codPaymentResult.is_paid);
        console.log('✓ Paid date set:', codPaymentResult.paid_date);
        
        // Wait a moment for triggers to complete
        await new Promise(resolve => setTimeout(resolve, 2000));
        
        // Check if payment transaction was created
        const { data: codTransaction } = await supabase
            .from('payment_transactions')
            .select('*')
            .eq('payment_schedule_id', codPaymentResult.id)
            .single();
        
        if (codTransaction) {
            console.log('✅ Payment transaction created:', codTransaction.id);
            console.log('✓ Amount:', codTransaction.amount);
            console.log('✓ Accountant assigned:', codTransaction.accountant_user_id);
        } else {
            console.log('❌ Payment transaction NOT created');
        }
        
        // Check if task was created
        const { data: codTask } = await supabase
            .from('tasks')
            .select('*')
            .eq('id', codTransaction?.task_id)
            .single();
        
        if (codTask) {
            console.log('✅ Task created:', codTask.id);
            console.log('✓ Title:', codTask.title);
            console.log('✓ Priority:', codTask.priority);
            console.log('✓ Requires task finished:', codTask.require_task_finished);
            console.log('✓ Requires photo upload:', codTask.require_photo_upload);
            console.log('✓ Requires ERP reference:', codTask.require_erp_reference);
        } else {
            console.log('❌ Task NOT created');
        }
        
        // Check if task assignment was created
        const { data: codAssignment } = await supabase
            .from('task_assignments')
            .select('*')
            .eq('task_id', codTask?.id)
            .single();
        
        if (codAssignment) {
            console.log('✅ Task assignment created:', codAssignment.id);
            console.log('✓ Assigned to:', codAssignment.assigned_to_user_id);
            console.log('✓ Status:', codAssignment.status);
        } else {
            console.log('❌ Task assignment NOT created');
        }
        
        // Check if notification was sent
        const { data: codNotification } = await supabase
            .from('notifications')
            .select('*')
            .eq('task_id', codTask?.id)
            .single();
        
        if (codNotification) {
            console.log('✅ Notification sent:', codNotification.id);
            console.log('✓ Title:', codNotification.title);
            console.log('✓ Type:', codNotification.type);
            console.log('✓ Priority:', codNotification.priority);
        } else {
            console.log('❌ Notification NOT sent');
        }
        
        // Test 2: Manual Payment Processing
        console.log('\n📋 TEST 2: Manual Payment Processing');
        console.log('-------------------------------------');
        
        // Create regular payment schedule (not cash-on-delivery)
        const regularPayment = {
            receiving_record_id: receivingRecord.id,
            bill_number: 'REG-TEST-' + Date.now(),
            vendor_name: receivingRecord.vendor_name || 'Test Vendor Regular',
            branch_id: receivingRecord.branch_id,
            bill_amount: 2000.00,
            final_bill_amount: receivingRecord.final_bill_amount || 2000.00,
            payment_method: 'bank_transfer',
            bank_name: 'Test Bank',
            iban: 'SA1234567890123456789012',
            due_date: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
            is_paid: false
        };
        
        console.log('🔄 Creating regular payment schedule...');
        const { data: regularPaymentResult, error: regularError } = await supabase
            .from('vendor_payment_schedule')
            .insert([regularPayment])
            .select()
            .single();
        
        if (regularError) {
            console.error('❌ Regular payment creation failed:', regularError);
            return;
        }
        
        console.log('✅ Regular payment created:', regularPaymentResult.id);
        console.log('✓ Initially unpaid:', !regularPaymentResult.is_paid);
        
        // Wait a moment
        await new Promise(resolve => setTimeout(resolve, 1000));
        
        // Now manually mark as paid
        console.log('🔄 Manually marking payment as paid...');
        const { data: updatedPayment, error: updateError } = await supabase
            .from('vendor_payment_schedule')
            .update({ 
                is_paid: true,
                paid_date: new Date().toISOString(),
                payment_status: 'paid'
            })
            .eq('id', regularPaymentResult.id)
            .select()
            .single();
        
        if (updateError) {
            console.error('❌ Payment update failed:', updateError);
            return;
        }
        
        console.log('✅ Payment marked as paid:', updatedPayment.is_paid);
        
        // Wait for triggers to complete
        await new Promise(resolve => setTimeout(resolve, 2000));
        
        // Check if automation was triggered
        const { data: regularTransaction } = await supabase
            .from('payment_transactions')
            .select('*')
            .eq('payment_schedule_id', regularPaymentResult.id)
            .single();
        
        if (regularTransaction) {
            console.log('✅ Payment transaction created:', regularTransaction.id);
            console.log('✓ Amount:', regularTransaction.amount);
            console.log('✓ Payment method:', regularTransaction.payment_method);
        } else {
            console.log('❌ Payment transaction NOT created');
        }
        
        // Check if task was created
        const { data: regularTask } = await supabase
            .from('tasks')
            .select('*')
            .eq('id', regularTransaction?.task_id)
            .single();
        
        if (regularTask) {
            console.log('✅ Task created:', regularTask.id);
            console.log('✓ Title matches requirement:', regularTask.title.includes('New payment made — enter into the ERP'));
            console.log('✓ Description includes vendor name:', regularTask.description.includes(regularPayment.vendor_name));
        } else {
            console.log('❌ Task NOT created');
        }
        
        // Test 3: Verify Accountant Assignment Logic
        console.log('\n📋 TEST 3: Accountant Assignment Verification');
        console.log('----------------------------------------------');
        
        // Get user details for both transactions
        if (codTransaction?.accountant_user_id) {
            const { data: codAccountant } = await supabase
                .from('users')
                .select('id, username, role_type, branch_id')
                .eq('id', codTransaction.accountant_user_id)
                .single();
            
            console.log('✅ COD Accountant Details:');
            console.log('  - Username:', codAccountant?.username);
            console.log('  - Role:', codAccountant?.role_type);
            console.log('  - Branch ID:', codAccountant?.branch_id);
            console.log('  - Source: Receiving Record');
        }
        
        if (regularTransaction?.accountant_user_id) {
            const { data: regularAccountant } = await supabase
                .from('users')
                .select('id, username, role_type, branch_id')
                .eq('id', regularTransaction.accountant_user_id)
                .single();
            
            console.log('✅ Regular Payment Accountant Details:');
            console.log('  - Username:', regularAccountant?.username);
            console.log('  - Role:', regularAccountant?.role_type);
            console.log('  - Branch ID:', regularAccountant?.branch_id);
        }
        
        // Test Summary
        console.log('\n📊 TEST SUMMARY');
        console.log('================');
        console.log('✓ Cash-on-Delivery Auto-Payment:', codPaymentResult?.is_paid ? '✅ PASS' : '❌ FAIL');
        console.log('✓ Payment Transactions Created:', (codTransaction && regularTransaction) ? '✅ PASS' : '❌ FAIL');
        console.log('✓ Tasks Created with Correct Format:', (codTask && regularTask) ? '✅ PASS' : '❌ FAIL');
        console.log('✓ Task Assignments Created:', (codAssignment) ? '✅ PASS' : '❌ FAIL');
        console.log('✓ Notifications Sent:', (codNotification) ? '✅ PASS' : '❌ FAIL');
        console.log('✓ Accountant from Receiving Record:', codTransaction?.accountant_user_id === receivingRecord.accountant_user_id ? '✅ PASS' : '❌ FAIL');
        
        // Cleanup - Remove test records
        console.log('\n🧹 CLEANUP');
        console.log('-----------');
        
        const testIds = [codPaymentResult.id, regularPaymentResult.id].filter(Boolean);
        if (testIds.length > 0) {
            await supabase
                .from('vendor_payment_schedule')
                .delete()
                .in('id', testIds);
            console.log('✅ Test payment schedules removed');
        }
        
    } catch (error) {
        console.error('❌ Test failed with error:', error);
    }
}

// Run the comprehensive test
testUpdatedAutomation().then(() => {
    console.log('\n🎯 Test completed!');
    process.exit(0);
}).catch(error => {
    console.error('💥 Test suite failed:', error);
    process.exit(1);
});