import { json } from '@sveltejs/kit';
import { supabase } from '$lib/utils/supabase';

export async function POST({ request }) {
	try {
		const requestData = await request.json();
		console.log('🔥 [API] Received completion request:', requestData);
		
		const { 
			receiving_task_id, 
			user_id,
			erp_reference,
			original_bill_file_path,
			has_erp_purchase_invoice = false,
			has_pr_excel_file = false,
			has_original_bill = false
		} = requestData;

		// Validate required fields
		if (!receiving_task_id) {
			console.log('❌ [API] Missing receiving_task_id');
			return json({ error: 'Receiving task ID is required' }, { status: 400 });
		}

		if (!user_id) {
			console.log('❌ [API] Missing user_id');
			return json({ error: 'User ID is required' }, { status: 400 });
		}

		console.log('🔍 [API] Looking for task:', receiving_task_id);

		// Get task details to check role type and requirements
		const { data: taskData, error: taskError } = await supabase
			.from('receiving_tasks')
			.select('role_type, requires_erp_reference, requires_original_bill_upload')
			.eq('id', receiving_task_id)
			.single();

		console.log('📊 [API] Task query result:', { data: taskData, error: taskError });

		if (taskError || !taskData) {
			console.log('❌ [API] Task not found:', taskError);
			return json({ error: 'Task not found' }, { status: 404 });
		}

		// Special validation for Inventory Manager
		if (taskData.role_type === 'inventory_manager') {
			console.log('📦 [API] Validating Inventory Manager requirements...');
			if (!has_erp_purchase_invoice) {
				console.log('❌ [API] Missing ERP purchase invoice');
				return json({ 
					error: 'ERP Purchase Invoice Reference is required for Inventory Manager tasks' 
				}, { status: 400 });
			}
			if (!has_pr_excel_file) {
				console.log('❌ [API] Missing PR Excel file');
				return json({ 
					error: 'PR Excel file is required for Inventory Manager tasks' 
				}, { status: 400 });
			}
			if (!has_original_bill) {
				console.log('❌ [API] Missing original bill');
				return json({ 
					error: 'Original bill upload is required for Inventory Manager tasks' 
				}, { status: 400 });
			}
		}

		// Special handling for Purchase Manager
		if (taskData.role_type === 'purchase_manager') {
			console.log('💰 [API] Processing Purchase Manager task completion...');
			// Purchase manager validations are handled in the database function
			// No additional client-side validation needed as it requires database queries
		}

		console.log('🚀 [API] Calling complete_receiving_task function...');

		// Call the database function to complete the receiving task
		const { data, error } = await supabase.rpc('complete_receiving_task', {
			receiving_task_id_param: receiving_task_id,
			user_id_param: user_id,
			erp_reference_param: erp_reference || null,
			original_bill_file_path_param: original_bill_file_path || null,
			has_erp_purchase_invoice: has_erp_purchase_invoice,
			has_pr_excel_file: has_pr_excel_file,
			has_original_bill: has_original_bill
		});

		console.log('📊 [API] Database function result:', { data, error });

		if (error) {
			console.error('Database error completing receiving task:', error);
			return json({ 
				error: 'Failed to complete receiving task: ' + error.message 
			}, { status: 500 });
		}

		// Check if the response indicates success
		if (data && !data.success) {
			// Handle specific error codes for better user experience
			let errorMessage = data.error || 'Unknown error occurred';
			
			// Purchase Manager specific error handling
			if (data.error_code === 'PR_EXCEL_NOT_UPLOADED') {
				console.log('❌ [API] Purchase Manager: PR Excel not uploaded');
				errorMessage = 'PR Excel not uploaded';
			} else if (data.error_code === 'VERIFICATION_NOT_FINISHED') {
				console.log('❌ [API] Purchase Manager: Verification not finished');
				errorMessage = 'Verification not finished';
			}
			
			return json({ 
				error: errorMessage,
				error_code: data.error_code
			}, { status: 400 });
		}

		return json({ 
			success: true,
			data: data,
			message: 'Task completed successfully'
		});

	} catch (error) {
		console.error('Error completing receiving task:', error);
		return json({ 
			error: 'Internal server error: ' + error.message 
		}, { status: 500 });
	}
}

export async function GET({ url }) {
	try {
		const receiving_task_id = url.searchParams.get('receiving_task_id');
		const user_id = url.searchParams.get('user_id');

		if (!receiving_task_id || !user_id) {
			return json({ 
				error: 'Both receiving_task_id and user_id are required' 
			}, { status: 400 });
		}

		// Call the database function to validate completion requirements
		const { data, error } = await supabase.rpc('validate_task_completion_requirements', {
			receiving_task_id_param: receiving_task_id,
			user_id_param: user_id
		});

		if (error) {
			console.error('Database error validating task completion:', error);
			return json({ 
				error: 'Failed to validate task completion requirements: ' + error.message 
			}, { status: 500 });
		}

		return json({ 
			success: true,
			validation: data
		});

	} catch (error) {
		console.error('Error validating task completion:', error);
		return json({ 
			error: 'Internal server error: ' + error.message 
		}, { status: 500 });
	}
}