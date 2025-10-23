#!/usr/bin/env node

import { createClient } from '@supabase/supabase-js';

// Supabase configuration
const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function exploreDatabase() {
  console.log('🔍 Exploring database structure...');
  
  try {
    // Check vendor_payment_schedule structure
    console.log('\n📋 Checking vendor_payment_schedule table...');
    const { data: paymentSchedule, error: scheduleError } = await supabase
      .from('vendor_payment_schedule')
      .select('*')
      .limit(3);
      
    if (scheduleError) {
      console.error('❌ Error accessing vendor_payment_schedule:', scheduleError);
    } else {
      console.log('✅ vendor_payment_schedule sample data:');
      console.log(JSON.stringify(paymentSchedule, null, 2));
    }
    
    // Check payment_transactions structure
    console.log('\n💳 Checking payment_transactions table...');
    const { data: paymentTrans, error: transError } = await supabase
      .from('payment_transactions')
      .select('*')
      .limit(3);
      
    if (transError) {
      console.error('❌ Error accessing payment_transactions:', transError);
    } else {
      console.log('✅ payment_transactions sample data:');
      console.log(JSON.stringify(paymentTrans, null, 2));
    }
    
    // Check if there are any paid records
    console.log('\n✅ Checking for paid records...');
    const { data: paidRecords, error: paidError } = await supabase
      .from('vendor_payment_schedule')
      .select('*')
      .eq('is_paid', true)
      .limit(5);
      
    if (paidError) {
      console.error('❌ Error checking paid records:', paidError);
    } else {
      console.log(`✅ Found ${paidRecords?.length || 0} paid records:`);
      console.log(JSON.stringify(paidRecords, null, 2));
    }
    
  } catch (error) {
    console.error('❌ Database exploration failed:', error);
  }
}

// Run the exploration
exploreDatabase();