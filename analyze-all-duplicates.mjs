import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'fs';

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

async function fetchAllRecords() {
  console.log('📥 Fetching ALL records from hr_fingerprint_transactions...\n');
  
  let allRecords = [];
  let from = 0;
  const batchSize = 1000;
  let hasMore = true;

  while (hasMore) {
    const { data, error } = await supabase
      .from('hr_fingerprint_transactions')
      .select('employee_id, date, time, status, branch_id, id, created_at')
      .range(from, from + batchSize - 1)
      .order('created_at', { ascending: false });

    if (error) {
      console.error('Error:', error);
      break;
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

  // Find duplicates
  console.log('🔍 Analyzing duplicates...\n');
  const seen = new Map();
  const duplicateGroups = [];

  allRecords.forEach(record => {
    const key = `${record.employee_id}-${record.date}-${record.time}-${record.status}-${record.branch_id}`;
    if (seen.has(key)) {
      duplicateGroups.push({
        key,
        original: seen.get(key),
        duplicate: record
      });
    } else {
      seen.set(key, record);
    }
  });

  console.log(`⚠️ TOTAL DUPLICATES FOUND: ${duplicateGroups.length.toLocaleString()}\n`);
  console.log(`📊 Breakdown:`);
  console.log(`   Total Records: ${allRecords.length.toLocaleString()}`);
  console.log(`   Unique Records: ${seen.size.toLocaleString()}`);
  console.log(`   Duplicate Records: ${duplicateGroups.length.toLocaleString()}`);
  console.log(`   Duplicate Percentage: ${((duplicateGroups.length / allRecords.length) * 100).toFixed(2)}%`);

  // Calculate: If we had 2,769 from historical sync + ongoing syncs creating duplicates
  console.log(`\n💡 EXPECTED vs ACTUAL:`);
  console.log(`   Expected (from ZKBioTime Oct 22-Nov 28): ~2,769 records`);
  console.log(`   Current in Supabase: ${allRecords.length.toLocaleString()} records`);
  console.log(`   Excess records (duplicates): ${(allRecords.length - 2769).toLocaleString()} records`);
  console.log(`   After cleanup, should have: ~${seen.size.toLocaleString()} unique records`);
}

fetchAllRecords();
