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
    console.log('🔍 Querying get_database_schema function...\n');

    // Call the function
    const { data, error } = await supabase.rpc('get_database_schema');

    if (error) {
      console.error('❌ Function error:', error);
      process.exit(1);
    }

    console.log('📊 Response type:', typeof data);
    console.log('📊 Is array?', Array.isArray(data));
    console.log('📊 Response length:', data?.length);
    console.log('📊 First item sample:', JSON.stringify(data?.[0], null, 2));

  } catch (err) {
    console.error('❌ Error:', err.message);
    process.exit(1);
  }
})();
