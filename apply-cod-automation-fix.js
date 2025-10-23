// Script to apply cash-on-delivery automation fix
import { createClient } from '@supabase/supabase-js';
import * as fs from 'fs';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || 'YOUR_SERVICE_ROLE_KEY';

const supabase = createClient(supabaseUrl, supabaseKey);

async function applyCODAutomationFix() {
  console.log('🔧 Applying Cash-on-Delivery Automation Fix...\n');
  
  try {
    // Read the production-ready migration
    const migrationSQL = fs.readFileSync('PRODUCTION-READY-MIGRATION-59.sql', 'utf8');
    
    console.log('📄 Migration SQL loaded from PRODUCTION-READY-MIGRATION-59.sql');
    console.log('📝 Note: This migration includes:');
    console.log('   ✅ Auto-mark cash-on-delivery as paid on INSERT');
    console.log('   ✅ Create transaction/task when manually marked as paid on UPDATE');
    console.log('   ✅ Use accountant from receiving_records');
    console.log('   ✅ Custom task title and description');
    console.log('   ✅ Send notifications to accountants\n');
    
    console.log('⚠️  IMPORTANT: You need to apply this migration manually in Supabase SQL Editor');
    console.log('    1. Go to: https://supabase.com/dashboard/project/vmypotfsyrvuublyddyt/sql');
    console.log('    2. Copy the contents from PRODUCTION-READY-MIGRATION-59.sql');
    console.log('    3. Paste and run in the SQL Editor');
    console.log('    4. Verify no errors occurred\n');
    
    // Alternative: Try to detect if the trigger exists
    const { data: functions, error: fnError } = await supabase
      .rpc('pg_get_functiondef', { funcoid: 'auto_create_payment_transaction_and_task'::regproc })
      .single();
    
    if (fnError) {
      console.log('❌ Could not check if function exists:', fnError.message);
      console.log('   This is expected if you haven\'t applied the migration yet.\n');
    } else {
      console.log('✅ Function exists in database');
      console.log('   Checking if it has cash-on-delivery logic...\n');
      
      const functionDef = functions?.pg_get_functiondef || '';
      const hasCODLogic = functionDef.includes('cash-on-delivery') || functionDef.includes('v_is_cash_on_delivery');
      
      if (hasCODLogic) {
        console.log('✅ Cash-on-delivery logic is present in the function!');
        console.log('   The automation should be working correctly.\n');
        
        // Test with actual data
        console.log('🧪 Testing with actual cash-on-delivery payments...\n');
        
        const { data: codPayments, error: codError } = await supabase
          .from('vendor_payment_schedule')
          .select('id, bill_number, payment_method, is_paid, paid_date')
          .or('payment_method.ilike.%cash on delivery%,payment_method.ilike.%cod%')
          .limit(5);
        
        if (codError) {
          console.log('❌ Error fetching COD payments:', codError);
        } else {
          console.log(`📋 Found ${codPayments?.length || 0} cash-on-delivery payments:`);
          codPayments?.forEach(p => {
            console.log(`   • ${p.bill_number}: ${p.payment_method} - Paid: ${p.is_paid ? '✅' : '❌'}`);
          });
          
          const unpaidCOD = codPayments?.filter(p => !p.is_paid) || [];
          if (unpaidCOD.length > 0) {
            console.log(`\n⚠️  Found ${unpaidCOD.length} unpaid COD payments that should be auto-paid`);
            console.log('   These might have been created before the trigger was updated.');
            console.log('   Run processCashOnDeliveryPayments() in PaymentManager to fix them.\n');
          }
        }
      } else {
        console.log('❌ Cash-on-delivery logic NOT found in function');
        console.log('   You need to apply the PRODUCTION-READY-MIGRATION-59.sql migration!\n');
      }
    }
    
    console.log('📚 Summary:');
    console.log('   1. Apply PRODUCTION-READY-MIGRATION-59.sql in Supabase SQL Editor');
    console.log('   2. Reload PaymentManager to process any existing unpaid COD payments');
    console.log('   3. New COD payments will be auto-marked as paid by the trigger\n');
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

applyCODAutomationFix();
