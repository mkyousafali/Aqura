/**
 * Create Warning Documents Storage Bucket
 * Simple script to create the storage bucket via Supabase API
 */

const { createClient } = require('@supabase/supabase-js');

// Supabase credentials (hardcoded for simplicity)
const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

if (!supabaseUrl || !supabaseServiceKey) {
	console.error('❌ Missing Supabase credentials in .env file');
	process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey, {
	auth: {
		autoRefreshToken: false,
		persistSession: false
	}
});

async function createStorageBucket() {
	console.log('🚀 Creating warning-documents storage bucket...\n');

	try {
		// Check if bucket already exists
		console.log('🔍 Checking existing buckets...');
		const { data: buckets, error: listError } = await supabase.storage.listBuckets();
		
		if (listError) {
			console.error('❌ Error listing buckets:', listError.message);
			throw listError;
		}

		const existingBucket = buckets.find(b => b.id === 'warning-documents');
		
		if (existingBucket) {
			console.log('✅ Bucket "warning-documents" already exists!');
			console.log('   ID:', existingBucket.id);
			console.log('   Name:', existingBucket.name);
			console.log('   Public:', existingBucket.public);
			console.log('   Created:', existingBucket.created_at);
			return;
		}

		// Create new bucket
		console.log('📦 Creating new bucket...');
		const { data, error } = await supabase.storage.createBucket('warning-documents', {
			public: true,
			fileSizeLimit: 5242880, // 5MB
			allowedMimeTypes: ['image/png', 'image/jpeg', 'image/jpg', 'image/webp']
		});

		if (error) {
			console.error('❌ Error creating bucket:', error.message);
			throw error;
		}

		console.log('✅ Bucket created successfully!');
		console.log('   Bucket ID:', data?.name || 'warning-documents');

		// Verify creation
		console.log('\n🔍 Verifying bucket creation...');
		const { data: verifyBuckets } = await supabase.storage.listBuckets();
		const newBucket = verifyBuckets.find(b => b.id === 'warning-documents');
		
		if (newBucket) {
			console.log('✅ Verification successful!');
			console.log('   Public URL base:', `${supabaseUrl}/storage/v1/object/public/warning-documents/`);
		}

		console.log('\n🎉 Storage bucket setup complete!');
		console.log('\n📝 Next steps:');
		console.log('   1. Test uploading an image');
		console.log('   2. Verify public access works');
		console.log('   3. Check storage policies in Supabase Dashboard\n');

	} catch (error) {
		console.error('\n❌ Setup failed:', error.message);
		console.log('\n💡 Manual setup instructions:');
		console.log('   1. Go to Supabase Dashboard → Storage');
		console.log('   2. Create new bucket: "warning-documents"');
		console.log('   3. Make it public');
		console.log('   4. Set file size limit: 5MB');
		console.log('   5. Allowed MIME types: image/png, image/jpeg, image/jpg, image/webp');
		process.exit(1);
	}
}

// Run setup
createStorageBucket();
