import { createClient } from '@supabase/supabase-js';
import fs from 'fs';

// Read .env.old for old Supabase credentials
const envOldPath = './frontend/.env.old';
if (!fs.existsSync(envOldPath)) {
  console.log('ERROR: .env.old file not found');
  process.exit(1);
}

const envOldContent = fs.readFileSync(envOldPath, 'utf-8');
const envVars = {};
envOldContent.split('\n').forEach(line => {
  const trimmed = line.trim();
  if (trimmed && !trimmed.startsWith('#')) {
    const match = trimmed.match(/^([^=]+)=(.*)$/);
    if (match) {
      envVars[match[1].trim()] = match[2].trim();
    }
  }
});

const oldUrl = envVars.VITE_SUPABASE_URL_OLD;
const oldKey = envVars.VITE_SUPABASE_SERVICE_KEY_OLD;

const oldSupabase = createClient(oldUrl, oldKey);

const bucketName = 'expense-scheduler-bills';

console.log('\nCHECKING BUCKET STRUCTURE: ' + bucketName);
console.log('='.repeat(70) + '\n');

// Function to recursively check folder structure
async function exploreFolder(path, depth = 0) {
  const indent = '  '.repeat(depth);
  
  const { data: items, error } = await oldSupabase
    .storage
    .from(bucketName)
    .list(path, { 
      limit: 1000,
      sortBy: { column: 'name', order: 'asc' }
    });

  if (error) {
    console.log(indent + 'ERROR: ' + error.message);
    return 0;
  }

  let fileCount = 0;

  if (!items || items.length === 0) {
    console.log(indent + '(empty)');
    return 0;
  }

  for (const item of items) {
    const isFolder = item.id === null; // Folders have id: null
    const icon = isFolder ? '[📁]' : '[📄]';
    const fullPath = path ? path + '/' + item.name : item.name;
    
    console.log(indent + icon + ' ' + item.name);

    if (isFolder) {
      // Recursively check folder contents
      const subFiles = await exploreFolder(fullPath, depth + 1);
      fileCount += subFiles;
    } else {
      fileCount += 1;
    }
  }

  return fileCount;
}

// Explore root
const totalFiles = await exploreFolder('');

console.log('\n' + '-'.repeat(70));
console.log('TOTAL FILES IN BUCKET: ' + totalFiles);
console.log('='.repeat(70) + '\n');

if (totalFiles > 4) {
  console.log('⚠️  WARNING: Bucket has folders with nested files!');
  console.log('   Standard migration may not work correctly.');
  console.log('   Need to handle folder paths properly.\n');
} else {
  console.log('✅ Bucket appears to have only files (no nested folders)\n');
}
