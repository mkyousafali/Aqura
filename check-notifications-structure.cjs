const fs = require('fs');
const { createClient } = require('@supabase/supabase-js');

// Load environment variables
const envPath = './frontend/.env';
const envContent = fs.readFileSync(envPath, 'utf-8');
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

(async () => {
  console.log('Checking notifications table structure...\n');
  
  // Try to select with limit 0 to get column structure
  const { data, error } = await supabase
    .from('notifications')
    .select('*')
    .limit(1);
  
  if (error) {
    console.error('❌ Error querying notifications:', error.message);
    console.error('Full error:', error);
  } else {
    console.log('✅ Query successful!');
    if (data && data.length > 0) {
      console.log('\n📋 Notifications table columns:');
      const columns = Object.keys(data[0]);
      columns.forEach(col => {
        console.log(`   - ${col}: ${typeof data[0][col]}`);
      });
      
      console.log('\n📊 Sample notification:');
      console.log(JSON.stringify(data[0], null, 2));
    } else {
      console.log('\n⚠️ Table is empty, but structure exists.');
      console.log('Attempting to get column info another way...');
      
      // Try inserting a test notification to see what columns are required
      console.log('\nAttempting test insert (will fail intentionally)...');
      const { data: testData, error: testError } = await supabase
        .from('notifications')
        .insert({
          title: 'TEST',
          message: 'TEST',
          type: 'test',
          created_by: '00000000-0000-0000-0000-000000000000'
        })
        .select();
      
      if (testError) {
        console.error('\n❌ Test insert error:', testError.message);
        console.error('Error code:', testError.code);
        console.error('Details:', testError.details);
        console.error('Hint:', testError.hint);
      } else {
        console.log('\n✅ Test insert successful!');
        console.log('Inserted columns:', Object.keys(testData[0]));
        
        // Delete the test notification
        await supabase
          .from('notifications')
          .delete()
          .eq('title', 'TEST');
      }
    }
  }
  
  console.log('\n' + '='.repeat(80));
  console.log('\nNow checking for RLS policies on notifications table...');
  console.log('(This requires looking at pg_policies system table)\n');
  
  // Try to get a notification to see what happens
  const { data: notifData, error: notifError } = await supabase
    .from('notifications')
    .select('*')
    .limit(1);
  
  if (notifError) {
    console.log('❌ Error with service role key:', notifError.message);
  } else {
    console.log('✅ Service role can access notifications table');
  }
})();
