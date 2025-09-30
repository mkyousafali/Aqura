const { createClient } = require('@supabase/supabase-js');

// Supabase configuration
const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcyNzY5NjQwNCwiZXhwIjoyMDQzMjcyNDA0fQ.L5u2zc6ca6ed1334314e1f5aecf7ac2bbec4be4f6ea2e0c6daa4b8934';

// Create Supabase client with service role
const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function setupStorageBucket() {
  console.log('🚀 Setting up completion-photos storage bucket...');

  try {
    // Create completion-photos bucket
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
      return false;
    } else {
      console.log('✅ completion-photos bucket ready');
    }

    // Set up storage policies
    console.log('🔐 Setting up storage policies...');
    
    // Note: Storage policies need to be set up manually in Supabase dashboard
    // or using the SQL editor with proper RLS policies
    
    console.log('\n🎉 Storage bucket setup completed!');
    console.log('\n📋 Next steps:');
    console.log('  1. ✅ Storage bucket is ready');
    console.log('  2. 📋 Run the SQL file manually in Supabase SQL editor:');
    console.log('     - Open Supabase Dashboard');
    console.log('     - Go to SQL Editor');
    console.log('     - Copy and paste add-completion-photo-url-column.sql');
    console.log('     - Execute the SQL');
    console.log('\n🚀 After running the SQL, your task completion system will be ready!');

    return true;

  } catch (error) {
    console.error('❌ Unexpected error:', error);
    return false;
  }
}

// Main execution
setupStorageBucket().catch(console.error);