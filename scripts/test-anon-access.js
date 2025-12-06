// Test if anon key can access erp_daily_sales and branches
import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

dotenv.config({ path: join(__dirname, '../frontend/.env') });

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseAnonKey = process.env.VITE_SUPABASE_ANON_KEY;

console.log('🔍 Testing anon key access to tables...\n');

const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function testAnonAccess() {
  // Test erp_daily_sales
  console.log('📊 Testing erp_daily_sales table...');
  const { data: salesData, error: salesError } = await supabase
    .from('erp_daily_sales')
    .select('*')
    .limit(1);

  if (salesError) {
    console.log('❌ erp_daily_sales - BLOCKED');
    console.log('   Error:', salesError.message);
    console.log('   → Service role key REQUIRED\n');
  } else {
    console.log('✅ erp_daily_sales - ACCESSIBLE with anon key');
    console.log('   Returned', salesData?.length || 0, 'record(s)\n');
  }

  // Test branches
  console.log('🏢 Testing branches table...');
  const { data: branchData, error: branchError } = await supabase
    .from('branches')
    .select('id, location_en, location_ar')
    .limit(1);

  if (branchError) {
    console.log('❌ branches - BLOCKED');
    console.log('   Error:', branchError.message);
    console.log('   → Service role key REQUIRED\n');
  } else {
    console.log('✅ branches - ACCESSIBLE with anon key');
    console.log('   Returned', branchData?.length || 0, 'record(s)\n');
  }

  console.log('\n📋 Summary:');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  
  if (salesError && branchError) {
    console.log('❌ BOTH tables require service role key');
    console.log('   RLS is likely ENABLED with no anon policies');
    console.log('\n💡 Options:');
    console.log('   1. Keep using service role key (current)');
    console.log('   2. Create RLS policies for anon access');
  } else if (salesError || branchError) {
    console.log('⚠️ MIXED access - one accessible, one blocked');
    const blocked = salesError ? 'erp_daily_sales' : 'branches';
    console.log(`   ${blocked} needs RLS policy for anon access`);
  } else {
    console.log('✅ BOTH tables accessible with anon key!');
    console.log('   You can switch from service key to anon key');
  }
}

testAnonAccess().catch(console.error);
