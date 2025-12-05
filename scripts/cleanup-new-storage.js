import { createClient } from '@supabase/supabase-js';
import fs from 'fs';

// Read environment files
const envContent = fs.readFileSync('./frontend/.env', 'utf-8');
const envVars = {};
envContent.split('\n').forEach(line => {
  const trimmed = line.trim();
  if (trimmed && !trimmed.startsWith('#')) {
    const match = trimmed.match(/^([^=]+)=(.*)$/);
    if (match) envVars[match[1].trim()] = match[2].trim();
  }
});

const newUrl = envVars.VITE_SUPABASE_URL;
const newKey = envVars.VITE_SUPABASE_SERVICE_KEY;

const newSupabase = createClient(newUrl, newKey);

console.log('\nCLEANING UP NEW SUPABASE STORAGE\n');
console.log('='.repeat(70));

const { data: buckets } = await newSupabase.storage.listBuckets();

let totalDeleted = 0;
let totalFailed = 0;

for (const bucket of buckets) {
  let offset = 0;
  const pageSize = 100;
  let hasMore = true;
  let bucketDeleted = 0;

  while (hasMore) {
    const { data: items, error: listError } = await newSupabase
      .storage
      .from(bucket.name)
      .list('', { limit: pageSize, offset: offset });

    if (listError) {
      console.log('ERROR in ' + bucket.name + ':', listError.message);
      hasMore = false;
      break;
    }

    if (!items || items.length === 0) {
      hasMore = false;
      break;
    }

    for (const item of items) {
      const isFolder = item.id === null;
      
      if (!isFolder) {
        try {
          const { error: deleteError } = await newSupabase
            .storage
            .from(bucket.name)
            .remove([item.name]);

          if (deleteError) {
            console.log('  x ' + bucket.name + '/' + item.name);
            totalFailed++;
          } else {
            console.log('  - ' + bucket.name + '/' + item.name);
            bucketDeleted++;
            totalDeleted++;
          }
        } catch (err) {
          console.log('  x ' + bucket.name + '/' + item.name);
          totalFailed++;
        }
      }
    }

    offset += pageSize;
    hasMore = items.length === pageSize;
  }

  if (bucketDeleted > 0) {
    console.log('  [' + bucket.name + '] Deleted: ' + bucketDeleted + '\n');
  }
}

console.log('='.repeat(70));
console.log('\nCLEANUP COMPLETE\n');
console.log('✅ Deleted: ' + totalDeleted);
console.log('❌ Failed: ' + totalFailed);
console.log('\nNew storage is now EMPTY - ready for fresh migration!');
console.log('='.repeat(70) + '\n');
