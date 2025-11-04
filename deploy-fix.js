import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcyNzM3ODQ4NiwiZXhwIjoyMDQyOTU0NDg2fQ.lEOzQyEAQ3CvhST4fJfD5xgNJNMO2YoKJHGH2pP1aFw';

const supabase = createClient(supabaseUrl, supabaseKey);

async function deployFunction() {
  console.log('🚀 Deploying updated function...');
  
  const sql = `
-- =====================================================
-- SIMPLE PURCHASE MANAGER COMPLETION FIX
-- =====================================================

CREATE OR REPLACE FUNCTION complete_receiving_task_simple(
  receiving_task_id_param UUID,
  user_id_param UUID,
  completion_photo_url_param TEXT DEFAULT NULL,
  completion_notes_param TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  v_task RECORD;
  v_receiving_record RECORD;
  v_result JSONB;
BEGIN
  -- Get task details
  SELECT * INTO v_task
  FROM receiving_tasks
  WHERE id = receiving_task_id_param
    AND assigned_user_id = user_id_param;
  
  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Task not found or not assigned to user',
      'error_code', 'TASK_NOT_FOUND'
    );
  END IF;
  
  -- Check if task is already completed
  IF v_task.task_completed THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Task is already completed',
      'error_code', 'TASK_ALREADY_COMPLETED'
    );
  END IF;
  
  -- Get receiving record
  SELECT * INTO v_receiving_record
  FROM receiving_records
  WHERE id = v_task.receiving_record_id;
  
  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Receiving record not found',
      'error_code', 'RECEIVING_RECORD_NOT_FOUND'
    );
  END IF;

  -- Simplified role-specific validations (no payment schedule checks!)
  IF v_task.role_type = 'inventory_manager' THEN
    -- Check inventory manager requirements
    IF NOT v_receiving_record.erp_purchase_invoice_uploaded THEN
      RETURN json_build_object(
        'success', false,
        'error', 'ERP purchase invoice not uploaded',
        'error_code', 'ERP_INVOICE_REQUIRED'
      );
    END IF;
    
    IF NOT v_receiving_record.pr_excel_file_uploaded THEN
      RETURN json_build_object(
        'success', false,
        'error', 'PR Excel file not uploaded',
        'error_code', 'PR_EXCEL_REQUIRED'
      );
    END IF;
    
    IF NOT v_receiving_record.original_bill_uploaded THEN
      RETURN json_build_object(
        'success', false,
        'error', 'Original bill not uploaded',
        'error_code', 'ORIGINAL_BILL_REQUIRED'
      );
    END IF;
    
  ELSIF v_task.role_type = 'purchase_manager' THEN
    -- Purchase manager ONLY needs PR Excel uploaded by inventory manager
    -- NO payment schedule validation needed!
    IF NOT v_receiving_record.pr_excel_file_uploaded THEN
      RETURN json_build_object(
        'success', false,
        'error', 'PR Excel file not uploaded by inventory manager',
        'error_code', 'PR_EXCEL_REQUIRED'
      );
    END IF;
    
    -- That's it! No other validations needed for purchase managers
    
  ELSIF v_task.role_type = 'accountant' THEN
    -- Check accountant dependency on inventory manager original bill upload
    IF NOT v_receiving_record.original_bill_uploaded OR v_receiving_record.original_bill_url IS NULL THEN
      RETURN json_build_object(
        'success', false,
        'error', 'Original bill not uploaded by the inventory manager – please follow up.',
        'error_code', 'DEPENDENCIES_NOT_MET'
      );
    END IF;
  END IF;

  -- Update the task as completed (update BOTH fields)
  UPDATE receiving_tasks
  SET 
    task_completed = true,
    assignment_status = 'completed',
    completed_at = CURRENT_TIMESTAMP,
    completion_photo_url = completion_photo_url_param,
    completion_notes = completion_notes_param
  WHERE id = receiving_task_id_param;
  
  -- Return success
  v_result := json_build_object(
    'success', true,
    'message', 'Task completed successfully',
    'task_id', receiving_task_id_param,
    'role_type', v_task.role_type,
    'completed_at', CURRENT_TIMESTAMP
  );
  
  RETURN v_result;
  
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object(
    'success', false,
    'error', SQLERRM,
    'error_code', 'INTERNAL_ERROR'
  );
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT EXECUTE ON FUNCTION complete_receiving_task_simple TO authenticated;
GRANT EXECUTE ON FUNCTION complete_receiving_task_simple TO service_role;
  `;
  
  try {
    const { data, error } = await supabase.rpc('exec_sql', { sql });
    
    if (error) {
      console.error('❌ Error deploying function:', error);
      return;
    }
    
    console.log('✅ Function deployed successfully');
    
    // Now fix existing completed tasks
    console.log('🔧 Fixing existing completed tasks...');
    
    const fixSql = `
      UPDATE receiving_tasks 
      SET assignment_status = 'completed' 
      WHERE task_completed = true AND assignment_status != 'completed';
    `;
    
    const { data: fixData, error: fixError } = await supabase.rpc('exec_sql', { sql: fixSql });
    
    if (fixError) {
      console.error('❌ Error fixing existing tasks:', fixError);
      return;
    }
    
    console.log('✅ Existing completed tasks fixed!');
    
  } catch (err) {
    console.error('❌ Deployment failed:', err);
  }
}

deployFunction();