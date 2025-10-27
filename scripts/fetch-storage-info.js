/**
 * Fetch Storage Information from Supabase
 * This script connects to Supabase using the service role key
 * and retrieves storage bucket information and connected tables
 */

import { createClient } from '@supabase/supabase-js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Supabase configuration
const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

// Create Supabase admin client
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

console.log('🔍 Fetching storage information from Supabase...\n');

async function fetchStorageInfo() {
  const info = {
    timestamp: new Date().toISOString(),
    supabase_url: SUPABASE_URL,
    storage_buckets: [],
    storage_objects: [],
    database_tables: [],
    table_relationships: [],
    statistics: {}
  };

  try {
    // 1. Fetch Storage Buckets
    console.log('📦 Fetching storage buckets...');
    const { data: buckets, error: bucketsError } = await supabase
      .storage
      .listBuckets();

    if (bucketsError) {
      console.error('❌ Error fetching buckets:', bucketsError);
    } else {
      info.storage_buckets = buckets;
      console.log(`✅ Found ${buckets.length} storage buckets`);
      buckets.forEach(bucket => {
        console.log(`   - ${bucket.name} (${bucket.public ? 'public' : 'private'})`);
      });
    }

    // 2. Fetch Storage Objects count for each bucket (without listing files)
    console.log('\n📁 Fetching storage objects count...');
    for (const bucket of buckets) {
      const { data: objects, error: objectsError } = await supabase
        .storage
        .from(bucket.name)
        .list('', {
          limit: 1,
          offset: 0
        });

      if (objectsError) {
        console.error(`❌ Error fetching objects from ${bucket.name}:`, objectsError);
        info.storage_objects.push({
          bucket: bucket.name,
          count: 0
        });
      } else {
        // Get count using storage metadata
        const { data: listData } = await supabase
          .storage
          .from(bucket.name)
          .list('', {
            limit: 1000,
            offset: 0
          });
        
        info.storage_objects.push({
          bucket: bucket.name,
          count: listData ? listData.length : 0
        });
        console.log(`   - ${bucket.name}: ${listData ? listData.length : 0} objects`);
      }
    }

    // 3. Fetch Database Tables
    console.log('\n📊 Fetching database tables...');
    const { data: tables, error: tablesError } = await supabase
      .from('information_schema.tables')
      .select('table_schema, table_name, table_type')
      .eq('table_schema', 'public');

    if (!tablesError && tables) {
      info.database_tables = tables;
      console.log(`✅ Found ${tables.length} tables`);
    }

    // Alternative: Fetch using RPC (if we have the function)
    const { data: tablesInfo, error: tablesInfoError } = await supabase
      .rpc('get_connected_tables_info');

    if (!tablesInfoError && tablesInfo) {
      info.database_tables = tablesInfo;
      console.log(`✅ Found ${tablesInfo.length} tables with detailed info`);
    }

    // 4. Fetch Table Relationships (Foreign Keys)
    console.log('\n🔗 Fetching table relationships...');
    const { data: relationships, error: relError } = await supabase
      .rpc('get_table_foreign_keys');

    if (!relError && relationships) {
      info.table_relationships = relationships;
      console.log(`✅ Found ${relationships.length} foreign key relationships`);
    }

    // 5. Fetch Database Statistics
    console.log('\n📈 Fetching database statistics...');
    const { data: stats, error: statsError } = await supabase
      .rpc('get_database_statistics');

    if (!statsError && stats && stats.length > 0) {
      info.statistics = stats[0];
      console.log('✅ Database Statistics:');
      console.log(`   - Total Tables: ${stats[0].total_tables}`);
      console.log(`   - Total Views: ${stats[0].total_views}`);
      console.log(`   - Total Functions: ${stats[0].total_functions}`);
      console.log(`   - Storage Buckets: ${stats[0].total_storage_buckets}`);
      console.log(`   - Storage Objects: ${stats[0].total_storage_objects}`);
      console.log(`   - Total Storage Size: ${stats[0].total_storage_size_mb} MB`);
      console.log(`   - Database Size: ${stats[0].database_size}`);
    }

    return info;

  } catch (error) {
    console.error('❌ Error fetching storage info:', error);
    throw error;
  }
}

