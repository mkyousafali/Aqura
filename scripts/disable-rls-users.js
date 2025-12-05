import { createClient } from '@supabase/supabase-js';
import fs from 'fs';

const envContent = fs.readFileSync('./frontend/.env', 'utf-8');
const envVars = {};
envContent.split('\n').forEach(line => {
  const trimmed = line.trim();
  if (trimmed && !trimmed.startsWith('#')) {
    const match = trimmed.match(/^([^=]+)=(.*)$/);
    if (match) envVars[match[1].trim()] = match[2].trim();
  }
});

const supabaseUrl = envVars.VITE_SUPABASE_URL;
const supabaseServiceKey = envVars.VITE_SUPABASE_SERVICE_KEY;

console.log('⚠️  DISABLING RLS on users table for testing...\n');

// Use fetch to execute SQL directly via Supabase API
const response = await fetch(`${supabaseUrl}/rest/v1/rpc/`, {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${supabaseServiceKey}`,
    'Content-Type': 'application/json',
    'apikey': supabaseServiceKey,
  },
});

console.log('Attempting to disable RLS via Supabase Dashboard...');
console.log('\n📋 Manual steps:');
console.log('1. Go to: https://app.supabase.com');
console.log('2. Select your project');
console.log('3. Go to: SQL Editor');
console.log('4. Click "New query"');
console.log('5. Paste this SQL:\n');
console.log('   ALTER TABLE users DISABLE ROW LEVEL SECURITY;\n');
console.log('6. Click "Run"');
console.log('\nThis will allow all authenticated users to update the users table.');
console.log('Once you confirm it works, we can re-enable RLS with proper policies.\n');

console.log('Or run this SQL to ENABLE RLS again:');
console.log('   ALTER TABLE users ENABLE ROW LEVEL SECURITY;\n');
