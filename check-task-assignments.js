import { createClient } from '@supabase/supabase-js';

// Supabase configuration
const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function checkTaskAssignmentsTable() {
  console.log('🔍 Checking task_assignments table structure...\n');
  
  try {
    // Check task_assignments table structure
    const { data: assignments, error: assignmentError } = await supabase
      .from('task_assignments')
      .select('*')
      .limit(1);
    
    if (assignmentError) {
      console.log('❌ Error fetching task_assignments:', assignmentError);
    } else if (assignments && assignments.length > 0) {
      console.log('📋 task_assignments table columns:');
      Object.keys(assignments[0]).forEach(column => {
        console.log(`  - ${column}`);
      });
    } else {
      console.log('📋 task_assignments table is empty, checking with a different approach...');
      
      // Try to get table information through a test insert
      const { error: testError } = await supabase
        .from('task_assignments')
        .insert([{
          task_id: '00000000-0000-0000-0000-000000000000', // Invalid ID to trigger error
          assignment_type: 'user'
        }]);
      
      console.log('📋 Test insert error (shows required columns):', testError);
    }
    
    // Also check some existing task assignments
    const { data: existingAssignments, error: existingError } = await supabase
      .from('task_assignments')
      .select('*')
      .limit(3);
    
    if (!existingError && existingAssignments) {
      console.log(`\n📊 Found ${existingAssignments.length} existing task assignments`);
      existingAssignments.forEach((assignment, index) => {
        console.log(`\nAssignment ${index + 1}:`);
        Object.entries(assignment).forEach(([key, value]) => {
          console.log(`  ${key}: ${value}`);
        });
      });
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

checkTaskAssignmentsTable();