async function saveToMigrationFile(info) {
  const migrationContent = `-- =====================================================
-- SUPABASE STORAGE AND DATABASE INFORMATION REFERENCE
-- =====================================================
-- This file contains a snapshot of storage buckets and database tables
-- Fetched on: ${info.timestamp}
-- Supabase URL: ${info.supabase_url}
-- 
-- NOTE: This is a reference file only. Do not run as migration.
-- Generated by: scripts/fetch-storage-info.js
-- =====================================================

-- =====================================================
-- STORAGE BUCKETS CONFIGURATION
-- =====================================================
-- Total Buckets: ${info.storage_buckets.length}

${info.storage_buckets.map(bucket => `
-- Bucket: ${bucket.name}
-- ID: ${bucket.id}
-- Public: ${bucket.public}
-- Created: ${bucket.created_at}
-- File Size Limit: ${bucket.file_size_limit || 'No limit'}
-- Allowed MIME Types: ${bucket.allowed_mime_types ? bucket.allowed_mime_types.join(', ') : 'All types'}
`).join('\n')}

-- =====================================================
-- STORAGE OBJECTS SUMMARY
-- =====================================================
-- Object counts per bucket

${info.storage_objects.map(obj => `-- Bucket: ${obj.bucket} - ${obj.count} objects`).join('\n')}

-- =====================================================
-- DATABASE TABLES
-- =====================================================
-- Total Tables: ${info.database_tables.length}

${info.database_tables.map(table => `
-- Table: ${table.table_name}
-- Schema: ${table.table_schema || 'public'}
-- Type: ${table.table_type || 'BASE TABLE'}
${table.row_count ? `-- Row Count: ${table.row_count}` : ''}
${table.total_size ? `-- Total Size: ${table.total_size}` : ''}
`).join('\n')}

-- =====================================================
-- TABLE RELATIONSHIPS (FOREIGN KEYS)
-- =====================================================
-- Total Foreign Keys: ${info.table_relationships.length}

${info.table_relationships.map(rel => `
-- ${rel.table_name}.${rel.column_name} -> ${rel.foreign_table_name}.${rel.foreign_column_name}
--   Constraint: ${rel.constraint_name}
`).join('\n')}

-- =====================================================
-- DATABASE STATISTICS
-- =====================================================

-- Total Tables: ${info.statistics.total_tables || 0}
-- Total Views: ${info.statistics.total_views || 0}
-- Total Functions: ${info.statistics.total_functions || 0}
-- Storage Buckets: ${info.statistics.total_storage_buckets || 0}
-- Storage Objects: ${info.statistics.total_storage_objects || 0}
-- Total Storage Size: ${info.statistics.total_storage_size_mb || 0} MB
-- Database Size: ${info.statistics.database_size || 'Unknown'}

-- =====================================================
-- END OF REFERENCE FILE
-- =====================================================
`;

  // Save to migrations directory
  const migrationPath = path.join(__dirname, '../supabase/migrations/049_storage_info_reference.sql');
  fs.writeFileSync(migrationPath, migrationContent);
  console.log(`\n✅ Storage information saved to: ${migrationPath}`);

  // Also save as JSON for programmatic access
  const jsonPath = path.join(__dirname, '../supabase/storage-info.json');
  fs.writeFileSync(jsonPath, JSON.stringify(info, null, 2));
  console.log(`✅ JSON data saved to: ${jsonPath}`);
}

// Main execution
(async () => {
  try {
    const info = await fetchStorageInfo();
    await saveToMigrationFile(info);
    console.log('\n✨ Done! Storage information fetched and saved successfully.');
  } catch (error) {
    console.error('\n❌ Failed to fetch storage information:', error);
    process.exit(1);
  }
})();
