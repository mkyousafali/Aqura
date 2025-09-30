// Simple test to check frontend authentication and storage upload
// Add this to your browser console when logged into your app

console.log('🧪 Testing frontend storage upload...');

// Test 1: Check authentication state
console.log('\n1️⃣ Checking authentication...');
const { data: { user } } = await window.supabase.auth.getUser();
if (user) {
  console.log('✅ User is authenticated:', user.email);
  console.log('   User ID:', user.id);
} else {
  console.log('❌ User is not authenticated');
}

// Test 2: Check storage access
console.log('\n2️⃣ Testing storage access...');
try {
  const { data: buckets, error } = await window.supabase.storage.listBuckets();
  if (error) {
    console.log('❌ Cannot list buckets:', error.message);
  } else {
    console.log('✅ Can access storage');
    console.log('   Available buckets:', buckets.map(b => b.name));
  }
} catch (e) {
  console.log('❌ Storage access failed:', e.message);
}

// Test 3: Create a simple test image and try upload
console.log('\n3️⃣ Testing image upload...');

// Create a simple 1x1 pixel PNG
const canvas = document.createElement('canvas');
canvas.width = 1;
canvas.height = 1;
const ctx = canvas.getContext('2d');
ctx.fillStyle = '#FF0000';
ctx.fillRect(0, 0, 1, 1);

canvas.toBlob(async (blob) => {
  const testFile = new File([blob], 'test-image.png', { type: 'image/png' });
  console.log('   Created test file:', testFile.name, testFile.type, testFile.size, 'bytes');
  
  try {
    const { data, error } = await window.supabase.storage
      .from('task-images')
      .upload(`test-${Date.now()}.png`, testFile);
    
    if (error) {
      console.log('❌ Upload failed:', error.message);
      console.log('   Error details:', error);
    } else {
      console.log('✅ Upload succeeded:', data);
      
      // Clean up - remove the test file
      await window.supabase.storage.from('task-images').remove([data.path]);
      console.log('🧹 Test file cleaned up');
    }
  } catch (e) {
    console.log('❌ Upload exception:', e.message);
  }
}, 'image/png');

console.log('\n📋 Instructions:');
console.log('1. Open your app in the browser');
console.log('2. Make sure you are logged in');
console.log('3. Open the browser console (F12)');
console.log('4. Copy and paste this entire script');
console.log('5. Press Enter to run the test');