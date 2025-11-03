// Reset approval request for a specific vendor payment
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

const paymentId = '1970993f-055e-4090-ae17-9dc5b64482d3';

async function resetApprovalRequest() {
  console.log('🔄 Resetting approval request for payment:', paymentId);
  
  try {
    // Reset the approval fields
    const { data, error } = await supabase
      .from('vendor_payment_schedule')
      .update({
        approval_status: 'pending',
        approval_requested_by: null,
        approval_requested_at: null,
        approved_by: null,
        approved_at: null,
        approval_notes: null,
        updated_at: new Date().toISOString()
      })
      .eq('id', paymentId)
      .select();

    if (error) {
      console.error('❌ Error resetting approval request:', error);
      return;
    }

    console.log('✅ Approval request reset successfully!');
    console.log('📋 Updated payment:', data);
    
  } catch (err) {
    console.error('❌ Unexpected error:', err);
  }
}

resetApprovalRequest();
