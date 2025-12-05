import { createClient } from '@supabase/supabase-js';
import fs from 'fs';
import path from 'path';

// Read environment files
const envPath = path.join(process.cwd(), 'frontend', '.env');
const envOldPath = path.join(process.cwd(), 'frontend', '.env.old');

const envContent = fs.readFileSync(envPath, 'utf-8');
const envOldContent = fs.readFileSync(envOldPath, 'utf-8');

const envVars = {};
const envOldVars = {};

// Parse .env
envContent.split('\n').forEach(line => {
  const trimmed = line.trim();
  if (trimmed && !trimmed.startsWith('#')) {
    const match = trimmed.match(/^([^=]+)=(.*)$/);
    if (match) envVars[match[1].trim()] = match[2].trim();
  }
});

// Parse .env.old
envOldContent.split('\n').forEach(line => {
  const trimmed = line.trim();
  if (trimmed && !trimmed.startsWith('#')) {
    const match = trimmed.match(/^([^=]+)=(.*)$/);
    if (match) envOldVars[match[1].trim()] = match[2].trim();
  }
});

const oldUrl = envOldVars.VITE_SUPABASE_URL_OLD;
const oldKey = envOldVars.VITE_SUPABASE_SERVICE_KEY_OLD;
const newUrl = envVars.VITE_SUPABASE_URL;
const newKey = envVars.VITE_SUPABASE_SERVICE_KEY;

const oldSupabase = createClient(oldUrl, oldKey);
const newSupabase = createClient(newUrl, newKey);

// List of buckets to migrate (in order)
const bucketsToMigrate = [
  'clearance-certificates',  // 1,845 files
  'original-bills',          // 1,732 files
  'pr-excel-files',          // 1,712 files
  'completion-photos',       // 1,295 files
  'quick-task-files',        // 59 files
  'expense-scheduler-bills',  // 349 files (nested)
  'notification-images',     // Unknown
  'task-images',             // Unknown
  'warning-documents',       // Unknown
  'shelf-paper-templates',   // Unknown
  'customer-app-media',      // Unknown
  'category-images',         // Unknown
  'product-images'           // Unknown
];

let totalMigrated = 0;
let totalFailed = 0;

/**
 * Recursively list all files in a bucket, preserving folder structure
 * Uses pagination to handle buckets with more than 1000 items
 */
async function listAllFiles(client, bucket, path = '', allFiles = []) {
  let offset = 0;
  const pageSize = 1000;
  let hasMore = true;

  while (hasMore) {
    const { data: items, error } = await client.storage
      .from(bucket)
      .list(path, { limit: pageSize, offset: offset });

    if (error) {
      console.error('  ❌ Error listing files in ' + path + ':', error.message);
      break;
    }

    if (!items || items.length === 0) {
      hasMore = false;
      break;
    }

    for (const item of items) {
      if (item.id === null) {
        // It's a folder - recurse into it
        const folderPath = path ? path + '/' + item.name : item.name;
        await listAllFiles(client, bucket, folderPath, allFiles);
      } else {
        // It's a file
        const filePath = path ? path + '/' + item.name : item.name;
        allFiles.push(filePath);
      }
    }

    offset += pageSize;
    hasMore = items.length === pageSize;
  }

  return allFiles;
}

/**
 * Migrate a single bucket
 */
async function migrateBucket(bucketName) {
  console.log('\n' + '='.repeat(70));
  console.log('🔄 Migrating bucket: ' + bucketName);
  console.log('='.repeat(70));

  try {
    // Get all files recursively
    const files = await listAllFiles(oldSupabase, bucketName);
    
    if (files.length === 0) {
      console.log('⚠️  No files found in bucket');
      return { migrated: 0, failed: 0, total: 0 };
    }

    console.log('📊 Total files found: ' + files.length);
    console.log('Starting migration...\n');

    let migrated = 0;
    let failed = 0;

    for (let i = 0; i < files.length; i++) {
      const filePath = files[i];
      
      try {
        // Download from old storage
        const { data, error: downloadError } = await oldSupabase.storage
          .from(bucketName)
          .download(filePath);

        if (downloadError) {
          console.log('  ❌ [' + (i + 1) + '/' + files.length + '] Download failed: ' + filePath);
          failed++;
          continue;
        }

        // Upload to new storage with same path and folder structure
        const { error: uploadError } = await newSupabase.storage
          .from(bucketName)
          .upload(filePath, data, { upsert: true });

        if (uploadError) {
          console.log('  ❌ [' + (i + 1) + '/' + files.length + '] Upload failed: ' + filePath);
          failed++;
        } else {
          migrated++;
          // Show progress every 20 files
          if (migrated % 20 === 0 || i === files.length - 1) {
            console.log('  ✅ Migrated ' + migrated + '/' + files.length + ' files...');
          }
        }
      } catch (e) {
        console.log('  ❌ Error with ' + filePath + ': ' + e.message);
        failed++;
      }
    }

    console.log('\n✅ Bucket migration complete!');
    console.log('   Migrated: ' + migrated + ' files');
    console.log('   Failed: ' + failed + ' files');
    console.log('   Total: ' + files.length + ' files');

    return { migrated, failed, total: files.length };
  } catch (e) {
    console.log('❌ Error migrating bucket: ' + e.message);
    return { migrated: 0, failed: 0, total: 0 };
  }
}

/**
 * Main migration process
 */
async function runMigration() {
  console.log('\n' + '🚀 STARTING STORAGE MIGRATION 🚀');
  console.log('From: ' + oldUrl);
  console.log('To: ' + newUrl);
  console.log('Buckets: ' + bucketsToMigrate.length + '\n');

  const results = {};

  for (const bucketName of bucketsToMigrate) {
    const result = await migrateBucket(bucketName);
    results[bucketName] = result;
    totalMigrated += result.migrated;
    totalFailed += result.failed;
  }

  // Print final summary
  console.log('\n' + '='.repeat(70));
  console.log('📊 MIGRATION SUMMARY');
  console.log('='.repeat(70));

  for (const bucketName of bucketsToMigrate) {
    const result = results[bucketName];
    const status = result.failed === 0 ? '✅' : '⚠️ ';
    console.log(status + ' ' + bucketName.padEnd(30) + ': ' + result.migrated + '/' + result.total + ' files');
  }

  console.log('='.repeat(70));
  console.log('🎯 TOTAL RESULTS:');
  console.log('   ✅ Migrated: ' + totalMigrated + ' files');
  console.log('   ❌ Failed: ' + totalFailed + ' files');
  console.log('   📊 Total: ' + (totalMigrated + totalFailed) + ' files');
  console.log('='.repeat(70) + '\n');
}

// Run migration
runMigration().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
