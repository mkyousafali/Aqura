import { json } from '@sveltejs/kit';
import { supabase } from '$lib/utils/supabase';

export async function GET({ url }) {
	try {
		const user_id = url.searchParams.get('user_id');

		if (!user_id) {
			return json({ 
				error: 'User ID is required' 
			}, { status: 400 });
		}

		// Call the database function to get user dashboard
		const { data, error } = await supabase.rpc('get_user_receiving_tasks_dashboard', {
			user_id_param: user_id
		});

		if (error) {
			console.error('Database error fetching user dashboard:', error);
			return json({ 
				error: 'Failed to fetch user dashboard: ' + error.message 
			}, { status: 500 });
		}

		return json({ 
			success: true,
			dashboard: data
		});

	} catch (error) {
		console.error('Error fetching user dashboard:', error);
		return json({ 
			error: 'Internal server error: ' + error.message 
		}, { status: 500 });
	}
}