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

async function checkDuplicates() {
  console.log('🔍 Checking for duplicate entries in hr_fingerprint_transactions...\n');

  // Check total records
  const { data, count: totalCount, error } = await supabase
    .from('hr_fingerprint_transactions')
    .select('id', { count: 'exact' })
    .limit(1);
  
  if (error) console.error('Error:', error);
  console.log(`📊 Total records: ${totalCount?.toLocaleString()}`);

  // Manual duplicate check - fetch all records and find duplicates
  console.log('\n🔍 Scanning for duplicates (this may take a moment)...');
  
  const { data: allRecords, error: fetchError } = await supabase
    .from('hr_fingerprint_transactions')
    .select('employee_id, date, time, status, branch_id, id, created_at')
    .order('created_at', { ascending: false });

  if (fetchError) {
    console.error('Error fetching records:', fetchError);
    return;
  }

  console.log(`   Fetched ${allRecords.length.toLocaleString()} records\n`);

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

  console.log(`⚠️ Found ${duplicateGroups.length.toLocaleString()} duplicate entries!\n`);

  if (duplicateGroups.length > 0) {
    console.log('📋 Sample duplicates (first 10):');
    duplicateGroups.slice(0, 10).forEach((dup, i) => {
      console.log(`\n${i + 1}. Duplicate Group:`);
      console.log(`   Employee: ${dup.duplicate.employee_id}`);
      console.log(`   Date: ${dup.duplicate.date}`);
      console.log(`   Time: ${dup.duplicate.time}`);
      console.log(`   Status: ${dup.duplicate.status}`);
      console.log(`   Branch: ${dup.duplicate.branch_id}`);
      console.log(`   Original ID: ${dup.original.id} (created: ${dup.original.created_at})`);
      console.log(`   Duplicate ID: ${dup.duplicate.id} (created: ${dup.duplicate.created_at})`);
    });

    // Count duplicates by employee
    const employeeDups = {};
    duplicateGroups.forEach(dup => {
      const empId = dup.duplicate.employee_id;
      employeeDups[empId] = (employeeDups[empId] || 0) + 1;
    });

    console.log(`\n\n👥 Duplicates by Employee (top 10):`);
    Object.entries(employeeDups)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 10)
      .forEach(([empId, count]) => {
        console.log(`   Employee ${empId}: ${count} duplicates`);
      });

    console.log(`\n\n💡 RECOMMENDATION:`);
    console.log(`   1. Delete ${duplicateGroups.length.toLocaleString()} duplicate records`);
    console.log(`   2. Add UNIQUE constraint on (employee_id, date, time, status, branch_id)`);
    console.log(`   3. Fix sync logic to check for existing records before insert`);
  } else {
    console.log('✅ No duplicates found!');
  }

  console.log('\n✅ Check complete!');
}

checkDuplicates();
