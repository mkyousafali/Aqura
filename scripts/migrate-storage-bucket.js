import { createClient } from '@supabase/supabase-js';
import fs from 'fs';

// Read environment files
const envContent = fs.readFileSync('./frontend/.env', 'utf-8');
const envOldContent = fs.readFileSync('./frontend/.env.old', 'utf-8');

const envVars = {};
const envOldVars = {};

envContent.split('\n').forEach(line => {
  const trimmed = line.trim();
  if (trimmed && !trimmed.startsWith('#')) {
    const match = trimmed.match(/^([^=]+)=(.*)$/);
    if (match) envVars[match[1].trim()] = match[2].trim();
  }
});

envOldContent.split('\n').forEach(line => {
  const trimmed = line.trim();
  if (trimmed && !trimmed.startsWith('#')) {
    const match = trimmed.match(/^([^=]+)=(.*)$/);
    if (match) envOldVars[match[1].trim()] = match[2].trim();
  }
});

const newUrl = envVars.VITE_SUPABASE_URL;
const newKey = envVars.VITE_SUPABASE_SERVICE_KEY;
const oldUrl = envOldVars.VITE_SUPABASE_URL_OLD;
const oldKey = envOldVars.VITE_SUPABASE_SERVICE_KEY_OLD;

if (!newUrl || !newKey || !oldUrl || !oldKey) {
  console.log('ERROR: Missing Supabase credentials');
  process.exit(1);
}

const oldSupabase = createClient(oldUrl, oldKey);
const newSupabase = createClient(newUrl, newKey);

const bucketName = 'flyer-templates';

console.log('\n' + '='.repeat(70));
console.log('MIGRATING STORAGE BUCKET: ' + bucketName);
console.log('='.repeat(70) + '\n');

// Function to recursively migrate files and folders
async function migrateFolder(bucket, path = '') {
  let offset = 0;
  const pageSize = 100;
  let totalMigrated = 0;
  let failedCount = 0;
  let hasMore = true;

  while (hasMore) {
    // Get items from old storage with pagination
    const { data: items, error: listError } = await oldSupabase
      .storage
      .from(bucket)
      .list(path, { 
        limit: pageSize,
        offset: offset,
        sortBy: { column: 'name', order: 'asc' }
      });

    if (listError) {
      console.log('ERROR listing ' + (path || 'root') + ':', listError.message);
      return { migrated: totalMigrated, failed: failedCount };
    }

    if (!items || items.length === 0) {
      hasMore = false;
      break;
    }

    // Process each item
    for (const item of items) {
      const isFolder = item.id === null;
      const fullPath = path ? path + '/' + item.name : item.name;

      if (isFolder) {
        // Recursively handle folders
        const subResult = await migrateFolder(bucket, fullPath);
        totalMigrated += subResult.migrated;
        failedCount += subResult.failed;
      } else {
        // Handle files
        try {
          // Download from old storage
          const { data, error: downloadError } = await oldSupabase
            .storage
            .from(bucket)
            .download(fullPath);

          if (downloadError) {
            console.log('  ❌ ' + fullPath + ' (download failed)');
            failedCount++;
            continue;
          }

          // Upload to new storage with same path
          const { error: uploadError } = await newSupabase
            .storage
            .from(bucket)
            .upload(fullPath, data, { upsert: true });

          if (uploadError) {
            console.log('  ❌ ' + fullPath + ' (upload failed)');
            failedCount++;
          } else {
            console.log('  ✅ ' + fullPath);
            totalMigrated++;
          }
        } catch (err) {
          console.log('  ❌ ' + fullPath + ' (error: ' + err.message + ')');
          failedCount++;
        }
      }
    }

    offset += pageSize;
    hasMore = items.length === pageSize;
  }

  return { migrated: totalMigrated, failed: failedCount };
}

// Function to migrate bucket
async function migrateBucket(bucket) {
  return await migrateFolder(bucket, '');
}

// Run migration
const result = await migrateBucket(bucketName);

console.log('\n' + '-'.repeat(70));
console.log('MIGRATION COMPLETE FOR: ' + bucketName);
console.log('-'.repeat(70));
console.log('✅ Successfully migrated: ' + result.migrated);
console.log('❌ Failed: ' + result.failed);
console.log('📊 Total: ' + (result.migrated + result.failed));
console.log('=' + '='.repeat(69) + '\n');
