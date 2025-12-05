import { createClient } from '@supabase/supabase-js';
import fs from 'fs';

// Read .env.old for old Supabase credentials
const envOldPath = './frontend/.env.old';
if (!fs.existsSync(envOldPath)) {
  console.log('ERROR: .env.old file not found');
  process.exit(1);
}

const envOldContent = fs.readFileSync(envOldPath, 'utf-8');
const envVars = {};
envOldContent.split('\n').forEach(line => {
  const trimmed = line.trim();
  if (trimmed && !trimmed.startsWith('#')) {
    const match = trimmed.match(/^([^=]+)=(.*)$/);
    if (match) {
      envVars[match[1].trim()] = match[2].trim();
    }
  }
});

const oldUrl = envVars.VITE_SUPABASE_URL_OLD;
const oldKey = envVars.VITE_SUPABASE_SERVICE_KEY_OLD;

if (!oldUrl || !oldKey) {
  console.log('ERROR: Old Supabase credentials missing in .env.old');
  process.exit(1);
}

console.log('CHECKING OLD SUPABASE STORAGE\n');
console.log('='.repeat(70));

const oldSupabase = createClient(oldUrl, oldKey);

// Get storage buckets from old Supabase
const { data: buckets, error: bucketsError } = await oldSupabase.storage.listBuckets();

if (bucketsError) {
  console.log('ERROR fetching buckets:', bucketsError.message);
  process.exit(1);
}

console.log('\nOLD SUPABASE STORAGE BUCKETS (' + buckets.length + ' total)\n');

let totalFiles = 0;
const bucketStats = [];

// Function to count files with pagination
async function countFilesInBucket(bucketName) {
  let count = 0;
  let offset = 0;
  const pageSize = 1000;
  let hasMore = true;

  while (hasMore) {
    const { data: files, error } = await oldSupabase
      .storage
      .from(bucketName)
      .list('', { 
        limit: pageSize,
        offset: offset,
        sortBy: { column: 'created_at', order: 'asc' }
      });
    
    if (error) {
      console.log('    ERROR in ' + bucketName + ':', error.message);
      return count;
    }

    if (!files || files.length === 0) {
      hasMore = false;
    } else {
      count += files.length;
      offset += pageSize;
      hasMore = files.length === pageSize;
    }
  }

  return count;
}

// Count files in each bucket
for (const bucket of buckets) {
  const fileCount = await countFilesInBucket(bucket.name);
  totalFiles += fileCount;
  bucketStats.push({ name: bucket.name, count: fileCount });
  
  const status = fileCount > 0 ? 'PENDING' : 'EMPTY';
  console.log('  ' + bucket.name.padEnd(40) + ' : ' + fileCount.toString().padStart(5) + ' files (' + status + ')');
}

console.log('\n' + '-'.repeat(70));
console.log('TOTAL FILES IN OLD STORAGE: ' + totalFiles.toString().padStart(6));
console.log('-'.repeat(70));

console.log('\nMIGRATION STATUS BY BUCKET\n');
bucketStats.forEach(stat => {
  const status = stat.count > 0 ? 'NEEDS MIGRATION' : 'EMPTY';
  console.log('  [' + (stat.count > 0 ? 'x' : ' ') + '] ' + stat.name.padEnd(40) + ' : ' + stat.count + ' files');
});

console.log('\n' + '='.repeat(70));
console.log('\nRECOMMENDATION:\n');
const bucketsNeedingMigration = bucketStats.filter(b => b.count > 0);
if (bucketsNeedingMigration.length > 0) {
  console.log('BUCKETS TO MIGRATE (' + bucketsNeedingMigration.length + '):');
  bucketsNeedingMigration.forEach(b => {
    console.log('  - ' + b.name + ' (' + b.count + ' files)');
  });
} else {
  console.log('No files to migrate in old storage');
}

console.log('\n' + '='.repeat(70));
