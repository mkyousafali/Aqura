const { Client } = require('pg');

// Using your existing database connection
const client = new Client({ 
  connectionString: 'postgresql://postgres:%40%23Imanihayath120@db.vmypotfsyrvuublyddyt.supabase.co:5432/postgres' 
});

async function createStorageBucketsSQL() {
  try {
    console.log('🚀 Creating storage buckets using direct SQL...');
    await client.connect();

    // SQL to create storage buckets directly
    const createBucketsSQL = `
      -- Create task-images bucket
      INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types, created_at, updated_at)
      VALUES (
        'task-images',
        'task-images', 
        false,
        5242880, -- 5MB
        ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp'],
        NOW(),
        NOW()
      ) ON CONFLICT (id) DO NOTHING;

      -- Create completion-photos bucket
      INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types, created_at, updated_at)
      VALUES (
        'completion-photos',
        'completion-photos',
        false,
        5242880, -- 5MB
        ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp'],
        NOW(),
        NOW()
      ) ON CONFLICT (id) DO NOTHING;

      -- Create documents bucket
      INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types, created_at, updated_at)
      VALUES (
        'documents',
        'documents',
        false,
        10485760, -- 10MB
        ARRAY['application/pdf', 'image/jpeg', 'image/png', 'application/msword', 
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'text/plain'],
        NOW(),
        NOW()
      ) ON CONFLICT (id) DO NOTHING;
    `;

    console.log('📁 Creating storage buckets...');
    await client.query(createBucketsSQL);
    console.log('✅ Storage buckets created successfully!');

    // Enable RLS on storage.objects if not already enabled
    console.log('🔐 Enabling Row Level Security...');
    try {
      await client.query('ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;');
      console.log('✅ RLS enabled on storage.objects');
    } catch (rlsError) {
      if (rlsError.message.includes('already enabled')) {
        console.log('✅ RLS was already enabled on storage.objects');
      } else {
        console.log('⚠️  RLS may already be enabled:', rlsError.message);
      }
    }

    // Create storage policies
    console.log('📋 Creating storage policies...');
    
    const policies = [
      // task-images policies
      `DROP POLICY IF EXISTS "task_images_authenticated_insert" ON storage.objects;
       CREATE POLICY "task_images_authenticated_insert" ON storage.objects 
       FOR INSERT TO authenticated WITH CHECK (bucket_id = 'task-images');`,
       
      `DROP POLICY IF EXISTS "task_images_authenticated_select" ON storage.objects;
       CREATE POLICY "task_images_authenticated_select" ON storage.objects 
       FOR SELECT TO authenticated USING (bucket_id = 'task-images');`,
       
      `DROP POLICY IF EXISTS "task_images_authenticated_update" ON storage.objects;
       CREATE POLICY "task_images_authenticated_update" ON storage.objects 
       FOR UPDATE TO authenticated USING (bucket_id = 'task-images');`,
       
      `DROP POLICY IF EXISTS "task_images_authenticated_delete" ON storage.objects;
       CREATE POLICY "task_images_authenticated_delete" ON storage.objects 
       FOR DELETE TO authenticated USING (bucket_id = 'task-images');`,

      // completion-photos policies
      `DROP POLICY IF EXISTS "completion_photos_authenticated_insert" ON storage.objects;
       CREATE POLICY "completion_photos_authenticated_insert" ON storage.objects 
       FOR INSERT TO authenticated WITH CHECK (bucket_id = 'completion-photos');`,
       
      `DROP POLICY IF EXISTS "completion_photos_authenticated_select" ON storage.objects;
       CREATE POLICY "completion_photos_authenticated_select" ON storage.objects 
       FOR SELECT TO authenticated USING (bucket_id = 'completion-photos');`,
       
      `DROP POLICY IF EXISTS "completion_photos_authenticated_update" ON storage.objects;
       CREATE POLICY "completion_photos_authenticated_update" ON storage.objects 
       FOR UPDATE TO authenticated USING (bucket_id = 'completion-photos');`,
       
      `DROP POLICY IF EXISTS "completion_photos_authenticated_delete" ON storage.objects;
       CREATE POLICY "completion_photos_authenticated_delete" ON storage.objects 
       FOR DELETE TO authenticated USING (bucket_id = 'completion-photos');`,

      // documents policies
      `DROP POLICY IF EXISTS "documents_authenticated_insert" ON storage.objects;
       CREATE POLICY "documents_authenticated_insert" ON storage.objects 
       FOR INSERT TO authenticated WITH CHECK (bucket_id = 'documents');`,
       
      `DROP POLICY IF EXISTS "documents_authenticated_select" ON storage.objects;
       CREATE POLICY "documents_authenticated_select" ON storage.objects 
       FOR SELECT TO authenticated USING (bucket_id = 'documents');`,
       
      `DROP POLICY IF EXISTS "documents_authenticated_update" ON storage.objects;
       CREATE POLICY "documents_authenticated_update" ON storage.objects 
       FOR UPDATE TO authenticated USING (bucket_id = 'documents');`,
       
      `DROP POLICY IF EXISTS "documents_authenticated_delete" ON storage.objects;
       CREATE POLICY "documents_authenticated_delete" ON storage.objects 
       FOR DELETE TO authenticated USING (bucket_id = 'documents');`
    ];

    for (let i = 0; i < policies.length; i++) {
      try {
        await client.query(policies[i]);
        console.log(`✅ Policy ${i + 1} applied successfully`);
      } catch (policyError) {
        console.log(`⚠️  Policy ${i + 1} may already exist:`, policyError.message);
      }
    }

    // Verify buckets were created
    console.log('\n📋 Verifying created buckets...');
    const { rows } = await client.query(`
      SELECT id, name, public, file_size_limit, allowed_mime_types, created_at
      FROM storage.buckets
      WHERE id IN ('task-images', 'completion-photos', 'documents')
      ORDER BY created_at;
    `);

    console.log('\n📁 Created storage buckets:');
    rows.forEach(bucket => {
      console.log(`  ✅ ${bucket.name} (${bucket.public ? 'public' : 'private'}, ${Math.round(bucket.file_size_limit / 1024 / 1024)}MB limit)`);
    });

    console.log('\n🎉 Storage buckets and policies setup completed successfully!');
    console.log('📝 You can now upload images and documents to your tasks.');

  } catch (error) {
    console.error('❌ Error setting up storage buckets:', error.message);
    
    if (error.message.includes('permission denied')) {
      console.log('\n📋 Alternative: Create buckets manually in Supabase dashboard:');
      console.log('1. Go to: https://supabase.com/dashboard/project/vmypotfsyrvuublyddyt');
      console.log('2. Navigate to Storage');
      console.log('3. Create these buckets: task-images, completion-photos, documents');
    }
  } finally {
    await client.end();
  }
}

// Run the setup
createStorageBucketsSQL();