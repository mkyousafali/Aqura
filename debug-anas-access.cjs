const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcyOTc3MDkzNCwiZXhwIjoyMDQ1MzQ2OTM0fQ.4uD6lzJgnwX1YLy5WnSJIWrBRfKH8tU2xfwIGP7Qx5o';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function debugAnasAccess() {
  console.log('🔍 Debugging Anas access...');
  
  // Find Anas user
  const { data: user, error: userError } = await supabase
    .from('users')
    .select('*')
    .eq('username', 'Anas')
    .single();
    
  if (userError) {
    console.error('Error finding user:', userError);
    return;
  }
  
  console.log('👤 User Anas:', {
    id: user.id,
    username: user.username,
    role_type: user.role_type,
    employee_id: user.employee_id
  });
  
  // Get current positions
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
    console.error('Error getting positions:', positionsError);
    return;
  }
  
  console.log('📋 Current positions:', positions?.map(p => ({
    position: p.hr_positions?.position_title_en,
    effective_date: p.effective_date,
    is_current: p.is_current
  })));
  
  // Check if there are any branch_manager tasks assigned to this user
  const { data: tasks, error: tasksError } = await supabase
    .from('receiving_tasks')
    .select('*')
    .eq('assigned_user_id', user.id)
    .eq('role_type', 'branch_manager')
    .eq('task_completed', false);
    
  if (tasksError) {
    console.error('Error getting tasks:', tasksError);
    return;
  }
  
  console.log('📋 Branch manager tasks assigned to Anas:', tasks?.length || 0);
  if (tasks && tasks.length > 0) {
    console.log('Task details:', tasks.map(t => ({
      id: t.id,
      title: t.title,
      role_type: t.role_type,
      assigned_date: t.created_at
    })));
  }
  
  // Check if Anas should have Branch Manager access based on business rules
  console.log('\n🤔 Analysis:');
  console.log('- Anas has position: Night Supervisors');
  console.log('- Trying to access: branch_manager task');
  console.log('- Required position: Branch Manager');
  console.log('- Should Night Supervisors have Branch Manager access? This needs business clarification.');
}

debugAnasAccess().catch(console.error);