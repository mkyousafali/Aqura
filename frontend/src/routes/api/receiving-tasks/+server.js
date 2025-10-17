import { json } from '@sveltejs/kit';
import { supabase } from '$lib/utils/supabase';

export async function POST({ request }) {
	try {
		const { 
			receiving_record_id, 
			clearance_certificate_url, 
			generated_by_user_id,
			generated_by_name,
			generated_by_role 
		} = await request.json();

		// Validate required fields
		if (!receiving_record_id) {
			return json({ error: 'Receiving record ID is required' }, { status: 400 });
		}

		if (!clearance_certificate_url) {
			return json({ error: 'Clearance certificate URL is required' }, { status: 400 });
		}

		if (!generated_by_user_id) {
			return json({ error: 'User ID is required' }, { status: 400 });
		}

		// Call the database function to process clearance certificate generation
		const { data, error } = await supabase.rpc('process_clearance_certificate_generation', {
			receiving_record_id_param: receiving_record_id,
			clearance_certificate_url_param: clearance_certificate_url,
			generated_by_user_id: generated_by_user_id,
			generated_by_name: generated_by_name || null,
			generated_by_role: generated_by_role || null
		});

		if (error) {
			console.error('Database error generating clearance certificate tasks:', error);
			return json({ 
				error: 'Failed to generate clearance certificate tasks: ' + error.message 
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
			message: `Successfully generated ${data.tasks_created} tasks and sent ${data.notifications_sent} notifications`
		});

	} catch (error) {
		console.error('Error generating clearance certificate tasks:', error);
		return json({ 
			error: 'Internal server error: ' + error.message 
		}, { status: 500 });
	}
}

export async function GET({ url }) {
	try {
		const receiving_record_id = url.searchParams.get('receiving_record_id');
		const user_id = url.searchParams.get('user_id');

		if (receiving_record_id) {
			// Get tasks for a specific receiving record
			const { data, error } = await supabase.rpc('get_tasks_for_receiving_record', {
				receiving_record_id_param: receiving_record_id
			});

			if (error) {
				console.error('Database error fetching receiving record tasks:', error);
				return json({ error: 'Failed to fetch tasks' }, { status: 500 });
			}

			// Return empty array if no tasks found instead of error
			return json({ 
				success: true, 
				tasks: data || [],
				message: data && data.length > 0 ? 'Tasks found' : 'No tasks generated yet'
			});

		} else if (user_id) {
			// Get receiving tasks for a specific user
			const status_filter = url.searchParams.get('status') || null;
			const limit = parseInt(url.searchParams.get('limit') || '50');

			const { data, error } = await supabase.rpc('get_receiving_tasks_for_user', {
				user_id_param: user_id,
				status_filter: status_filter,
				limit_count: limit
			});

			if (error) {
				console.error('Database error fetching user receiving tasks:', error);
				return json({ error: 'Failed to fetch user tasks' }, { status: 500 });
			}

			return json({ 
				success: true, 
				tasks: data || []
			});

		} else {
			// Get receiving task statistics
			const branch_id = url.searchParams.get('branch_id');
			const date_from = url.searchParams.get('date_from');
			const date_to = url.searchParams.get('date_to');

			const { data, error } = await supabase.rpc('get_receiving_task_statistics', {
				branch_id_param: branch_id ? parseInt(branch_id) : null,
				date_from: date_from || null,
				date_to: date_to || null
			});

			if (error) {
				console.error('Database error fetching receiving task statistics:', error);
				return json({ error: 'Failed to fetch statistics' }, { status: 500 });
			}

			return json({ 
				success: true, 
				statistics: data || []
			});
		}

	} catch (error) {
		console.error('Error fetching receiving tasks:', error);
		return json({ error: 'Internal server error' }, { status: 500 });
	}
}