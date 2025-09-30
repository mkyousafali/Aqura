const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

// Load environment variables from .env file
function loadEnv() {
  const envPath = path.join(__dirname, '.env');
  if (fs.existsSync(envPath)) {
    const envContent = fs.readFileSync(envPath, 'utf8');
    const lines = envContent.split('\n');
    
    for (const line of lines) {
      const trimmed = line.trim();
      if (trimmed && !trimmed.startsWith('#') && trimmed.includes('=')) {
        const [key, ...valueParts] = trimmed.split('=');
        const value = valueParts.join('=');
        process.env[key.trim()] = value.trim();
      }
    }
  }
}

loadEnv();

const supabaseUrl = process.env.PUBLIC_SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

console.log('🔗 Supabase URL:', supabaseUrl);
console.log('🔑 Service Key loaded:', supabaseServiceKey ? 'Yes' : 'No');

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('❌ Missing Supabase URL or Service Role Key in .env file');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function testStorageBuckets() {
  try {
    console.log('🧪 Testing storage buckets with correct service role key...');

    // Test authentication by listing buckets
    const { data: buckets, error: listError } = await supabase.storage.listBuckets();
    
    if (listError) {
      console.error('❌ Failed to list buckets:', listError.message);
      return;
    }

    console.log('✅ Authentication successful!');
    console.log('\n📁 Available storage buckets:');
    buckets.forEach(bucket => {
      const isRequired = ['task-images', 'completion-photos', 'documents'].includes(bucket.name);
      const status = isRequired ? '✅' : '📁';
      console.log(`  ${status} ${bucket.name} (public: ${bucket.public})`);
    });

    // Check if our required buckets exist
    const requiredBuckets = ['task-images', 'completion-photos', 'documents'];
    const existingBucketNames = buckets.map(b => b.name);
    const missingBuckets = requiredBuckets.filter(name => !existingBucketNames.includes(name));

    if (missingBuckets.length > 0) {
      console.log('\n⚠️  Missing buckets:', missingBuckets.join(', '));
      console.log('🔧 Creating missing buckets...');

      for (const bucketName of missingBuckets) {
        const bucketConfig = getBucketConfig(bucketName);
        const { data, error } = await supabase.storage.createBucket(bucketName, bucketConfig);

        if (error) {
          console.error(`❌ Failed to create ${bucketName}:`, error.message);
        } else {
          console.log(`✅ Created ${bucketName} bucket successfully`);
        }
      }
    } else {
      console.log('\n✅ All required storage buckets exist!');
    }

    // Test file upload to task-images bucket
    console.log('\n🧪 Testing file upload...');
    const testFileName = `test-${Date.now()}.txt`;
    const testContent = new Blob(['Test file for storage bucket'], { type: 'text/plain' });
    
    const { data: uploadData, error: uploadError } = await supabase.storage
      .from('task-images')
      .upload(testFileName, testContent);

    if (uploadError) {
      console.error('❌ File upload test failed:', uploadError.message);
    } else {
      console.log('✅ File upload test successful');
      
      // Clean up test file
      await supabase.storage.from('task-images').remove([testFileName]);
      console.log('🧹 Test file cleaned up');
    }

    console.log('\n🎉 Storage system is ready for task creation!');

  } catch (error) {
    console.error('❌ Test failed:', error.message);
  }
}

function getBucketConfig(bucketName) {
  const configs = {
    'task-images': {
      public: false,
      allowedMimeTypes: ['image/jpeg', 'image/png', 'image/gif', 'image/webp'],
      fileSizeLimit: 5242880 // 5MB
    },
    'completion-photos': {
      public: false,
      allowedMimeTypes: ['image/jpeg', 'image/png', 'image/gif', 'image/webp'],
      fileSizeLimit: 5242880 // 5MB
    },
    'documents': {
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
  };

  return configs[bucketName] || {};
}

// Run the test
testStorageBuckets();