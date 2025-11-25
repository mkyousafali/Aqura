/**
 * Verify Flyer Template Table Structure
 * Run: node verify-flyer-template-table.js
 */

import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'fs';

// Load environment variables
const envContent = readFileSync('./frontend/.env', 'utf-8');
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

const supabase = createClient(
  envVars.VITE_SUPABASE_URL,
  envVars.VITE_SUPABASE_SERVICE_ROLE_KEY
);

async function verifyTable() {
  console.log('🔍 Checking flyer_templates table...\n');

  try {
    // Try to query the table
    const { data, error, count } = await supabase
      .from('flyer_templates')
      .select('*', { count: 'exact', head: false })
      .limit(1);

    if (error) {
      if (error.message.includes('does not exist')) {
        console.log('❌ Table "flyer_templates" does NOT exist\n');
        console.log('📋 You need to apply the migration:');
        console.log('   1. Open Supabase Dashboard > SQL Editor');
        console.log('   2. Copy contents from: supabase/migrations/20251125_create_flyer_template_system.sql');
        console.log('   3. Run the SQL script\n');
        console.log('   OR\n');
        console.log('   Run: node apply-flyer-template-migration.js\n');
        return false;
      } else {
        console.error('❌ Error checking table:', error.message);
        return false;
      }
    }

    console.log('✅ Table "flyer_templates" EXISTS!\n');
    console.log(`📊 Current records: ${count || 0}\n`);

    if (data && data.length > 0) {
      console.log('📋 Sample record structure:');
      console.log('   Columns:', Object.keys(data[0]).join(', '));
      console.log('\n   Sample data:');
      console.log('   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      console.log('   ID:', data[0].id);
      console.log('   Name:', data[0].name);
      console.log('   First Page URL:', data[0].first_page_image_url ? 'Set' : 'Not set');
      console.log('   Sub Pages:', data[0].sub_page_image_urls?.length || 0);
      console.log('   Is Active:', data[0].is_active);
      console.log('   Is Default:', data[0].is_default);
      console.log('   Created:', data[0].created_at);
      console.log('   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    } else {
      console.log('📝 Table is empty (no templates yet)\n');
    }

    // Check storage bucket
    console.log('🗄️  Checking storage bucket...');
    const { data: buckets } = await supabase.storage.listBuckets();
    const flyerBucket = buckets?.find(b => b.id === 'flyer-templates');
    
    if (flyerBucket) {
      console.log('✅ Storage bucket "flyer-templates" EXISTS!\n');
      
      // List files in bucket
      const { data: files } = await supabase.storage
        .from('flyer-templates')
        .list();
      
      console.log(`📁 Files in bucket: ${files?.length || 0}\n`);
    } else {
      console.log('❌ Storage bucket "flyer-templates" does NOT exist\n');
      console.log('📋 Create it manually:');
      console.log('   1. Go to Supabase Dashboard > Storage');
      console.log('   2. Click "New bucket"');
      console.log('   3. Name: flyer-templates');
      console.log('   4. Make it public\n');
    }

    console.log('✅ Verification complete!\n');
    console.log('🎯 Ready to use Flyer Template Designer');
    return true;

  } catch (error) {
    console.error('💥 Error:', error.message);
    return false;
  }
}

verifyTable();
