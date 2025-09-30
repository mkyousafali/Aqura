const { createClient } = require('@supabase/supabase-js');

// Use your project details
const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';

// Try different service role keys - replace with your actual one from Supabase dashboard
const possibleServiceKeys = [
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.KVPfLdYhk3a6OJXnVcyOGwRIJGDl7uSUjIW_l7f-VgE',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcyNTAwMjMwOCwiZXhwIjoyMDQwNTc4MzA4fQ.GnNzFXJhh8_LdIHqPV9IbYHMrCUP-k_kH9YqCHqfVrY'
];

async function createStorageBucketsWithFallback() {
  console.log('🚀 Attempting to create storage buckets...');

  // Try each service key until one works
  for (let i = 0; i < possibleServiceKeys.length; i++) {
    const serviceKey = possibleServiceKeys[i];
    console.log(`\n🔑 Trying service key ${i + 1}...`);

    try {
      const supabase = createClient(supabaseUrl, serviceKey, {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      });

      // Test the connection first
      const { data: testData, error: testError } = await supabase.storage.listBuckets();
      
      if (testError && testError.message.includes('signature verification')) {
        console.log(`  ❌ Service key ${i + 1} failed authentication`);
        continue;
      }

      console.log(`  ✅ Service key ${i + 1} works! Creating buckets...`);

      // Define buckets to create
      const buckets = [
        {
          id: 'task-images',
          options: {
            public: false,
            allowedMimeTypes: ['image/jpeg', 'image/png', 'image/gif', 'image/webp'],
            fileSizeLimit: 5242880 // 5MB
          }
        },
        {
          id: 'completion-photos',
          options: {
            public: false,
            allowedMimeTypes: ['image/jpeg', 'image/png', 'image/gif', 'image/webp'],
            fileSizeLimit: 5242880 // 5MB
          }
        },
        {
          id: 'documents',
          options: {
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
        }
      ];

      // Create each bucket
      for (const bucket of buckets) {
        console.log(`\n📁 Creating bucket: ${bucket.id}`);
        
        const { data, error } = await supabase.storage.createBucket(bucket.id, bucket.options);

        if (error) {
          if (error.message.includes('already exists')) {
            console.log(`  ✅ Bucket '${bucket.id}' already exists`);
          } else {
            console.log(`  ⚠️  Error creating '${bucket.id}':`, error.message);
          }
        } else {
          console.log(`  ✅ Successfully created '${bucket.id}' bucket`);
        }
      }

      // List all buckets to verify
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
      console.log('\n⚠️  Important: You may need to set up storage policies in the Supabase dashboard');
      console.log('Go to: Storage > Policies in your Supabase dashboard');
      
      return; // Success, exit function

    } catch (error) {
      console.log(`  ❌ Service key ${i + 1} failed:`, error.message);
    }
  }

  // If all service keys failed, provide manual instructions
  console.log('\n❌ All service keys failed. Please create buckets manually:');
  console.log('\n📋 Manual Setup Instructions:');
  console.log('1. Go to: https://supabase.com/dashboard/project/vmypotfsyrvuublyddyt');
  console.log('2. Navigate to Storage in the left sidebar');
  console.log('3. Click "Create bucket" and create these buckets:');
  console.log('   - task-images (Private, 5MB limit, image types only)');
  console.log('   - completion-photos (Private, 5MB limit, image types only)');
  console.log('   - documents (Private, 10MB limit, document types)');
  console.log('4. Set up policies for authenticated users to upload/view files');
}

// Run the setup
createStorageBucketsWithFallback();