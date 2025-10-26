// Test script to verify requisitions setup
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function testRequisitionsSetup() {
    console.log('🔍 Testing Requisitions Setup...\n');

    // Check expense_requisitions table
    console.log('📋 Checking expense_requisitions table:');
    const { data: reqData, error: reqError } = await supabase
        .from('expense_requisitions')
        .select('*')
        .limit(5);

    if (reqError) {
        console.error('❌ Error:', reqError.message);
        console.log('⚠️  Table may not exist. Please apply migration:');
        console.log('   d:\\Aqura\\supabase\\migrations\\20250126000001_create_requisitions.sql\n');
    } else {
        console.log(`✅ Table exists! Found ${reqData.length} requisitions\n`);
    }

    // Check storage bucket
    console.log('📦 Checking requisition-images storage bucket:');
    const { data: bucketData, error: bucketError } = await supabase
        .storage
        .getBucket('requisition-images');

    if (bucketError) {
        console.error('❌ Error:', bucketError.message);
        console.log('⚠️  Bucket may not exist. Create it via Supabase Dashboard:');
        console.log('   1. Go to Storage');
        console.log('   2. Create bucket: requisition-images');
        console.log('   3. Make it public');
        console.log('   4. File size limit: 5MB\n');
    } else {
        console.log('✅ Storage bucket exists!');
        console.log('   Name:', bucketData.name);
        console.log('   Public:', bucketData.public);
        console.log('   File size limit:', bucketData.file_size_limit || 'unlimited', '\n');
    }

    // List files in bucket
    console.log('📄 Listing files in bucket:');
    const { data: files, error: listError } = await supabase
        .storage
        .from('requisition-images')
        .list();

    if (listError) {
        console.error('❌ Error listing files:', listError.message);
    } else {
        console.log(`✅ Found ${files?.length || 0} files in bucket\n`);
        if (files && files.length > 0) {
            console.log('First 5 files:');
            files.slice(0, 5).forEach(file => {
                console.log(`   - ${file.name} (${(file.metadata?.size / 1024).toFixed(2)} KB)`);
            });
        }
    }
}

testRequisitionsSetup().then(() => {
    console.log('\n✨ Test complete!');
    process.exit(0);
}).catch(err => {
    console.error('💥 Fatal error:', err);
    process.exit(1);
});
