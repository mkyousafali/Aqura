const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjUwMDIzMDgsImV4cCI6MjA0MDU3ODMwOH0.TqAcQAbbv9VFb19Cs5BPl_RJ0k0T7POw0_QbBGpYqmQ';

const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function createStorageBuckets() {
  try {
    console.log('Creating storage buckets using Supabase client...');

    // Create task-images bucket
    const { data: taskImagesData, error: taskImagesError } = await supabase.storage.createBucket('task-images', {
      public: false,
      allowedMimeTypes: ['image/jpeg', 'image/png', 'image/gif', 'image/webp'],
      fileSizeLimit: 5242880 // 5MB
    });

    if (taskImagesError) {
      if (taskImagesError.message.includes('already exists')) {
        console.log('✅ task-images bucket already exists');
      } else {
        console.error('❌ Error creating task-images bucket:', taskImagesError.message);
      }
    } else {
      console.log('✅ task-images bucket created successfully');
    }

    // Create completion-photos bucket
    const { data: completionPhotosData, error: completionPhotosError } = await supabase.storage.createBucket('completion-photos', {
      public: false,
      allowedMimeTypes: ['image/jpeg', 'image/png', 'image/gif', 'image/webp'],
      fileSizeLimit: 5242880 // 5MB
    });

    if (completionPhotosError) {
      if (completionPhotosError.message.includes('already exists')) {
        console.log('✅ completion-photos bucket already exists');
      } else {
        console.error('❌ Error creating completion-photos bucket:', completionPhotosError.message);
      }
    } else {
      console.log('✅ completion-photos bucket created successfully');
    }

    // Create documents bucket
    const { data: documentsData, error: documentsError } = await supabase.storage.createBucket('documents', {
      public: false,
      allowedMimeTypes: ['application/pdf', 'image/jpeg', 'image/png', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'text/plain'],
      fileSizeLimit: 10485760 // 10MB
    });

    if (documentsError) {
      if (documentsError.message.includes('already exists')) {
        console.log('✅ documents bucket already exists');
      } else {
        console.error('❌ Error creating documents bucket:', documentsError.message);
      }
    } else {
      console.log('✅ documents bucket created successfully');
    }

    // List all buckets to verify
    const { data: buckets, error: listError } = await supabase.storage.listBuckets();
    if (!listError) {
      console.log('\n📁 Available storage buckets:');
      buckets.forEach(bucket => {
        console.log(`  - ${bucket.name} (public: ${bucket.public})`);
      });
    } else {
      console.error('❌ Error listing buckets:', listError.message);
    }

    console.log('\n🎉 Storage bucket setup completed!');
    console.log('\n📋 Note: Storage policies need to be set up in the Supabase dashboard under Storage > Policies');
    console.log('You can use the RLS policies from the create-storage-buckets.sql file');

  } catch (error) {
    console.error('❌ Error setting up storage buckets:', error.message);
  }
}

// Run the setup
createStorageBuckets();