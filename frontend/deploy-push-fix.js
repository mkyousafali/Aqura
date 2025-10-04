// Deploy Push Notification Fixes
const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');

const supabaseUrl = process.env.PUBLIC_SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
    console.error('❌ Missing Supabase environment variables');
    process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function fixPushNotifications() {
    try {
        console.log('🔧 Fixing push notification system...');
        
        const sql = fs.readFileSync('57-fix-push-notifications.sql', 'utf8');
        
        // Split SQL into individual statements
        const statements = sql
            .split(';')
            .map(s => s.trim())
            .filter(s => s.length > 0 && !s.startsWith('--'));
        
        console.log(`📝 Executing ${statements.length} SQL statements...`);
        
        for (let i = 0; i < statements.length; i++) {
            const statement = statements[i];
            if (statement.trim()) {
                console.log(`⚡ Executing statement ${i + 1}/${statements.length}...`);
                
                try {
                    const { error } = await supabase.rpc('exec_sql', { 
                        sql_query: statement + ';' 
                    });
                    
                    if (error) {
                        console.log(`⚠️ Statement ${i + 1} warning:`, error.message);
                    } else {
                        console.log(`✅ Statement ${i + 1} completed`);
                    }
                } catch (err) {
                    console.log(`⚠️ Statement ${i + 1} error:`, err.message);
                }
            }
        }
        
        // Test the notification system
        console.log('🧪 Testing notification system...');
        
        // Check notification recipients table structure
        const { data: recipients, error: recipientsError } = await supabase
            .from('notification_recipients')
            .select('id, notification_id, user_id, delivery_status, is_read, created_at')
            .limit(3);
        
        if (recipientsError) {
            console.error('❌ Error checking notification recipients:', recipientsError);
        } else {
            console.log('✅ Notification recipients structure OK');
            console.log('📊 Sample recipients:', recipients);
        }
        
        // Check push subscriptions
        const { data: subscriptions, error: subsError } = await supabase
            .from('push_subscriptions')
            .select('id, user_id, device_id, is_active')
            .eq('is_active', true)
            .limit(3);
        
        if (subsError) {
            console.error('❌ Error checking push subscriptions:', subsError);
        } else {
            console.log('✅ Push subscriptions check OK');
            console.log('📊 Active subscriptions:', subscriptions?.length || 0);
        }
        
        // Check notification queue
        const { data: queue, error: queueError } = await supabase
            .from('notification_queue')
            .select('id, notification_id, user_id, status, created_at')
            .limit(5);
        
        if (queueError) {
            console.error('❌ Error checking notification queue:', queueError);
        } else {
            console.log('✅ Notification queue check OK');
            console.log('📊 Queue items:', queue?.length || 0);
        }
        
        console.log('🎉 Push notification system fix completed!');
        
    } catch (error) {
        console.error('❌ Fix failed:', error);
        process.exit(1);
    }
}

fixPushNotifications();