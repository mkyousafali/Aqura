// Quick Check Script for Payment Automation
// Tests current state before implementing new requirements

import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcyOTY5NjkzNCwiZXhwIjoyMDQ1MjcyOTM0fQ.d8lXMGXhWVNjV3dT_C4l4mQlbtGV3UBqG6FKyYGUu_o';

const supabase = createClient(supabaseUrl, supabaseKey);

async function quickCheck() {
    console.log('🔍 QUICK AUTOMATION CHECK');
    console.log('=========================');
    
    try {
        // Check receiving records
        const { data: receivingRecords } = await supabase
            .from('receiving_records')
            .select('id, user_id, accountant_user_id, branch_id, vendor_name, bill_number, final_bill_amount')
            .limit(5);
        
        console.log('📋 Available receiving records:', receivingRecords?.length || 0);
        
        if (receivingRecords && receivingRecords.length > 0) {
            const recordsWithAccountant = receivingRecords.filter(r => r.accountant_user_id);
            const recordsWithoutAccountant = receivingRecords.filter(r => !r.accountant_user_id);
            
            console.log('✓ Records with accountant:', recordsWithAccountant.length);
            console.log('✓ Records without accountant:', recordsWithoutAccountant.length);
            
            if (recordsWithAccountant.length > 0) {
                console.log('✅ Sample record with accountant:', recordsWithAccountant[0]);
            }
            
            if (recordsWithoutAccountant.length > 0) {
                console.log('⚠️ Sample record without accountant:', recordsWithoutAccountant[0]);
            }
        }
        
        // Check current payment schedules
        const { data: paymentSchedules } = await supabase
            .from('vendor_payment_schedule')
            .select('id, payment_method, is_paid, receiving_record_id')
            .limit(10);
        
        console.log('\n💰 Current payment schedules:', paymentSchedules?.length || 0);
        
        if (paymentSchedules && paymentSchedules.length > 0) {
            const codPayments = paymentSchedules.filter(p => 
                p.payment_method && 
                (p.payment_method.toLowerCase().includes('cash') || 
                 p.payment_method.toLowerCase().includes('cod'))
            );
            const paidPayments = paymentSchedules.filter(p => p.is_paid);
            const unpaidPayments = paymentSchedules.filter(p => !p.is_paid);
            
            console.log('💵 Cash-on-delivery payments:', codPayments.length);
            console.log('✅ Paid payments:', paidPayments.length);
            console.log('⏳ Unpaid payments:', unpaidPayments.length);
            
            if (codPayments.length > 0) {
                console.log('📋 Sample cash payment:', codPayments[0]);
            }
        }
        
        // Check users for accountant assignment
        const { data: users } = await supabase
            .from('users')
            .select('id, username, role_type, status, branch_id')
            .eq('status', 'active')
            .limit(10);
        
        console.log('\n👥 Active users:', users?.length || 0);
        
        if (users && users.length > 0) {
            const accountants = users.filter(u => 
                u.role_type && u.role_type.toLowerCase().includes('accountant')
            );
            const managers = users.filter(u => 
                u.role_type && (u.role_type.toLowerCase().includes('manager') || u.role_type.toLowerCase().includes('admin'))
            );
            
            console.log('👤 Accountant users:', accountants.length);
            console.log('👔 Manager/Admin users:', managers.length);
            
            if (accountants.length > 0) {
                console.log('📋 Sample accountant:', accountants[0]);
            }
        }
        
        // Check current automation state
        const { data: currentTriggers, error: triggerError } = await supabase
            .rpc('get_trigger_info', {})
            .catch(() => ({ data: null, error: 'Function not available' }));
        
        console.log('\n🔧 AUTOMATION STATUS');
        console.log('Current trigger function exists:', triggerError ? 'Unknown' : 'Yes');
        
        // Suggest next steps
        console.log('\n📝 RECOMMENDATIONS');
        console.log('===================');
        
        if (receivingRecords && receivingRecords.length > 0) {
            const firstRecord = receivingRecords[0];
            
            if (!firstRecord.accountant_user_id && users && users.length > 0) {
                console.log('1. ✨ Assign accountant to receiving record');
                console.log(`   UPDATE receiving_records SET accountant_user_id = '${users[0].id}' WHERE id = '${firstRecord.id}';`);
            }
            
            console.log('2. 🔄 Apply the updated migration');
            console.log('   Execute UPDATED-MIGRATION-59-COMPREHENSIVE.sql in Supabase SQL Editor');
            
            console.log('3. 🧪 Test cash-on-delivery automation');
            console.log('   Create a cash-on-delivery payment schedule to test auto-payment');
            
            console.log('4. ✅ Test manual payment marking');
            console.log('   Mark existing payments as paid to test task creation');
        }
        
    } catch (error) {
        console.error('❌ Error during check:', error);
    }
}

quickCheck().then(() => {
    console.log('\n🎯 Quick check completed!');
    process.exit(0);
}).catch(error => {
    console.error('💥 Check failed:', error);
    process.exit(1);
});