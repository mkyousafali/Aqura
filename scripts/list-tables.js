#!/usr/bin/env node

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { createClient } from '@supabase/supabase-js';

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

// Create Supabase client
const supabase = createClient(supabaseUrl, supabaseServiceKey);

(async () => {
  try {
    console.log('🔍 Querying Supabase database schema...\n');

    // Use RPC to get table information
    const { data, error } = await supabase.rpc('get_database_schema');

    if (error) {
      console.error('❌ Error querying database:', error);
      
      // Try alternative method using information_schema
      console.log('\n📊 Trying alternative method...\n');
      
      const { data: tables, error: tablesError } = await supabase
        .from('information_schema.tables')
        .select('table_name')
        .eq('table_schema', 'public')
        .order('table_name');

      if (tablesError) {
        console.error('❌ Alternative method failed:', tablesError);
        process.exit(1);
      }

      if (tables) {
        console.log(`📊 Total Tables: ${tables.length}\n`);
        console.log('📋 Table List:\n');
        
        tables.forEach((table, index) => {
          console.log(`  ${index + 1}. ${table.table_name}`);
        });
      }
      return;
    }

    // If RPC worked
    if (data && Array.isArray(data)) {
      console.log(`📊 Total Tables: ${data.length}\n`);
      console.log('📋 Table List:\n');
      
      data.forEach((table, index) => {
        const name = table.table_name || table.name || table;
        console.log(`  ${index + 1}. ${name}`);
      });
    }

  } catch (err) {
    console.error('❌ Error:', err.message);
    process.exit(1);
  }
})();
