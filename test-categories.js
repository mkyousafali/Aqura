// Test script to check expense categories tables
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkTables() {
    console.log('🔍 Checking expense category tables...\n');

    // Check parent categories
    console.log('📋 Checking expense_parent_categories table:');
    const { data: parentData, error: parentError } = await supabase
        .from('expense_parent_categories')
        .select('*');

    if (parentError) {
        console.error('❌ Error:', parentError.message);
        console.error('Details:', parentError);
    } else {
        console.log(`✅ Found ${parentData.length} parent categories`);
        if (parentData.length > 0) {
            console.log('First category:', parentData[0]);
        }
    }

    console.log('\n📋 Checking expense_sub_categories table:');
    const { data: subData, error: subError } = await supabase
        .from('expense_sub_categories')
        .select('*');

    if (subError) {
        console.error('❌ Error:', subError.message);
        console.error('Details:', subError);
    } else {
        console.log(`✅ Found ${subData.length} sub categories`);
        if (subData.length > 0) {
            console.log('First sub category:', subData[0]);
        }
    }

    // Check with JOIN
    console.log('\n📋 Checking sub categories with parent JOIN:');
    const { data: joinData, error: joinError } = await supabase
        .from('expense_sub_categories')
        .select(`
            *,
            expense_parent_categories (
                id,
                name_en,
                name_ar
            )
        `)
        .limit(5);

    if (joinError) {
        console.error('❌ Error:', joinError.message);
        console.error('Details:', joinError);
    } else {
        console.log(`✅ JOIN query successful, showing first 5:`);
        console.log(JSON.stringify(joinData, null, 2));
    }

    // Check RLS policies
    console.log('\n🔒 Checking RLS policies:');
    const { data: policyData, error: policyError } = await supabase
        .rpc('exec_sql', {
            sql: `
                SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
                FROM pg_policies 
                WHERE tablename IN ('expense_parent_categories', 'expense_sub_categories');
            `
        });

    if (policyError) {
        console.log('⚠️  Could not check policies (this is normal)');
    } else {
        console.log('Policies:', policyData);
    }
}

checkTables().then(() => {
    console.log('\n✨ Check complete!');
    process.exit(0);
}).catch(err => {
    console.error('💥 Fatal error:', err);
    process.exit(1);
});
