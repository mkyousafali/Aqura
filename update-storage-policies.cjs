const { Client } = require('pg');

const client = new Client({
    connectionString: 'postgresql://postgres:%40%23Imanihayath120@db.vmypotfsyrvuublyddyt.supabase.co:5432/postgres'
});

async function updateStoragePolicies() {
    try {
        await client.connect();
        console.log('Connected to database');

        // Drop existing restrictive policies
        console.log('Dropping existing storage policies...');
        
        await client.query(`
            DROP POLICY IF EXISTS "task_images_policy" ON storage.objects;
        `);
        
        await client.query(`
            DROP POLICY IF EXISTS "completion_photos_policy" ON storage.objects;
        `);
        
        await client.query(`
            DROP POLICY IF EXISTS "documents_policy" ON storage.objects;
        `);

        // Create more permissive policies that allow uploads for any authenticated user
        console.log('Creating new permissive storage policies...');
        
        // Policy for task-images bucket - allow authenticated users to upload
        await client.query(`
            CREATE POLICY "task_images_upload_policy" ON storage.objects 
            FOR INSERT 
            WITH CHECK (
                bucket_id = 'task-images' 
                AND auth.uid() IS NOT NULL
            );
        `);

        // Policy for task-images bucket - allow authenticated users to view
        await client.query(`
            CREATE POLICY "task_images_select_policy" ON storage.objects 
            FOR SELECT 
            USING (
                bucket_id = 'task-images' 
                AND auth.uid() IS NOT NULL
            );
        `);

        // Policy for completion-photos bucket - allow authenticated users to upload
        await client.query(`
            CREATE POLICY "completion_photos_upload_policy" ON storage.objects 
            FOR INSERT 
            WITH CHECK (
                bucket_id = 'completion-photos' 
                AND auth.uid() IS NOT NULL
            );
        `);

        // Policy for completion-photos bucket - allow authenticated users to view
        await client.query(`
            CREATE POLICY "completion_photos_select_policy" ON storage.objects 
            FOR SELECT 
            USING (
                bucket_id = 'completion-photos' 
                AND auth.uid() IS NOT NULL
            );
        `);

        // Policy for documents bucket - allow authenticated users to upload
        await client.query(`
            CREATE POLICY "documents_upload_policy" ON storage.objects 
            FOR INSERT 
            WITH CHECK (
                bucket_id = 'documents' 
                AND auth.uid() IS NOT NULL
            );
        `);

        // Policy for documents bucket - allow authenticated users to view
        await client.query(`
            CREATE POLICY "documents_select_policy" ON storage.objects 
            FOR SELECT 
            USING (
                bucket_id = 'documents' 
                AND auth.uid() IS NOT NULL
            );
        `);

        console.log('✅ Storage policies updated successfully!');
        console.log('');
        console.log('Note: These policies still require Supabase authentication.');
        console.log('If you continue to have issues, we may need to disable RLS temporarily');
        console.log('or create a service role key-based solution.');

    } catch (error) {
        console.error('❌ Error updating storage policies:', error.message);
        console.log('');
        console.log('If this fails, we may need to use the Supabase dashboard to update policies.');
    } finally {
        await client.end();
    }
}

updateStoragePolicies();