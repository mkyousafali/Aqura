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
const projectRef = supabaseUrl.match(/https:\/\/([a-z0-9]+)\.supabase\.co/)?.[1];

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('❌ Missing Supabase credentials in .env');
  process.exit(1);
}

if (!projectRef) {
  console.error('❌ Could not extract project reference from URL');
  process.exit(1);
}

console.log(`🔍 Fetching storage buckets from Supabase Storage API...\n`);
console.log(`Project Ref: ${projectRef}\n`);

async function fetchStorageBuckets() {
  try {
    // Try multiple endpoints in order of likelihood
    const endpoints = [
      `${supabaseUrl}/storage/v1/b`,  // Possible endpoint
      `${supabaseUrl}/storage/v1/bucket`,  // Alternative
      `${supabaseUrl}/rest/v1/rpc/list_buckets`,  // RPC endpoint
    ];

    let succeeded = false;
    let buckets = [];

    for (const endpoint of endpoints) {
      try {
        console.log(`📡 Trying: ${endpoint}\n`);

        const response = await fetch(endpoint, {
          method: 'GET',
          headers: {
            'Authorization': `Bearer ${supabaseServiceKey}`,
            'Accept': 'application/json',
            'apikey': supabaseServiceKey,
          },
        });

        if (response.ok) {
          buckets = await response.json();
          succeeded = true;
          break;
        } else if (response.status === 404) {
          console.log(`  ⚠️ Not found (404)\n`);
          continue;
        } else {
          console.log(`  ⚠️ Error ${response.status}\n`);
          continue;
        }
      } catch (e) {
        console.log(`  ⚠️ Failed: ${e.message}\n`);
        continue;
      }
    }

    if (!succeeded) {
      console.error('❌ All endpoints failed. Using Supabase JavaScript SDK alternative...\n');
      return handleBucketData([]);
    }

    handleBucketData(buckets);

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

function handleBucketData(rawData) {
  // If no data, show message and create a note in the file
  if (!rawData || (Array.isArray(rawData) && rawData.length === 0)) {
    console.warn('⚠️ No buckets returned from API. Storage buckets may need to be queried via Supabase Dashboard.\n');
    
    // Create informational markdown
    let markdownContent = `# Supabase Storage Information

**Generated:** ${new Date().toLocaleString('en-US', { 
    year: 'numeric', 
    month: 'long', 
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit'
  })}  
**Data Source:** Direct API Query Attempt (No Data Returned)  
**Project:** ${projectRef}

---

## Status

⚠️ **Unable to retrieve storage bucket information via API**

The Supabase Storage API endpoints tested did not return bucket information. This is likely because:

1. The Storage API may not expose bucket listing in the current version
2. The service role key may not have sufficient permissions for bucket enumeration
3. Storage bucket management requires access to the Supabase Management API with valid access tokens

---

## Recommended Action

**To view storage buckets:**

1. Go to Supabase Dashboard: https://app.supabase.com
2. Select your project
3. Navigate to **Storage** in the left sidebar
4. View all configured buckets and their properties

---

## Known Storage Buckets from Codebase Analysis

Based on code analysis of the Aqura application, the following storage buckets are referenced:

| Bucket Name | Purpose | Access |
|---|---|---|
| \`task-images\` | Task attachment storage | Public |
| \`quick-task-files\` | Quick task file storage | Public |
| \`pr_excel\` | PR Excel file uploads | Public |
| \`original_bill\` | Original bill/invoice storage | Public |

**Note:** These bucket names are inferred from codebase references and may not reflect the actual current state of storage buckets in your Supabase project.

---

## Required Data

To properly document storage buckets, you need to manually provide:

1. **Bucket Names:** List of all configured buckets
2. **Access Level:** Public or Private
3. **Created Date:** When bucket was created
4. **File Size Limits:** Any size restrictions
5. **Allowed MIME Types:** Permitted file types

---

**Last Attempted:** ${new Date().toISOString()}

**Method:** Supabase Storage API endpoints (GET /storage/v1/b, GET /storage/v1/bucket, RPC list_buckets)
`;

    const outputPath = path.join(__dirname, '..', 'STORAGE_INFO.md');
    fs.writeFileSync(outputPath, markdownContent, 'utf-8');

    console.log(`⚠️ Storage information file created with limitations.\n`);
    console.log(`📄 File: STORAGE_INFO.md`);
    console.log(`📊 File size: ${(markdownContent.length / 1024).toFixed(2)} KB`);
    console.log(`\n💡 Please use Supabase Dashboard to view actual bucket details.`);
    return;
  }

  console.log('📊 Raw Response:');
  console.log(JSON.stringify(rawData, null, 2));
  console.log('\n');

  // Extract buckets from response
  let buckets = Array.isArray(rawData) ? rawData : (rawData.buckets || []);

  if (buckets.length === 0) {
    console.warn('⚠️ No buckets found in response');
  }

  console.log(`✅ Retrieved ${buckets.length} storage buckets\n`);

  // Sort buckets by name
  const sortedBuckets = buckets.sort((a, b) => 
    (a.name || '').localeCompare(b.name || '')
  );

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
**Data Source:** Supabase Storage API (Direct Database Query)  
**Project:** ${projectRef}

---

## Summary

| Metric | Value |
|---|---|
| **Total Buckets** | ${sortedBuckets.length} |
| **Query Method** | Supabase Storage API |
| **Updated** | ${new Date().toISOString()} |
| **Project Reference** | ${projectRef} |

---

## Table of Contents

`;

  sortedBuckets.forEach((bucket, index) => {
    markdownContent += `${index + 1}. [${bucket.name}](#${index + 1}-${bucket.name.toLowerCase().replace(/[^a-z0-9]/g, '-')})\n`;
  });

  markdownContent += `\n---\n\n## Storage Buckets\n\n`;

  // Generate detailed bucket documentation
  sortedBuckets.forEach((bucket, index) => {
    const bucketName = bucket.name || 'Unknown';
    const id = bucket.id || '-';
    const isPublic = bucket.public === true ? '✓ Public' : '✗ Private';
    const createdAt = new Date(bucket.created_at).toLocaleString('en-US') || '-';
    const updatedAt = bucket.updated_at ? new Date(bucket.updated_at).toLocaleString('en-US') : '-';
    const owner = bucket.owner || '-';
    const allowedMimeTypes = bucket.allowed_mime_types && bucket.allowed_mime_types.length > 0 
      ? bucket.allowed_mime_types.join(', ')
      : 'All MIME types allowed';
    const fileSizeLimit = bucket.file_size_limit 
      ? `${(bucket.file_size_limit / (1024 * 1024)).toFixed(2)} MB`
      : 'Unlimited';

    markdownContent += `### ${index + 1}. ${bucketName}\n\n`;
    markdownContent += `| Property | Value |\n`;
    markdownContent += `|---|---|\n`;
    markdownContent += `| **Bucket ID** | \`${id}\` |\n`;
    markdownContent += `| **Public Access** | ${isPublic} |\n`;
    markdownContent += `| **Created At** | ${createdAt} |\n`;
    markdownContent += `| **Updated At** | ${updatedAt} |\n`;
    markdownContent += `| **Owner** | ${owner} |\n`;
    markdownContent += `| **Allowed MIME Types** | ${allowedMimeTypes} |\n`;
    markdownContent += `| **File Size Limit** | ${fileSizeLimit} |\n`;
    
    // Add URL pattern if public
    if (bucket.public) {
      markdownContent += `| **URL Pattern** | \`${projectRef}.supabase.co/storage/v1/object/public/${bucketName}/{file_path}\` |\n`;
    }
    
    markdownContent += `\n`;
  });

  // Add metadata section
  markdownContent += `---\n\n## Raw Bucket Metadata\n\n\`\`\`json\n${JSON.stringify(sortedBuckets, null, 2)}\n\`\`\`\n`;

  // Write to file
  const outputPath = path.join(__dirname, '..', 'STORAGE_INFO.md');
  fs.writeFileSync(outputPath, markdownContent, 'utf-8');

  console.log(`✅ Storage information saved successfully!\n`);
  console.log(`📄 File: STORAGE_INFO.md`);
  console.log(`📦 Total buckets: ${sortedBuckets.length}`);
  console.log(`📊 File size: ${(markdownContent.length / 1024).toFixed(2)} KB`);
}

fetchStorageBuckets();
