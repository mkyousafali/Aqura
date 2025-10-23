// Check Users Table Structure
// This script will help us understand the actual columns in the users table

import { createClient } from '@supabase/supabase-js';

// Using the working credentials from the browser logs
const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
// You'll need to provide the correct key - the one from browser or a working anon key
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mjk2OTY5MzQsImV4cCI6MjA0NTI3MjkzNH0.3PgGrFgrTHIbT29dePmYI_YZEYt7dGWCNDwL8FKtUL8';

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkUsersTable() {
    try {
        console.log('🔍 Checking users table structure...');
        
        // Get a sample user to see the actual columns
        const { data: users, error } = await supabase
            .from('users')
            .select('*')
            .limit(1);
        
        if (error) {
            console.error('❌ Error fetching users:', error);
            return;
        }
        
        if (users && users.length > 0) {
            const user = users[0];
            console.log('✅ Sample user columns:', Object.keys(user));
            console.log('📋 Sample user data:', user);
        } else {
            console.log('⚠️ No users found');
        }
        
        // Check cash payments that need processing
        const { data: cashPayments, error: cashError } = await supabase
            .from('vendor_payment_schedule')
            .select('*')
            .or('payment_method.ilike.%cash%,payment_method.ilike.%cod%')
            .eq('is_paid', false)
            .limit(5);
        
        if (cashError) {
            console.error('❌ Error fetching cash payments:', cashError);
        } else {
            console.log('💰 Unprocessed cash payments:', cashPayments?.length || 0);
            if (cashPayments && cashPayments.length > 0) {
                console.log('📋 Sample cash payment:', cashPayments[0]);
            }
        }
        
    } catch (error) {
        console.error('💥 Error:', error);
    }
}

checkUsersTable().then(() => {
    console.log('🎯 Users table check completed!');
}).catch(error => {
    console.error('💥 Check failed:', error);
});