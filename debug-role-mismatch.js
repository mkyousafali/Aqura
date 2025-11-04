// Debug role mismatch issue
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseKey);

async function debugRoleMismatch() {
  console.log('=== Debugging Role Mismatch Issue ===');
  
  const userId = '6f883b06-13a8-476b-86ce-a7a79553a4bd'; // Hisham's ID from logs
  const taskId = '72975b25-b777-43f9-b31e-c901c4d30af7'; // Task ID from logs
  
  console.log('1. Checking user details...');
  const { data: user, error: userError } = await supabase
    .from('users')
    .select('*')
    .eq('id', userId)
    .single();
  
  if (userError) {
    console.error('❌ User error:', userError);
  } else {
    console.log('✅ User details:', {
      id: user.id,
      username: user.username,
      role_type: user.role_type,
      user_type: user.user_type,
      status: user.status
    });
  }
  
  console.log('\n2. Checking receiving task details...');
  const { data: task, error: taskError } = await supabase
    .from('receiving_tasks')
    .select('*')
    .eq('id', taskId)
    .single();
  
  if (taskError) {
    console.error('❌ Task error:', taskError);
  } else {
    console.log('✅ Task details:', {
      id: task.id,
      role_type: task.role_type,
      user_id: task.user_id,
      status: task.status
    });
  }
  
  console.log('\n3. Role comparison:');
  if (user && task) {
    console.log(`User role_type: "${user.role_type}"`);
    console.log(`Task role_type: "${task.role_type}"`);
    console.log(`Do they match? ${user.role_type === task.role_type}`);
    
    // Check if this user should have access to inventory_manager tasks
    console.log('\n4. Checking if user has inventory manager position...');
    const { data: positions, error: positionsError } = await supabase
      .from('hr_position_assignments')
      .select(`
        *,
        hr_positions (
          position_title_en,
          position_title_ar
        )
      `)
      .eq('employee_id', user.employee_id)
      .eq('is_current', true);
    
    if (positionsError) {
      console.error('❌ Positions error:', positionsError);
    } else {
      console.log('✅ Current positions:', positions?.map(p => ({
        position: p.hr_positions?.position_title_en,
        effective_date: p.effective_date
      })));
    }
  }
}

debugRoleMismatch().then(() => process.exit(0)).catch(err => {
  console.error('Failed:', err);
  process.exit(1);
});