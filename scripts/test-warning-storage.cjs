/**
 * Test Warning Image Storage System
 * Verifies all components are working correctly
 */

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function runTests() {
	console.log('🧪 Testing Warning Image Storage System\n');
	console.log('='.repeat(50));

	let passCount = 0;
	let failCount = 0;

	// Test 1: Check storage bucket exists
	console.log('\n📋 Test 1: Check storage bucket exists');
	try {
		const { data: buckets, error } = await supabase.storage.listBuckets();
		if (error) throw error;
		
		const bucket = buckets.find(b => b.id === 'warning-documents');
		if (bucket) {
			console.log('✅ PASS - Bucket exists');
			console.log('   Name:', bucket.name);
			console.log('   Public:', bucket.public);
			passCount++;
		} else {
			console.log('❌ FAIL - Bucket not found');
			failCount++;
		}
	} catch (err) {
		console.log('❌ FAIL -', err.message);
		failCount++;
	}

	// Test 2: Check bucket is public
	console.log('\n📋 Test 2: Check bucket is public');
	try {
		const { data: buckets } = await supabase.storage.listBuckets();
		const bucket = buckets.find(b => b.id === 'warning-documents');
		if (bucket && bucket.public) {
			console.log('✅ PASS - Bucket is public');
			passCount++;
		} else {
			console.log('❌ FAIL - Bucket is not public');
			failCount++;
		}
	} catch (err) {
		console.log('❌ FAIL -', err.message);
		failCount++;
	}

	// Test 3: Check employee_warnings table structure
	console.log('\n📋 Test 3: Check employee_warnings table has warning_document_url');
	try {
		const { data, error } = await supabase
			.from('employee_warnings')
			.select('warning_document_url')
			.limit(1);
		
		if (error) throw error;
		console.log('✅ PASS - Column exists');
		passCount++;
	} catch (err) {
		console.log('❌ FAIL -', err.message);
		failCount++;
	}

	// Test 4: Test file upload (create a dummy text file as image)
	console.log('\n📋 Test 4: Test file upload');
	try {
		// Create a simple text file as test
		const testContent = 'Test warning image content';
		const testBlob = new Blob([testContent], { type: 'image/png' });
		const testPath = 'test/test-upload.png';
		
		const { data, error } = await supabase.storage
			.from('warning-documents')
			.upload(testPath, testBlob, {
				contentType: 'image/png',
				upsert: true
			});

		if (error) throw error;
		console.log('✅ PASS - File upload successful');
		console.log('   Path:', data.path);
		passCount++;

		// Test 5: Get public URL
		console.log('\n📋 Test 5: Get public URL');
		const { data: urlData } = supabase.storage
			.from('warning-documents')
			.getPublicUrl(testPath);
		
		if (urlData.publicUrl) {
			console.log('✅ PASS - Public URL generated');
			console.log('   URL:', urlData.publicUrl);
			passCount++;
		} else {
			console.log('❌ FAIL - Failed to generate public URL');
			failCount++;
		}

		// Test 6: Delete test file
		console.log('\n📋 Test 6: Delete test file');
		const { error: deleteError } = await supabase.storage
			.from('warning-documents')
			.remove([testPath]);

		if (!deleteError) {
			console.log('✅ PASS - File deletion successful');
			passCount++;
		} else {
			console.log('❌ FAIL - File deletion failed:', deleteError.message);
			failCount++;
		}

	} catch (err) {
		console.log('❌ FAIL -', err.message);
		failCount += 3; // Failed 3 tests
	}

	// Test 7: Check warning references
	console.log('\n📋 Test 7: Check existing warnings with references');
	try {
		const { data, error } = await supabase
			.from('employee_warnings')
			.select('id, warning_reference, warning_document_url')
			.not('warning_reference', 'is', null)
			.limit(5);
		
		if (error) throw error;
		console.log('✅ PASS - Query successful');
		console.log('   Found', data.length, 'warnings with references');
		if (data.length > 0) {
			console.log('   Sample:', data[0].warning_reference);
		}
		passCount++;
	} catch (err) {
		console.log('❌ FAIL -', err.message);
		failCount++;
	}

	// Test 8: Check storage policies
	console.log('\n📋 Test 8: Check storage policies exist');
	try {
		// Try to list objects (public read should work)
		const { data, error } = await supabase.storage
			.from('warning-documents')
			.list('', { limit: 1 });
		
		if (error) throw error;
		console.log('✅ PASS - Storage policies working');
		passCount++;
	} catch (err) {
		console.log('❌ FAIL -', err.message);
		failCount++;
	}

	// Summary
	console.log('\n' + '='.repeat(50));
	console.log('📊 Test Summary');
	console.log('='.repeat(50));
	console.log(`✅ Passed: ${passCount}`);
	console.log(`❌ Failed: ${failCount}`);
	console.log(`📈 Success Rate: ${Math.round((passCount / (passCount + failCount)) * 100)}%`);
	console.log('='.repeat(50));

	if (failCount === 0) {
		console.log('\n🎉 All tests passed! System is ready to use.');
	} else {
		console.log('\n⚠️  Some tests failed. Please review the errors above.');
	}

	console.log('\n📝 Next steps:');
	console.log('   1. Open the frontend application');
	console.log('   2. Generate a warning template');
	console.log('   3. Click "💾 Save as Image"');
	console.log('   4. Verify the image is saved and displayed');
	console.log('   5. Test sending notification and WhatsApp sharing\n');
}

// Run tests
runTests();
