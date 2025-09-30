const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcyNTAwMjMwOCwiZXhwIjoyMDQwNTc4MzA4fQ.GnNzFXJhh8_LdIHqPV9IbYHMrCUP-k_kH9YqCHqfVrY'; // Service role key for admin operations

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function createStorageBuckets() {
  try {
    console.log('Creating storage buckets...');

    // Create task-images bucket
    const { data: taskImagesBucket, error: taskImagesError } = await supabase.storage.createBucket('task-images', {
      public: false,
      allowedMimeTypes: ['image/jpeg', 'image/png', 'image/gif', 'image/webp'],
      fileSizeLimit: 5242880 // 5MB
    });

    if (taskImagesError && !taskImagesError.message.includes('already exists')) {
      console.error('Error creating task-images bucket:', taskImagesError);
    } else {
      console.log('✅ task-images bucket created successfully');
    }

    // Create completion-photos bucket for task completion photos
    const { data: completionPhotosBucket, error: completionPhotosError } = await supabase.storage.createBucket('completion-photos', {
      public: false,
      allowedMimeTypes: ['image/jpeg', 'image/png', 'image/gif', 'image/webp'],
      fileSizeLimit: 5242880 // 5MB
    });

    if (completionPhotosError && !completionPhotosError.message.includes('already exists')) {
      console.error('Error creating completion-photos bucket:', completionPhotosError);
    } else {
      console.log('✅ completion-photos bucket created successfully');
    }

    // Create documents bucket for general document uploads
    const { data: documentsBucket, error: documentsError } = await supabase.storage.createBucket('documents', {
      public: false,
      allowedMimeTypes: ['application/pdf', 'image/jpeg', 'image/png', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
      fileSizeLimit: 10485760 // 10MB
    });

    if (documentsError && !documentsError.message.includes('already exists')) {
      console.error('Error creating documents bucket:', documentsError);
    } else {
      console.log('✅ documents bucket created successfully');
    }

    console.log('\n📋 Setting up storage policies...');

    // Storage policies for task-images bucket
    const taskImagesPolicies = [
      {
        name: 'Allow authenticated users to upload task images',
        definition: `(bucket_id = 'task-images') AND (auth.role() = 'authenticated')`,
        action: 'INSERT'
      },
      {
        name: 'Allow authenticated users to view task images',
        definition: `(bucket_id = 'task-images') AND (auth.role() = 'authenticated')`,
        action: 'SELECT'
      },
      {
        name: 'Allow users to update their own task images',
        definition: `(bucket_id = 'task-images') AND (auth.role() = 'authenticated')`,
        action: 'UPDATE'
      },
      {
        name: 'Allow users to delete their own task images',
        definition: `(bucket_id = 'task-images') AND (auth.role() = 'authenticated')`,
        action: 'DELETE'
      }
    ];

    // Storage policies for completion-photos bucket
    const completionPhotosPolicies = [
      {
        name: 'Allow authenticated users to upload completion photos',
        definition: `(bucket_id = 'completion-photos') AND (auth.role() = 'authenticated')`,
        action: 'INSERT'
      },
      {
        name: 'Allow authenticated users to view completion photos',
        definition: `(bucket_id = 'completion-photos') AND (auth.role() = 'authenticated')`,
        action: 'SELECT'
      }
    ];

    // Storage policies for documents bucket
    const documentsPolicies = [
      {
        name: 'Allow authenticated users to upload documents',
        definition: `(bucket_id = 'documents') AND (auth.role() = 'authenticated')`,
        action: 'INSERT'
      },
      {
        name: 'Allow authenticated users to view documents',
        definition: `(bucket_id = 'documents') AND (auth.role() = 'authenticated')`,
        action: 'SELECT'
      },
      {
        name: 'Allow users to update their own documents',
        definition: `(bucket_id = 'documents') AND (auth.role() = 'authenticated')`,
        action: 'UPDATE'
      },
      {
        name: 'Allow users to delete their own documents',
        definition: `(bucket_id = 'documents') AND (auth.role() = 'authenticated')`,
        action: 'DELETE'
      }
    ];

    // Apply policies via SQL (more reliable than the JS API for policies)
    const allPolicies = [
      ...taskImagesPolicies,
      ...completionPhotosPolicies,
      ...documentsPolicies
    ];

    for (const policy of allPolicies) {
      const policySQL = `
        DO $$
        BEGIN
          IF NOT EXISTS (
            SELECT 1 FROM pg_policies 
            WHERE schemaname = 'storage' 
            AND tablename = 'objects' 
            AND policyname = '${policy.name}'
          ) THEN
            CREATE POLICY "${policy.name}"
            ON storage.objects FOR ${policy.action}
            TO authenticated
            USING (${policy.definition});
          END IF;
        END $$;
      `;

      const { error: policyError } = await supabase.rpc('exec_sql', { sql: policySQL });
      
      if (policyError) {
        console.log(`⚠️  Policy "${policy.name}" may already exist or failed to create:`, policyError.message);
      } else {
        console.log(`✅ Policy "${policy.name}" created successfully`);
      }
    }

    // Enable RLS on storage.objects if not already enabled
    const { error: rlsError } = await supabase.rpc('exec_sql', { 
      sql: 'ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;' 
    });

    if (rlsError && !rlsError.message.includes('already enabled')) {
      console.log('⚠️  RLS may already be enabled on storage.objects:', rlsError.message);
    } else {
      console.log('✅ Row Level Security enabled on storage.objects');
    }

    console.log('\n🎉 Storage buckets and policies setup completed!');
    
    // List all buckets to verify
    const { data: buckets, error: listError } = await supabase.storage.listBuckets();
    if (!listError) {
      console.log('\n📁 Available storage buckets:');
      buckets.forEach(bucket => {
        console.log(`  - ${bucket.name} (public: ${bucket.public})`);
      });
    }

  } catch (error) {
    console.error('❌ Error setting up storage buckets:', error);
  }
}

// Run the setup
createStorageBuckets();