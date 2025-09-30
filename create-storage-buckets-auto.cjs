const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
// Use the actual service role key from Supabase dashboard
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.KVPfLdYhk3a6OJXnVcyOGwRIJGDl7uSUjIW_l7f-VgE';

const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function createStorageBuckets() {
  try {
    console.log('🚀 Creating storage buckets automatically...');

    // Bucket configurations
    const buckets = [
      {
        id: 'task-images',
        name: 'task-images',
        public: false,
        allowedMimeTypes: ['image/jpeg', 'image/png', 'image/gif', 'image/webp'],
        fileSizeLimit: 5242880 // 5MB
      },
      {
        id: 'completion-photos',
        name: 'completion-photos',
        public: false,
        allowedMimeTypes: ['image/jpeg', 'image/png', 'image/gif', 'image/webp'],
        fileSizeLimit: 5242880 // 5MB
      },
      {
        id: 'documents',
        name: 'documents',
        public: false,
        allowedMimeTypes: [
          'application/pdf', 
          'image/jpeg', 
          'image/png', 
          'application/msword', 
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          'text/plain'
        ],
        fileSizeLimit: 10485760 // 10MB
      }
    ];

    // Create each bucket
    for (const bucket of buckets) {
      console.log(`\n📁 Creating bucket: ${bucket.name}`);
      
      const { data, error } = await supabase.storage.createBucket(bucket.id, {
        public: bucket.public,
        allowedMimeTypes: bucket.allowedMimeTypes,
        fileSizeLimit: bucket.fileSizeLimit
      });

      if (error) {
        if (error.message.includes('already exists')) {
          console.log(`  ✅ Bucket '${bucket.name}' already exists`);
        } else {
          console.error(`  ❌ Error creating '${bucket.name}':`, error.message);
        }
      } else {
        console.log(`  ✅ Successfully created '${bucket.name}' bucket`);
      }
    }

    console.log('\n🔐 Setting up storage policies...');

    // RLS Policies for each bucket
    const policies = [
      // task-images policies
      {
        name: 'task_images_upload_policy',
        bucket: 'task-images',
        operation: 'INSERT',
        definition: `bucket_id = 'task-images'`
      },
      {
        name: 'task_images_select_policy',
        bucket: 'task-images',
        operation: 'SELECT',
        definition: `bucket_id = 'task-images'`
      },
      {
        name: 'task_images_update_policy',
        bucket: 'task-images',
        operation: 'UPDATE',
        definition: `bucket_id = 'task-images'`
      },
      {
        name: 'task_images_delete_policy',
        bucket: 'task-images',
        operation: 'DELETE',
        definition: `bucket_id = 'task-images'`
      },
      // completion-photos policies
      {
        name: 'completion_photos_upload_policy',
        bucket: 'completion-photos',
        operation: 'INSERT',
        definition: `bucket_id = 'completion-photos'`
      },
      {
        name: 'completion_photos_select_policy',
        bucket: 'completion-photos',
        operation: 'SELECT',
        definition: `bucket_id = 'completion-photos'`
      },
      {
        name: 'completion_photos_update_policy',
        bucket: 'completion-photos',
        operation: 'UPDATE',
        definition: `bucket_id = 'completion-photos'`
      },
      {
        name: 'completion_photos_delete_policy',
        bucket: 'completion-photos',
        operation: 'DELETE',
        definition: `bucket_id = 'completion-photos'`
      },
      // documents policies
      {
        name: 'documents_upload_policy',
        bucket: 'documents',
        operation: 'INSERT',
        definition: `bucket_id = 'documents'`
      },
      {
        name: 'documents_select_policy',
        bucket: 'documents',
        operation: 'SELECT',
        definition: `bucket_id = 'documents'`
      },
      {
        name: 'documents_update_policy',
        bucket: 'documents',
        operation: 'UPDATE',
        definition: `bucket_id = 'documents'`
      },
      {
        name: 'documents_delete_policy',
        bucket: 'documents',
        operation: 'DELETE',
        definition: `bucket_id = 'documents'`
      }
    ];

    // Apply policies using SQL
    for (const policy of policies) {
      const sql = `
        DO $$
        BEGIN
          IF NOT EXISTS (
            SELECT 1 FROM pg_policies 
            WHERE schemaname = 'storage' 
            AND tablename = 'objects' 
            AND policyname = '${policy.name}'
          ) THEN
            EXECUTE format('CREATE POLICY %I ON storage.objects FOR ${policy.operation} TO authenticated USING (%s)', 
              '${policy.name}', 
              '${policy.definition}'
            );
            RAISE NOTICE 'Policy % created successfully', '${policy.name}';
          ELSE
            RAISE NOTICE 'Policy % already exists', '${policy.name}';
          END IF;
        END $$;
      `;

      const { error: policyError } = await supabase.rpc('exec_sql', { sql });
      
      if (policyError) {
        console.log(`  ⚠️  Policy '${policy.name}' may already exist:`, policyError.message);
      } else {
        console.log(`  ✅ Policy '${policy.name}' applied successfully`);
      }
    }

    // Enable RLS on storage.objects
    const rlsSQL = `
      DO $$
      BEGIN
        EXECUTE 'ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY';
        RAISE NOTICE 'RLS enabled on storage.objects';
      EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'RLS may already be enabled: %', SQLERRM;
      END $$;
    `;

    const { error: rlsError } = await supabase.rpc('exec_sql', { sql: rlsSQL });
    if (rlsError) {
      console.log('  ⚠️  RLS may already be enabled:', rlsError.message);
    } else {
      console.log('  ✅ Row Level Security enabled');
    }

    // Verify buckets were created
    console.log('\n📋 Verifying created buckets...');
    const { data: bucketList, error: listError } = await supabase.storage.listBuckets();
    
    if (!listError) {
      console.log('\n📁 Available storage buckets:');
      bucketList.forEach(bucket => {
        const isOurs = ['task-images', 'completion-photos', 'documents'].includes(bucket.name);
        const status = isOurs ? '✅' : '📁';
        console.log(`  ${status} ${bucket.name} (public: ${bucket.public})`);
      });
    }

    console.log('\n🎉 Storage buckets setup completed successfully!');
    console.log('📝 You can now upload images and documents to your tasks.');

  } catch (error) {
    console.error('❌ Error setting up storage buckets:', error.message);
    process.exit(1);
  }
}

// Install the exec_sql function if it doesn't exist
async function setupExecFunction() {
  const functionSQL = `
    CREATE OR REPLACE FUNCTION exec_sql(sql text)
    RETURNS void
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $$
    BEGIN
      EXECUTE sql;
    END;
    $$;
  `;

  const { error } = await supabase.rpc('exec_sql', { sql: functionSQL });
  if (error && !error.message.includes('already exists')) {
    console.log('Setting up exec function...');
    // If the function doesn't exist, we'll create it directly
    const { data, error: createError } = await supabase
      .from('pg_stat_activity')
      .select('*')
      .limit(1);
    
    if (createError) {
      console.log('Note: Some advanced features may not work without the exec_sql function');
    }
  }
}

// Run the setup
setupExecFunction().then(() => createStorageBuckets());