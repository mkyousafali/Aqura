import { json } from '@sveltejs/kit';
import { supabase } from '$lib/utils/supabase';

export async function POST({ request }) {
	try {
		const { 
			receiving_task_id, 
			user_id,
			erp_reference,
			original_bill_file_path
		} = await request.json();

		// Validate required fields
		if (!receiving_task_id) {
			return json({ error: 'Receiving task ID is required' }, { status: 400 });
		}

		if (!user_id) {
			return json({ error: 'User ID is required' }, { status: 400 });
		}

		// Call the database function to complete the receiving task
		const { data, error } = await supabase.rpc('complete_receiving_task', {
			receiving_task_id_param: receiving_task_id,
			user_id_param: user_id,
			erp_reference_param: erp_reference || null,
			original_bill_file_path_param: original_bill_file_path || null
		});

		if (error) {
			console.error('Database error completing receiving task:', error);
			return json({ 
				error: 'Failed to complete receiving task: ' + error.message 
			}, { status: 500 });
		}

		// Check if the response indicates success
		if (data && !data.success) {
			return json({ 
				error: data.error || 'Unknown error occurred',
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