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

console.log('🔍 Fetching database schema from Supabase...\n');

// Use fetch with service role key to query tables
const apiUrl = `${supabaseUrl}/rest/v1/rpc/get_database_schema`;

try {
  const response = await fetch(apiUrl, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${supabaseServiceKey}`,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'apikey': supabaseServiceKey,
    },
    body: JSON.stringify({}),
  });

  if (!response.ok) {
    console.error(`❌ HTTP Error: ${response.status} ${response.statusText}`);
    const error = await response.text();
    console.error('Error details:', error);
    process.exit(1);
  }

  const data = await response.json();
  
  console.log('📊 Response type:', typeof data);
  console.log('📊 Is array?', Array.isArray(data));
  
  if (typeof data === 'object' && data !== null) {
    console.log('📊 Keys:', Object.keys(data).slice(0, 10));
    console.log('📊 Sample value:', JSON.stringify(Object.values(data)?.[0], null, 2));
  }

  // If it's a single object with table data
  if (data && typeof data === 'object' && !Array.isArray(data)) {
    console.log('\n✅ Received schema data as object\n');
    
    // Group by table
    const tablesByName = {};
    
    Object.entries(data).forEach(([key, value]) => {
      // Try to parse if it's structured
      if (typeof value === 'string') {
        try {
          const parsed = JSON.parse(value);
          if (parsed.table_name) {
            const tableName = parsed.table_name;
            if (!tablesByName[tableName]) {
              tablesByName[tableName] = [];
            }
            tablesByName[tableName].push({
              name: parsed.column_name,
              type: parsed.data_type,
              nullable: parsed.is_nullable
            });
          }
        } catch (e) {
          // Not JSON, skip
        }
      }
    });

    const tables = Object.keys(tablesByName).sort();
    console.log(`📊 Found ${tables.length} tables`);
    console.log('📋 Tables:', tables.slice(0, 10).join(', '));
  }

} catch (error) {
  console.error('❌ Error:', error.message);
  process.exit(1);
}
