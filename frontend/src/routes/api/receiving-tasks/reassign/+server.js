import { json } from '@sveltejs/kit';
import { supabase } from '$lib/utils/supabase';

export async function POST({ request }) {
	try {
		const { 
			receiving_task_id, 
			new_assigned_user_id,
			reassigned_by_user_id,
			reassignment_reason 
		} = await request.json();

		// Validate required fields
		if (!receiving_task_id) {
			return json({ error: 'Receiving task ID is required' }, { status: 400 });
		}

		if (!new_assigned_user_id) {
			return json({ error: 'New assigned user ID is required' }, { status: 400 });
		}

		if (!reassigned_by_user_id) {
			return json({ error: 'Reassigned by user ID is required' }, { status: 400 });
		}

		// Call the database function to reassign the receiving task
		const { data, error } = await supabase.rpc('reassign_receiving_task', {
			receiving_task_id_param: receiving_task_id,
			new_assigned_user_id: new_assigned_user_id,
			reassigned_by_user_id: reassigned_by_user_id,
			reassignment_reason: reassignment_reason || null
		});

		if (error) {
			console.error('Database error reassigning receiving task:', error);
			return json({ 
				error: 'Failed to reassign receiving task: ' + error.message 
			}, { status: 500 });
		}

		// Check if the response indicates success
		if (data && !data.success) {
			return json({ 
				error: data.error || 'Unknown error occurred'
			}, { status: 400 });
		}

		return json({ 
			success: true,
			data: data,
			message: 'Task successfully reassigned'
		});

	} catch (error) {
		console.error('Error reassigning receiving task:', error);
		return json({ 
			error: 'Internal server error: ' + error.message 
		}, { status: 500 });
	}
}