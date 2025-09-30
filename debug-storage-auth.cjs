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
const supabaseAnonKey = process.env.PUBLIC_SUPABASE_ANON_KEY;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

console.log('🔗 Supabase URL:', supabaseUrl);
console.log('🔑 Anon Key loaded:', supabaseAnonKey ? 'Yes' : 'No');
console.log('🔑 Service Key loaded:', supabaseServiceKey ? 'Yes' : 'No');

// Create client with anon key (like frontend)
const supabaseAnon = createClient(supabaseUrl, supabaseAnonKey);

// Create client with service key (for admin operations)
const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function debugStorageAuthentication() {
  try {
    console.log('\n🔍 Debugging storage authentication...');

    // Test 1: Check if policies exist
    console.log('\n1️⃣ Checking storage policies...');
    
    const policiesQuery = `
      SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
      FROM pg_policies 
      WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname LIKE '%task_images%'
      ORDER BY policyname;
    `;
    
    const { data: policies, error: policiesError } = await supabaseAdmin
      .rpc('exec_sql', { sql: policiesQuery });
    
    if (policiesError) {
      console.log('⚠️  Could not fetch policies (this is normal)');
    } else {
      console.log('✅ Storage policies found');
    }

    // Test 2: Check bucket configuration
    console.log('\n2️⃣ Checking bucket configuration...');
    
    const { data: buckets, error: bucketsError } = await supabaseAdmin.storage.listBuckets();
    
    if (bucketsError) {
      console.error('❌ Failed to list buckets:', bucketsError.message);
      return;
    }

    const taskImagesBucket = buckets.find(b => b.name === 'task-images');
    if (taskImagesBucket) {
      console.log('✅ task-images bucket found');
      console.log('   - Public:', taskImagesBucket.public);
      console.log('   - File size limit:', Math.round(taskImagesBucket.file_size_limit / 1024 / 1024) + 'MB');
      console.log('   - Allowed MIME types:', taskImagesBucket.allowed_mime_types);
    } else {
      console.log('❌ task-images bucket not found');
      return;
    }

    // Test 3: Try anonymous upload (should fail with proper error)
    console.log('\n3️⃣ Testing anonymous upload (should fail)...');
    
    const testContent = new Blob(['Test file for anonymous upload'], { type: 'text/plain' });
    const testFileName = `test-anon-${Date.now()}.txt`;
    
    const { data: anonUpload, error: anonError } = await supabaseAnon.storage
      .from('task-images')
      .upload(testFileName, testContent);
    
    if (anonError) {
      console.log('✅ Anonymous upload failed as expected:', anonError.message);
    } else {
      console.log('⚠️  Anonymous upload succeeded (this might be a security issue)');
      // Clean up
      await supabaseAnon.storage.from('task-images').remove([testFileName]);
    }

    // Test 4: Create a test user session and try upload
    console.log('\n4️⃣ Testing authenticated upload...');
    
    // Try to sign in with a test user (you'll need to create one or use existing)
    const testEmail = 'admin@aqura.com'; // Replace with your test user email
    const testPassword = 'password123'; // Replace with your test user password
    
    const { data: signInData, error: signInError } = await supabaseAnon.auth.signInWithPassword({
      email: testEmail,
      password: testPassword
    });
    
    if (signInError) {
      console.log('⚠️  Could not sign in test user:', signInError.message);
      console.log('📝 To test authenticated upload, create a test user in Supabase Auth');
    } else {
      console.log('✅ Test user signed in successfully');
      
      // Try upload with authenticated user
      const authTestContent = new Blob(['Test file for authenticated upload'], { type: 'text/plain' });
      const authTestFileName = `test-auth-${Date.now()}.txt`;
      
      const { data: authUpload, error: authError } = await supabaseAnon.storage
        .from('task-images')
        .upload(authTestFileName, authTestContent);
      
      if (authError) {
        console.log('❌ Authenticated upload failed:', authError.message);
      } else {
        console.log('✅ Authenticated upload succeeded');
        // Clean up
        await supabaseAnon.storage.from('task-images').remove([authTestFileName]);
      }
      
      // Sign out
      await supabaseAnon.auth.signOut();
    }

    // Test 5: Try service role upload (should work)
    console.log('\n5️⃣ Testing service role upload...');
    
    const serviceTestContent = new Blob(['Test file for service role upload'], { type: 'text/plain' });
    const serviceTestFileName = `test-service-${Date.now()}.txt`;
    
    const { data: serviceUpload, error: serviceError } = await supabaseAdmin.storage
      .from('task-images')
      .upload(serviceTestFileName, serviceTestContent);
    
    if (serviceError) {
      console.log('❌ Service role upload failed:', serviceError.message);
    } else {
      console.log('✅ Service role upload succeeded');
      // Clean up
      await supabaseAdmin.storage.from('task-images').remove([serviceTestFileName]);
    }

    console.log('\n🎯 Summary:');
    console.log('- Storage buckets are properly configured');
    console.log('- For frontend uploads to work, users need to be authenticated');
    console.log('- Make sure your app properly signs in users before allowing uploads');

  } catch (error) {
    console.error('❌ Debug failed:', error.message);
  }
}

// Run the debug
debugStorageAuthentication();