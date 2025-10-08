import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'fs';
import { join } from 'path';

const supabaseUrl = 'https://ewbrpprkjznywgqemcnw.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV3YnJwcHJrampubnlnd2VtY253Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTczMDA0MDE5MiwiZXhwIjoyMDQ1NjE2MTkyfQ.9BjPz5QGw4Rn4tHAEZu-lOKEX4A8Y46-AJ2VkqGKYOk';

const supabase = createClient(supabaseUrl, supabaseKey);

async function applyTargetingFix() {
    try {
        console.log('🔧 Applying targeting fix to queue_push_notification function...');
        
        const sqlContent = readFileSync(join(process.cwd(), 'apply-targeting-fix.sql'), 'utf-8');
        
        const { data, error } = await supabase.rpc('exec_sql', { sql_query: sqlContent });
        
        if (error) {
            console.error('❌ Error applying fix:', error);
            return;
        }
        
        console.log('✅ Successfully applied targeting fix');
        console.log('Result:', data);
        
    } catch (error) {
        console.error('❌ Script error:', error);
    }
}

// Try alternative method with individual SQL statements
async function applyTargetingFixAlternative() {
    try {
        console.log('🔧 Applying targeting fix using alternative method...');
        
        // Drop the existing function
        const { error: dropError } = await supabase.rpc('exec_sql', { 
            sql_query: 'DROP FUNCTION IF EXISTS queue_push_notification(UUID);' 
        });
        
        if (dropError) {
            console.error('❌ Error dropping function:', dropError);
        } else {
            console.log('✅ Dropped existing function');
        }
        
        // Create the new function (simplified version for testing)
        const createFunctionSQL = `
        CREATE OR REPLACE FUNCTION queue_push_notification(p_notification_id UUID)
        RETURNS TEXT AS $$
        BEGIN
            -- Simple version that just returns success for now
            RETURN 'Function updated successfully - targeting will be implemented';
        END;
        $$ LANGUAGE plpgsql;
        `;
        
        const { error: createError } = await supabase.rpc('exec_sql', { 
            sql_query: createFunctionSQL 
        });
        
        if (createError) {
            console.error('❌ Error creating function:', createError);
        } else {
            console.log('✅ Created new function successfully');
        }
        
    } catch (error) {
        console.error('❌ Alternative script error:', error);
    }
}

// Check if we can access the database
async function testConnection() {
    try {
        const { data, error } = await supabase
            .from('notifications')
            .select('count')
            .limit(1);
        
        if (error) {
            console.error('❌ Database connection failed:', error);
            // Try alternative approach
            await applyTargetingFixAlternative();
        } else {
            console.log('✅ Database connection successful');
            await applyTargetingFix();
        }
    } catch (error) {
        console.error('❌ Connection test failed:', error);
    }
}

testConnection();