import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'fs';

// Load environment variables
const envPath = './frontend/.env';
const envContent = readFileSync(envPath, 'utf-8');
const envVars = {};
envContent.split('\n').forEach(line => {
  const trimmed = line.trim();
  if (trimmed && !trimmed.startsWith('#')) {
    const match = trimmed.match(/^([^=]+)=(.*)$/);
    if (match) envVars[match[1].trim()] = match[2].trim();
  }
});

const supabaseUrl = envVars.VITE_SUPABASE_URL || envVars.PUBLIC_SUPABASE_URL;
const supabaseKey = envVars.VITE_SUPABASE_SERVICE_ROLE_KEY || envVars.SUPABASE_SERVICE_ROLE_KEY;
const supabase = createClient(supabaseUrl, supabaseKey);

async function deleteDuplicates() {
  console.log('🗑️  DUPLICATE DELETION SCRIPT');
  console.log('============================\n');
  console.log('⚠️  This will delete duplicate records from hr_fingerprint_transactions');
  console.log('   Keeping only the OLDEST (first created) record for each duplicate group\n');

  // Fetch all records
  console.log('📥 Fetching all records...\n');
  
  let allRecords = [];
  let from = 0;
  const batchSize = 1000;
  let hasMore = true;

  while (hasMore) {
    const { data, error } = await supabase
      .from('hr_fingerprint_transactions')
      .select('employee_id, date, time, status, branch_id, id, created_at')
      .range(from, from + batchSize - 1)
      .order('created_at', { ascending: true }); // Oldest first

    if (error) {
      console.error('❌ Error:', error);
      return;
    }

    if (data.length === 0) {
      hasMore = false;
    } else {
      allRecords = allRecords.concat(data);
      console.log(`   Fetched batch ${Math.floor(from / batchSize) + 1}: ${data.length} records (total: ${allRecords.length})`);
      from += batchSize;
    }

    if (data.length < batchSize) {
      hasMore = false;
    }
  }

  console.log(`\n✅ Total records fetched: ${allRecords.length.toLocaleString()}\n`);

  // Find duplicates (keep oldest/first)
  console.log('🔍 Identifying duplicates...\n');
  const seen = new Map();
  const duplicatesToDelete = [];

  allRecords.forEach(record => {
    const key = `${record.employee_id}-${record.date}-${record.time}-${record.status}-${record.branch_id}`;
    
    if (seen.has(key)) {
      // This is a duplicate - mark for deletion
      duplicatesToDelete.push(record.id);
    } else {
      // This is the first (oldest) occurrence - keep it
      seen.set(key, record);
    }
  });

  console.log(`📊 Analysis:`);
  console.log(`   Total Records: ${allRecords.length.toLocaleString()}`);
  console.log(`   Unique Records: ${seen.size.toLocaleString()}`);
  console.log(`   Duplicates to Delete: ${duplicatesToDelete.length.toLocaleString()}`);

  if (duplicatesToDelete.length === 0) {
    console.log('\n✅ No duplicates found! Nothing to delete.');
    return;
  }

  console.log(`\n⚠️  WARNING: About to delete ${duplicatesToDelete.length.toLocaleString()} duplicate records!`);
  console.log('   This action cannot be undone.\n');

  // Delete in batches
  console.log('🗑️  Starting deletion...\n');
  
  const deleteBatchSize = 100;
  let deletedCount = 0;
  
  for (let i = 0; i < duplicatesToDelete.length; i += deleteBatchSize) {
    const batch = duplicatesToDelete.slice(i, i + deleteBatchSize);
    
    const { error } = await supabase
      .from('hr_fingerprint_transactions')
      .delete()
      .in('id', batch);

    if (error) {
      console.error(`❌ Batch ${Math.floor(i / deleteBatchSize) + 1} deletion failed:`, error);
    } else {
      deletedCount += batch.length;
      const progress = Math.round((deletedCount / duplicatesToDelete.length) * 100);
      console.log(`   Deleted ${deletedCount.toLocaleString()}/${duplicatesToDelete.length.toLocaleString()} (${progress}%)`);
    }
  }

  console.log(`\n✅ DELETION COMPLETE!`);
  console.log(`   Deleted: ${deletedCount.toLocaleString()} duplicate records`);
  console.log(`   Remaining: ${seen.size.toLocaleString()} unique records`);
  
  // Verify final count
  const { count: finalCount } = await supabase
    .from('hr_fingerprint_transactions')
    .select('id', { count: 'exact' })
    .limit(1);
  
  console.log(`\n📊 Final Verification:`);
  console.log(`   Database now has: ${finalCount?.toLocaleString()} records`);
  console.log(`   Expected: ${seen.size.toLocaleString()} records`);
  
  if (finalCount === seen.size) {
    console.log(`   ✅ Perfect match! All duplicates removed.`);
  } else {
    console.log(`   ⚠️  Count mismatch - please investigate`);
  }
}

// Run the script
console.log('\n⏳ Starting in 3 seconds... (Press Ctrl+C to cancel)\n');
setTimeout(() => {
  deleteDuplicates().catch(err => {
    console.error('Fatal error:', err);
    process.exit(1);
  });
}, 3000);
