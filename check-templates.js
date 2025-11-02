import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'fs';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function checkTemplates() {
  console.log('🔍 Checking templates in database...\n');

  const { data, error } = await supabase
    .from('receiving_task_templates')
    .select('*')
    .order('role_type');

  if (error) {
    console.error('❌ Error:', error.message);
    return;
  }

  console.log(`Found ${data?.length || 0} templates:\n`);
  
  if (data && data.length > 0) {
    data.forEach((t, idx) => {
      console.log(`${idx + 1}. ${t.role_type}`);
      console.log(`   Title: ${t.title_template}`);
      console.log(`   Deadline: ${t.deadline_hours} hours`);
      console.log(`   Priority: ${t.priority}\n`);
    });
  } else {
    console.log('⚠️  No templates found! Need to run receiving_task_templates_data.sql migration');
  }
}

checkTemplates()
  .then(() => process.exit(0))
  .catch(err => {
    console.error('Fatal:', err);
    process.exit(1);
  });
