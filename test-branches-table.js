// Test script to check branches table structure
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkBranchesTable() {
    console.log('🔍 Checking branches table structure...\n');

    const { data: branchData, error: branchError } = await supabase
        .from('branches')
        .select('*')
        .limit(5);

    if (branchError) {
        console.error('❌ Error:', branchError.message);
        return;
    }

    console.log(`✅ Found ${branchData.length} branches\n`);

    if (branchData.length > 0) {
        console.log('📋 Table Structure:');
        const firstBranch = branchData[0];
        Object.keys(firstBranch).forEach((key, index) => {
            const value = firstBranch[key];
            console.log(`${index + 1}. ${key}: ${typeof value} = ${value}`);
        });

        console.log('\n📊 Sample Branches:');
        branchData.forEach((branch, index) => {
            console.log(`\nBranch ${index + 1}:`);
            console.log(`  ID: ${branch.id}`);
            console.log(`  Name EN: ${branch.name_en || 'N/A'}`);
            console.log(`  Name AR: ${branch.name_ar || 'N/A'}`);
            console.log(`  Status: ${branch.is_active || 'N/A'}`);
        });
    }
}

checkBranchesTable().then(() => {
    console.log('\n✨ Check complete!');
    process.exit(0);
}).catch(err => {
    console.error('💥 Fatal error:', err);
    process.exit(1);
});
