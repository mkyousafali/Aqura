// =====================================================
// UPDATE FRONTEND FOR ACCOUNTANT DEPENDENCY
// =====================================================
// This updates the mobile and desktop interfaces to show
// the dependency message when accountant tries to complete
// task without inventory manager uploading original bill
// =====================================================

// 1. UPDATE MOBILE INTERFACE
// File: frontend/src/routes/mobile/receiving-tasks/[id]/complete/+page.svelte

// Add this function after checkTaskDependencies():

async function checkAccountantDependency() {
    if (taskDetails?.role_type !== 'accountant') return;
    
    try {
        // Check if inventory manager uploaded original bill
        const { data: receivingRecord, error: recordError } = await supabase
            .from('receiving_records')
            .select('original_bill_uploaded, original_bill_url')
            .eq('id', taskDetails.receiving_record_id)
            .single();

        if (recordError) {
            console.error('Error checking receiving record:', recordError);
            return;
        }

        // Check if inventory manager task is completed
        const { data: inventoryTask, error: inventoryError } = await supabase
            .from('receiving_tasks')
            .select('task_completed, completed_at')
            .eq('receiving_record_id', taskDetails.receiving_record_id)
            .eq('role_type', 'inventory_manager')
            .single();

        if (inventoryError || !inventoryTask?.task_completed) {
            canComplete = false;
            blockingRoles = ['Inventory Manager must complete their task first'];
            return;
        }

        // Check original bill upload status
        if (!receivingRecord.original_bill_uploaded || !receivingRecord.original_bill_url) {
            canComplete = false;
            errorMessage = 'Original bill not uploaded by the inventory manager – please follow up.';
            blockingRoles = ['Original bill upload required from Inventory Manager'];
            return;
        }

        // All good, accountant can proceed
        canComplete = true;
        blockingRoles = [];
        errorMessage = '';
        
    } catch (error) {
        console.error('Error checking accountant dependency:', error);
        canComplete = false;
        errorMessage = 'Error checking dependencies. Please try again.';
    }
}

// 2. UPDATE DESKTOP INTERFACE  
// File: frontend/src/lib/components/admin/receiving/ReceivingTaskCompletionDialog.svelte

// Add this function:

async function checkAccountantDependency() {
    if (taskDetails?.role_type !== 'accountant') return;
    
    try {
        // Check receiving record for original bill status
        const { data: receivingRecord, error } = await supabase
            .from('receiving_records')
            .select('original_bill_uploaded, original_bill_url')
            .eq('id', receivingRecordId)
            .single();

        if (error) {
            console.error('Error checking receiving record:', error);
            return;
        }

        // Check inventory manager task completion
        const { data: inventoryTask, error: inventoryError } = await supabase
            .from('receiving_tasks')
            .select('task_completed, completed_at')
            .eq('receiving_record_id', receivingRecordId)
            .eq('role_type', 'inventory_manager')
            .single();

        if (inventoryError || !inventoryTask?.task_completed) {
            canComplete = false;
            blockingRoles = ['inventory_manager'];
            return;
        }

        if (!receivingRecord.original_bill_uploaded || !receivingRecord.original_bill_url) {
            canComplete = false;
            error = 'Original bill not uploaded by the inventory manager – please follow up.';
            return;
        }

        canComplete = true;
        error = null;
        
    } catch (err) {
        console.error('Error checking accountant dependency:', err);
        canComplete = false;
        error = 'Error checking dependencies.';
    }
}

// 3. UPDATE API ENDPOINT
// File: frontend/src/routes/api/receiving-tasks/complete/+server.js

// Add this validation before calling the database function:

if (taskData.role_type === 'accountant') {
    console.log('🧾 [API] Validating Accountant dependencies...');
    
    // Check if inventory manager has uploaded original bill
    const { data: receivingRecord, error: recordError } = await supabase
        .from('receiving_records')
        .select('original_bill_uploaded, original_bill_url')
        .eq('id', taskData.receiving_record_id)
        .single();

    if (recordError) {
        console.log('❌ [API] Error checking receiving record:', recordError);
        return json({ 
            error: 'Error checking dependencies' 
        }, { status: 500 });
    }

    if (!receivingRecord.original_bill_uploaded || !receivingRecord.original_bill_url) {
        console.log('❌ [API] Original bill not uploaded by inventory manager');
        return json({ 
            error: 'Original bill not uploaded by the inventory manager – please follow up.',
            error_code: 'ORIGINAL_BILL_NOT_UPLOADED'
        }, { status: 400 });
    }
}

// 4. UPDATE DASHBOARD
// File: frontend/src/lib/components/admin/receiving/ReceivingTasksDashboard.svelte

// Add this to the completeTask function for accountant:

if (task.role_type === 'accountant') {
    // Check dependency first
    const { data: receivingRecord } = await supabase
        .from('receiving_records')
        .select('original_bill_uploaded, original_bill_url')
        .eq('id', task.receiving_record_id)
        .single();

    if (!receivingRecord?.original_bill_uploaded || !receivingRecord?.original_bill_url) {
        alert('Original bill not uploaded by the inventory manager – please follow up.');
        return;
    }
}

console.log('✅ Frontend update instructions:');
console.log('1. Add checkAccountantDependency() function to mobile interface');
console.log('2. Add dependency check to desktop completion dialog');
console.log('3. Update API endpoint with accountant validation');
console.log('4. Update dashboard with dependency check');
console.log('5. Call checkAccountantDependency() in onMount and before submission');
console.log('');
console.log('The user will see: "Original bill not uploaded by the inventory manager – please follow up."');