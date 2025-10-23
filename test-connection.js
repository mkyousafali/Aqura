// Simple Database Connection Test
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcyOTY5NjkzNCwiZXhwIjoyMDQ1MjcyOTM0fQ.d8lXMGXhWVNjV3dT_C4l4mQlbtGV3UBqG6FKyYGUu_o';

const supabase = createClient(supabaseUrl, supabaseKey);

async function testConnection() {
    try {
        console.log('🔌 Testing database connection...');
        
        // Test basic connection
        const { data, error } = await supabase
            .from('users')
            .select('count')
            .limit(1);
        
        if (error) {
            console.error('❌ Connection error:', error);
            return;
        }
        
        console.log('✅ Database connection successful');
        
        // Test other tables
        const tables = ['receiving_records', 'vendor_payment_schedule', 'tasks', 'notifications', 'payment_transactions'];
        
        for (const table of tables) {
            try {
                const { count, error } = await supabase
                    .from(table)
                    .select('*', { count: 'exact', head: true });
                
                if (error) {
                    console.log(`❌ ${table}: ${error.message}`);
                } else {
                    console.log(`✅ ${table}: ${count || 0} records`);
                }
            } catch (e) {
                console.log(`❌ ${table}: ${e.message}`);
            }
        }
        
    } catch (error) {
        console.error('💥 Test failed:', error);
    }
}

testConnection();