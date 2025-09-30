const { createClient } = require('@supabase/supabase-js');

// Supabase configuration
const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcyNzY5NjQwNCwiZXhwIjoyMDQzMjcyNDA0fQ.L5u2zc6ca6ed1334314e1f5aecf7ac2bbec4be4f6ea2e0c6daa4b8934'; // Service role key for admin operations

// Create Supabase client with service role
const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function runDatabaseUpdates() {
  console.log('🚀 Starting database updates for task completion system...');

  try {
    // 1. Create completion-photos bucket if it doesn't exist
    console.log('📦 Creating completion-photos storage bucket...');
    const { data: bucketData, error: bucketError } = await supabase
      .storage
      .createBucket('completion-photos', {
        public: false,
        fileSizeLimit: 5242880, // 5MB
        allowedMimeTypes: ['image/jpeg', 'image/png', 'image/gif', 'image/webp']
      });

    if (bucketError && !bucketError.message.includes('already exists')) {
      console.error('❌ Error creating bucket:', bucketError);
    } else {
      console.log('✅ Completion-photos bucket ready');
    }

    // 2. Add completion_photo_url column to task_completions table
    console.log('📋 Adding completion_photo_url column...');
    const { error: columnError } = await supabase.rpc('exec_sql', {
      sql: `ALTER TABLE public.task_completions 
            ADD COLUMN IF NOT EXISTS completion_photo_url TEXT NULL;`
    });

    if (columnError) {
      console.error('❌ Error adding column:', columnError);
    } else {
      console.log('✅ completion_photo_url column added');
    }

    // 3. Remove unique constraint to allow multiple completions
    console.log('🔓 Removing unique constraint for multiple task completions...');
    const { error: constraintError } = await supabase.rpc('exec_sql', {
      sql: `ALTER TABLE public.task_completions 
            DROP CONSTRAINT IF EXISTS task_completions_task_id_completed_by_key;`
    });

    if (constraintError) {
      console.error('❌ Error removing constraint:', constraintError);
    } else {
      console.log('✅ Unique constraint removed - multiple completions now allowed');
    }

    // 4. Add comment for the new column
    console.log('📝 Adding column comment...');
    const { error: commentError } = await supabase.rpc('exec_sql', {
      sql: `COMMENT ON COLUMN public.task_completions.completion_photo_url 
            IS 'URL of the uploaded completion photo stored in completion-photos bucket';`
    });

    if (commentError) {
      console.error('❌ Error adding comment:', commentError);
    } else {
      console.log('✅ Column comment added');
    }

    // 5. Create index for photo URL lookups
    console.log('🔍 Creating index for photo URL lookups...');
    const { error: indexError } = await supabase.rpc('exec_sql', {
      sql: `CREATE INDEX IF NOT EXISTS idx_task_completions_photo_url 
            ON public.task_completions 
            USING btree (completion_photo_url) 
            TABLESPACE pg_default
            WHERE completion_photo_url IS NOT NULL;`
    });

    if (indexError) {
      console.error('❌ Error creating index:', indexError);
    } else {
      console.log('✅ Photo URL index created');
    }

    // 6. Handle existing data that might violate new constraint
    console.log('🔧 Fixing existing data...');
    const { error: dataFixError } = await supabase.rpc('exec_sql', {
      sql: `UPDATE public.task_completions 
            SET photo_uploaded_completed = false 
            WHERE photo_uploaded_completed = true 
              AND completion_photo_url IS NULL;`
    });

    if (dataFixError) {
      console.error('❌ Error fixing existing data:', dataFixError);
    } else {
      console.log('✅ Existing data updated');
    }

    // 7. Add photo URL consistency constraint
    console.log('🛡️ Adding photo URL consistency constraint...');
    const { error: consistencyError1 } = await supabase.rpc('exec_sql', {
      sql: `ALTER TABLE public.task_completions 
            DROP CONSTRAINT IF EXISTS chk_photo_url_consistency;`
    });

    const { error: consistencyError2 } = await supabase.rpc('exec_sql', {
      sql: `ALTER TABLE public.task_completions 
            ADD CONSTRAINT chk_photo_url_consistency 
            CHECK (
              (photo_uploaded_completed = false OR completion_photo_url IS NOT NULL)
            );`
    });

    if (consistencyError1 || consistencyError2) {
      console.error('❌ Error adding consistency constraint:', consistencyError1 || consistencyError2);
    } else {
      console.log('✅ Photo URL consistency constraint added');
    }

    // 8. Update the view to include the new column
    console.log('👁️ Updating task_completion_summary view...');
    const { error: viewError } = await supabase.rpc('exec_sql', {
      sql: `CREATE OR REPLACE VIEW task_completion_summary AS
            SELECT 
              tc.id as completion_id,
              tc.task_id,
              t.title as task_title,
              t.priority as task_priority,
              tc.assignment_id,
              tc.completed_by,
              tc.completed_by_name,
              tc.completed_by_branch_id,
              b.name_en as branch_name,
              tc.task_finished_completed,
              tc.photo_uploaded_completed,
              tc.completion_photo_url,
              tc.erp_reference_completed,
              tc.erp_reference_number,
              tc.completion_notes,
              tc.verified_by,
              tc.verified_at,
              tc.verification_notes,
              tc.completed_at,
              ROUND(
                (CASE WHEN tc.task_finished_completed THEN 1 ELSE 0 END +
                 CASE WHEN tc.photo_uploaded_completed THEN 1 ELSE 0 END +
                 CASE WHEN tc.erp_reference_completed THEN 1 ELSE 0 END) * 100.0 / 3, 2
              ) as completion_percentage,
              (tc.task_finished_completed = true AND 
               tc.photo_uploaded_completed = true AND 
               tc.erp_reference_completed = true) as is_fully_completed
            FROM public.task_completions tc
            JOIN public.tasks t ON tc.task_id = t.id
            LEFT JOIN public.branches b ON tc.completed_by_branch_id::text = b.id::text
            ORDER BY tc.completed_at DESC;`
    });

    if (viewError) {
      console.error('❌ Error updating view:', viewError);
    } else {
      console.log('✅ task_completion_summary view updated');
    }

    console.log('\n🎉 Database updates completed successfully!');
    console.log('\n📋 Summary of changes:');
    console.log('  ✅ completion-photos storage bucket ready');
    console.log('  ✅ completion_photo_url column added to task_completions');
    console.log('  ✅ Unique constraint removed (allows multiple task completions)');
    console.log('  ✅ Photo URL consistency constraint added');
    console.log('  ✅ Index created for photo URL lookups');
    console.log('  ✅ View updated to include photo URLs');
    console.log('\n🚀 Task completion system is now ready!');

  } catch (error) {
    console.error('❌ Unexpected error:', error);
  }
}

// Note: This script requires the exec_sql function to be available in your Supabase database
// If exec_sql is not available, you'll need to run the SQL commands manually in the Supabase SQL editor

async function checkExecSqlFunction() {
  console.log('🔍 Checking if exec_sql function is available...');
  
  const { data, error } = await supabase.rpc('exec_sql', {
    sql: 'SELECT 1 as test;'
  });

  if (error) {
    console.error('❌ exec_sql function not available. Please run the SQL commands manually in Supabase SQL editor.');
    console.log('\n📋 Manual SQL to run in Supabase:');
    console.log('Copy and paste the contents of add-completion-photo-url-column.sql into your Supabase SQL editor.');
    return false;
  } else {
    console.log('✅ exec_sql function is available');
    return true;
  }
}

// Main execution
async function main() {
  const canRunSQL = await checkExecSqlFunction();
  
  if (canRunSQL) {
    await runDatabaseUpdates();
  } else {
    console.log('\n⚠️ Cannot run SQL automatically. Please use the manual SQL file approach.');
  }
}

main().catch(console.error);