import { readFileSync } from 'fs';
import { createClient } from '@supabase/supabase-js';

// Load environment variables from frontend/.env
const envPath = './frontend/.env';
const envContent = readFileSync(envPath, 'utf-8');
const envVars = {};

envContent.split('\n').forEach(line => {
  const trimmed = line.trim();
  if (trimmed && !trimmed.startsWith('#')) {
    const match = trimmed.match(/^([^=]+)=(.*)$/);
    if (match) {
      envVars[match[1].trim()] = match[2].trim();
    }
  }
});

const supabaseUrl = envVars.VITE_SUPABASE_URL;
const supabaseServiceKey = envVars.VITE_SUPABASE_SERVICE_ROLE_KEY;

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkPurchaseManagerDependencies() {
  const receivingRecordId = '0c8e30dd-3e92-49fb-8d4a-d12c58d37094';
  const roleType = 'purchase_manager';
  
  console.log('🔍 Checking dependencies for purchase_manager task...\n');
  
  // Check the RPC function
  const { data: depStatus, error: rpcError } = await supabase.rpc('check_receiving_task_dependencies', {
    receiving_record_id_param: receivingRecordId,
    role_type_param: roleType
  });
  
  if (rpcError) {
    console.error('❌ RPC Error:', rpcError);
  } else {
    console.log('✅ Dependency check result:', JSON.stringify(depStatus, null, 2));
  }
  
  // Check receiving record directly
  console.log('\n🔍 Checking receiving record...\n');
  const { data: record, error: recordError } = await supabase
    .from('receiving_records')
    .select('*')
    .eq('id', receivingRecordId)
    .single();
  
  if (recordError) {
    console.error('❌ Record Error:', recordError);
  } else {
    console.log('📊 Receiving Record:');
    console.log('   erp_purchase_invoice_uploaded:', record.erp_purchase_invoice_uploaded);
    console.log('   erp_purchase_invoice_reference:', record.erp_purchase_invoice_reference);
    console.log('   pr_excel_file_uploaded:', record.pr_excel_file_uploaded);
    console.log('   pr_excel_file_url:', record.pr_excel_file_url);
    console.log('   original_bill_uploaded:', record.original_bill_uploaded);
    console.log('   original_bill_url:', record.original_bill_url);
  }
  
  // Check payment schedule directly
  console.log('\n🔍 Checking payment schedule verification...\n');
  const { data: schedule, error: scheduleError } = await supabase
    .from('vendor_payment_schedule')
    .select('pr_excel_verified, pr_excel_verified_by, pr_excel_verified_date')
    .eq('receiving_record_id', receivingRecordId);
  
  if (scheduleError) {
    console.error('❌ Schedule Error:', scheduleError);
  } else {
    console.log('📊 Payment Schedule:', JSON.stringify(schedule, null, 2));
  }
}

checkPurchaseManagerDependencies().catch(console.error);
