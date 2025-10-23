import { createClient } from '@supabase/supabase-js';

// Directly set the environment variables
const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function checkTasksTable() {
  console.log('🔍 Checking tasks table structure...');
  
  try {
    // Get table structure
    const { data: tableInfo, error: structureError } = await supabase
      .from('tasks')
      .select('*')
      .limit(1);
    
    if (structureError) {
      console.error('❌ Error getting table structure:', structureError);
      return;
    }
    
    if (tableInfo && tableInfo.length > 0) {
      console.log('📋 Tasks table columns:', Object.keys(tableInfo[0]));
    } else {
      console.log('📋 Tasks table is empty, checking with different approach...');
      
      // Try to insert a minimal record to see what columns are required
      const { data, error } = await supabase
        .from('tasks')
        .insert([{
          title: 'Test Task',
          description: 'Test Description',
          status: 'pending'
        }])
        .select();
        
      if (error) {
        console.log('❌ Test insert error (this helps us see required columns):', error);
      } else {
        console.log('✅ Test task created:', data);
        // Clean up test record
        if (data && data[0]) {
          await supabase.from('tasks').delete().eq('id', data[0].id);
          console.log('🧹 Cleaned up test record');
        }
      }
    }
    
    // Check if there are any existing tasks
    const { data: existingTasks, error: taskError } = await supabase
      .from('tasks')
      .select('*')
      .limit(5);
      
    if (taskError) {
      console.error('❌ Error fetching existing tasks:', taskError);
    } else {
      console.log(`📊 Found ${existingTasks?.length || 0} existing tasks`);
      if (existingTasks && existingTasks.length > 0) {
        console.log('📋 Sample task structure:', Object.keys(existingTasks[0]));
      }
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

checkTasksTable();