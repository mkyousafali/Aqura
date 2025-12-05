import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Read .env file
const envPath = path.join(__dirname, '..', 'frontend', '.env');
const envContent = fs.readFileSync(envPath, 'utf-8');

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
const supabaseServiceKey = envVars.VITE_SUPABASE_SERVICE_KEY;

console.log('🔍 Fetching first 5 records from users table...\n');

// Fetch users data
const response = await fetch(`${supabaseUrl}/rest/v1/users?limit=5`, {
  method: 'GET',
  headers: {
    'Authorization': `Bearer ${supabaseServiceKey}`,
    'Content-Type': 'application/json',
    'apikey': supabaseServiceKey,
    'Prefer': 'count=exact'
  }
});

if (!response.ok) {
  console.error(`❌ Error: ${response.status} ${response.statusText}`);
  const error = await response.text();
  console.error(error);
  process.exit(1);
}

const data = await response.json();
console.log('✅ Users table data (first 5 records):\n');
console.log(JSON.stringify(data, null, 2));
console.log(`\n📊 Total records fetched: ${data.length}`);
