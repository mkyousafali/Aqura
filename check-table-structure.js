// Check the exact structure of push_subscriptions table
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

console.log('🔍 Checking push_subscriptions table structure...\n');

async function checkTableStructure() {
  try {
    // Try to query the table structure
    const { data, error } = await supabase
      .from('push_subscriptions')
      .select('*')
      .limit(0); // Just get structure, no data

    if (error) {
      console.log('❌ Error querying table:', error.message);
      
      // Try to get table info from system tables
      const { data: columns, error: columnError } = await supabase
        .rpc('get_column_info', { table_name: 'push_subscriptions' })
        .single();
      
      if (columnError) {
        console.log('❌ Could not get column info:', columnError.message);
        
        // Fallback: try to describe the table structure differently
        console.log('\n🔍 Attempting to get table structure via raw SQL...');
        
        const { data: rawColumns, error: rawError } = await supabase
          .from('information_schema.columns')
          .select('column_name, data_type, is_nullable')
          .eq('table_name', 'push_subscriptions')
          .eq('table_schema', 'public');
          
        if (rawError) {
          console.log('❌ Raw query failed:', rawError.message);
        } else {
          console.log('✅ Table structure found:');
          rawColumns?.forEach(col => {
            console.log(`   📋 ${col.column_name}: ${col.data_type} ${col.is_nullable === 'YES' ? '(nullable)' : '(required)'}`);
          });
        }
      } else {
        console.log('✅ Column info:', columns);
      }
    } else {
      console.log('✅ Table is accessible, but need to check columns...');
      
      // If we can access the table, try a simple insert to see what columns are expected
      console.log('\n🧪 Testing column structure by attempting test insert...');
      
      const testData = {
        user_id: 'test-user-id',
        device_id: 'test-device-id',
        push_subscription: { test: 'data' },
        device_type: 'desktop',
        browser_name: 'Chrome',
        user_agent: 'test-agent',
        is_active: true,
        last_seen: new Date().toISOString()
      };
      
      const { data: insertData, error: insertError } = await supabase
        .from('push_subscriptions')
        .insert(testData)
        .select();
        
      if (insertError) {
        console.log('❌ Insert test failed:', insertError.message);
        console.log('   📋 This tells us about the expected column structure');
        
        // Try with different column name possibilities
        const alternatives = [
          { subscription_data: testData.push_subscription },
          { subscription: testData.push_subscription },
          { endpoint: 'test-endpoint', p256dh: 'test-key', auth: 'test-auth' }
        ];
        
        for (const alt of alternatives) {
          console.log(`\n🧪 Testing alternative structure: ${Object.keys(alt).join(', ')}`);
          const altData = { ...testData, ...alt };
          delete altData.push_subscription;
          
          const { error: altError } = await supabase
            .from('push_subscriptions')
            .insert(altData)
            .select();
            
          if (altError) {
            console.log(`   ❌ Failed: ${altError.message}`);
          } else {
            console.log(`   ✅ Success! Correct structure found`);
            break;
          }
        }
      } else {
        console.log('✅ Insert successful! Column structure is correct');
        console.log('   📊 Inserted data:', insertData);
        
        // Clean up test data
        await supabase
          .from('push_subscriptions')
          .delete()
          .eq('user_id', 'test-user-id');
      }
    }
    
  } catch (error) {
    console.log('❌ Unexpected error:', error.message);
  }
}

checkTableStructure();