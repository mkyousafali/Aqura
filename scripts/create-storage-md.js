#!/usr/bin/env node

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Read environment variables from frontend/.env
const envPath = path.join(__dirname, '..', 'frontend', '.env');
let envContent = '';

try {
  envContent = fs.readFileSync(envPath, 'utf-8');
} catch (err) {
  console.error('❌ Error reading .env file:', err.message);
  process.exit(1);
}

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

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('❌ Missing Supabase credentials in .env');
  process.exit(1);
}

console.log('🔍 Fetching Supabase storage information...\n');

// Use the storage API endpoint to list buckets
const storageApiUrl = `${supabaseUrl}/storage/v1/b`;

async function fetchStorageInfo() {
  try {
    const response = await fetch(storageApiUrl, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${supabaseServiceKey}`,
        'Accept': 'application/json',
        'apikey': supabaseServiceKey,
      },
    });

    if (!response.ok) {
      console.error(`❌ HTTP Error: ${response.status} ${response.statusText}`);
      const error = await response.text();
      console.error('Error details:', error);
      
      // If get_storage_info function exists, try that instead
      console.log('\n🔄 Trying alternative RPC endpoint...\n');
      
      const rpcUrl = `${supabaseUrl}/rest/v1/rpc/get_storage_info`;
      const rpcResponse = await fetch(rpcUrl, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${supabaseServiceKey}`,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'apikey': supabaseServiceKey,
        },
        body: JSON.stringify({}),
      });

      if (!rpcResponse.ok) {
        console.error('❌ RPC endpoint also failed');
        process.exit(1);
      }

      const rpcData = await rpcResponse.json();
      handleStorageData(rpcData, supabaseUrl);
      return;
    }

    const data = await response.json();
    handleStorageData(data, supabaseUrl);

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

fetchStorageInfo();

function handleStorageData(data, supabaseUrl) {
  // Extract storage info
  let storageArray = data.storage_buckets || data.buckets || (Array.isArray(data) ? data : []);
  
  if (typeof storageArray === 'string') {
    try {
      storageArray = JSON.parse(storageArray);
    } catch (e) {
      console.error('❌ Could not parse response');
      process.exit(1);
    }
  }

  if (!Array.isArray(storageArray)) {
    console.error('⚠️  No buckets found or unexpected response format');
    storageArray = [];
  }

  console.log(`✅ Retrieved storage information for ${storageArray.length} buckets\n`);

  // Sort buckets by name
  const sortedBuckets = storageArray.sort((a, b) => 
    (a.name || '').localeCompare(b.name || '')
  );

  // Calculate totals
  let totalSize = 0;
  let totalFiles = 0;

  // Generate markdown content
  let markdownContent = `# Supabase Storage Information

**Generated:** ${new Date().toLocaleString('en-US', { 
    year: 'numeric', 
    month: 'long', 
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit'
  })}  
**Total Buckets:** ${sortedBuckets.length}

---

## Table of Contents

`;

  if (sortedBuckets.length > 0) {
    // Add table of contents
    sortedBuckets.forEach((bucket, index) => {
      markdownContent += `${index + 1}. [${bucket.name}](#${bucket.name})\n`;
    });

    markdownContent += `\n---\n\n`;

    // Generate bucket documentation
    sortedBuckets.forEach(bucket => {
      const bucketName = bucket.name || 'Unknown';
      const isPublic = bucket.public ? '✓ Yes' : '✗ No';
      const id = bucket.id || '-';
      const createdAt = bucket.created_at || '-';
      const updatedAt = bucket.updated_at || '-';
      const owner = bucket.owner || '-';
      const fileCount = bucket.file_count || 0;
      const size = bucket.size || 0;

      totalSize += size;
      totalFiles += fileCount;

      markdownContent += `## ${bucketName}\n\n`;
      markdownContent += `| Property | Value |\n`;
      markdownContent += `|---|---|\n`;
      markdownContent += `| **ID** | \`${id}\` |\n`;
      markdownContent += `| **Public** | ${isPublic} |\n`;
      markdownContent += `| **Files** | ${fileCount} |\n`;
      markdownContent += `| **Size** | ${formatBytes(size)} |\n`;
      markdownContent += `| **Owner** | ${owner} |\n`;
      markdownContent += `| **Created** | ${createdAt} |\n`;
      markdownContent += `| **Updated** | ${updatedAt} |\n`;
      
      markdownContent += `\n`;
    });
  } else {
    markdownContent += `\n⚠️ No storage buckets found or unable to retrieve bucket details.\n\n`;
  }

  // Add summary
  const summaryContent = `---

## Summary

| Metric | Value |
|---|---|
| **Total Buckets** | ${sortedBuckets.length} |
| **Total Files** | ${totalFiles} |
| **Total Size** | ${formatBytes(totalSize)} |
${sortedBuckets.length > 0 ? `| **Average Bucket Size** | ${formatBytes(totalSize / sortedBuckets.length)} |\n` : ''}

`;

  markdownContent = summaryContent + markdownContent;

  // Write to file
  const outputPath = path.join(__dirname, '..', 'STORAGE_INFO.md');
  fs.writeFileSync(outputPath, markdownContent, 'utf-8');

  console.log(`✅ Markdown file created successfully!\n`);
  console.log(`📄 File: STORAGE_INFO.md`);
  console.log(`📦 Total buckets: ${sortedBuckets.length}`);
  console.log(`📁 Total files: ${totalFiles}`);
  console.log(`💾 Total size: ${formatBytes(totalSize)}`);
  console.log(`📊 File size: ${(markdownContent.length / 1024).toFixed(2)} KB`);
}

// Helper function to format bytes
function formatBytes(bytes) {
  if (bytes === 0) return '0 Bytes';

  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));

  return Math.round((bytes / Math.pow(k, i)) * 100) / 100 + ' ' + sizes[i];
}
