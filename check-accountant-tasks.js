// =====================================================
// CHECK ACCOUNTANT TASK CREATION
// =====================================================
// This script specifically checks if accountant tasks are being created
// when clearance certificates are generated
// =====================================================

import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://gqqmgqaelflqkdgpvbxl.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdxcW1ncWFlbGZscWtkZ3B2YnhsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzA0NDIzNzgsImV4cCI6MjA0NjAxODM3OH0.G0Q2_bZG3eo6KJ4E8G1g5PZ0iIHhXEo-A6vQQ9BQGnA';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function checkAccountantTasks() {
  console.log('🔍 CHECKING ACCOUNTANT TASK CREATION');
  console.log('=' .repeat(60));

  try {
    // 1. Check if accountant template exists
    console.log('\\n1️⃣ Checking accountant template...');
    const { data: accountantTemplate, error: templateError } = await supabase
      .from('receiving_task_templates')
      .select('*')
      .eq('role_type', 'accountant')
      .single();

    if (templateError) {
      console.error('❌ Error fetching accountant template:', templateError);
      return;
    }

    if (accountantTemplate) {
      console.log('✅ Accountant template found:');
      console.log('   Title:', accountantTemplate.title_template);
      console.log('   Priority:', accountantTemplate.priority);
      console.log('   Deadline hours:', accountantTemplate.deadline_hours);
      console.log('   Requires photo:', accountantTemplate.require_photo_upload || false);
      console.log('   Dependencies:', accountantTemplate.depends_on_role_types || 'None');
    } else {
      console.log('❌ No accountant template found');
      return;
    }

    // 2. Check all role templates to see the full list
    console.log('\\n2️⃣ Checking all role templates...');
    const { data: allTemplates, error: allTemplatesError } = await supabase
      .from('receiving_task_templates')
      .select('role_type, title_template, priority, deadline_hours')
      .order('priority', { ascending: false });

    if (allTemplatesError) {
      console.error('❌ Error fetching all templates:', allTemplatesError);
    } else {
      console.log('✅ All role templates:');
      allTemplates.forEach((template, index) => {
        console.log(`   ${index + 1}. ${template.role_type} (Priority: ${template.priority}, ${template.deadline_hours}h)`);
      });
    }

    // 3. Check existing accountant tasks
    console.log('\\n3️⃣ Checking existing accountant tasks...');
    const { data: accountantTasks, error: tasksError } = await supabase
      .from('receiving_tasks')
      .select('*')
      .eq('role_type', 'accountant')
      .order('created_at', { ascending: false });

    if (tasksError) {
      console.error('❌ Error fetching accountant tasks:', tasksError);
    } else {
      console.log(`✅ Found ${accountantTasks.length} accountant tasks:`);
      if (accountantTasks.length > 0) {
        accountantTasks.slice(0, 5).forEach((task, index) => {
          console.log(`   ${index + 1}. Task ${task.id}:`);
          console.log(`      Title: ${task.title}`);
          console.log(`      Status: ${task.task_status}`);
          console.log(`      Completed: ${task.task_completed ? 'Yes' : 'No'}`);
          console.log(`      Assigned to: ${task.assigned_user_id || 'Unassigned'}`);
          console.log(`      Created: ${task.created_at}`);
          console.log(`      Receiving Record: ${task.receiving_record_id}`);
        });
      } else {
        console.log('   No accountant tasks found');
      }
    }

    // 4. Check tasks by role type to see distribution
    console.log('\\n4️⃣ Checking task distribution by role...');
    const { data: taskStats, error: statsError } = await supabase
      .from('receiving_tasks')
      .select('role_type')
      .order('role_type');

    if (statsError) {
      console.error('❌ Error fetching task stats:', statsError);
    } else {
      const roleCount = {};
      taskStats.forEach(task => {
        roleCount[task.role_type] = (roleCount[task.role_type] || 0) + 1;
      });

      console.log('✅ Tasks by role type:');
      Object.entries(roleCount).forEach(([role, count]) => {
        console.log(`   ${role}: ${count} tasks`);
      });
    }

    // 5. Check recent receiving records to see if tasks are being generated
    console.log('\\n5️⃣ Checking recent receiving records and their tasks...');
    const { data: recentRecords, error: recordsError } = await supabase
      .from('receiving_records')
      .select('id, bill_number, vendor_name, created_at')
      .order('created_at', { ascending: false })
      .limit(5);

    if (recordsError) {
      console.error('❌ Error fetching recent records:', recordsError);
    } else {
      console.log('✅ Recent receiving records:');
      
      for (let i = 0; i < recentRecords.length; i++) {
        const record = recentRecords[i];
        console.log(`\\n   ${i + 1}. Record ${record.id}:`);
        console.log(`      Bill: ${record.bill_number}`);
        console.log(`      Vendor: ${record.vendor_name}`);
        console.log(`      Created: ${record.created_at}`);

        // Check tasks for this record
        const { data: recordTasks, error: recordTasksError } = await supabase
          .from('receiving_tasks')
          .select('role_type, task_status, task_completed')
          .eq('receiving_record_id', record.id);

        if (recordTasksError) {
          console.log(`      ❌ Error fetching tasks: ${recordTasksError.message}`);
        } else {
          console.log(`      📋 Tasks (${recordTasks.length}):`);
          const roleTypes = recordTasks.map(t => t.role_type);
          const hasAccountant = roleTypes.includes('accountant');
          
          console.log(`         Roles: ${roleTypes.join(', ')}`);
          console.log(`         Has accountant task: ${hasAccountant ? '✅ YES' : '❌ NO'}`);
          
          if (hasAccountant) {
            const accountantTask = recordTasks.find(t => t.role_type === 'accountant');
            console.log(`         Accountant status: ${accountantTask.task_status} (${accountantTask.task_completed ? 'completed' : 'pending'})`);
          }
        }
      }
    }

    // 6. Test the task creation function directly (if we can)
    console.log('\\n6️⃣ Testing function behavior...');
    console.log('ℹ️  To test accountant task creation:');
    console.log('   1. Generate a new clearance certificate');
    console.log('   2. Check if accountant task appears in the receiving_tasks table');
    console.log('   3. Verify the task has proper title, description, and assignment');
    
    console.log('\\n✅ SUMMARY:');
    console.log('   📋 Accountant template: ' + (accountantTemplate ? 'EXISTS' : 'MISSING'));
    console.log('   📊 Current accountant tasks: ' + (accountantTasks?.length || 0));
    console.log('   🔧 Template priority: ' + (accountantTemplate?.priority || 'N/A'));
    console.log('   ⏰ Template deadline: ' + (accountantTemplate?.deadline_hours || 'N/A') + ' hours');

    if (accountantTasks?.length === 0) {
      console.log('\\n⚠️  INVESTIGATION NEEDED:');
      console.log('   - Accountant template exists but no tasks found');
      console.log('   - Check if clearance certificates are being generated');
      console.log('   - Check if process_clearance_certificate_generation function is working');
      console.log('   - Check if accountant_user_id is set in receiving_records');
    }

  } catch (error) {
    console.error('💥 Error during analysis:', error);
  }
}

checkAccountantTasks().catch(console.error);