// Test the simple test-queue function
const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

async function testQueue() {
    console.log('🧪 Testing test-queue Edge Function...\n');
    
    try {
        const response = await fetch(`${SUPABASE_URL}/functions/v1/test-queue`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({})
        });
        
        const result = await response.json();
        console.log('📡 Response:', JSON.stringify(result, null, 2));
        console.log('Status:', response.status, response.statusText);
    } catch (error) {
        console.error('❌ Error:', error.message);
    }
}

testQueue();
