import { json } from '@sveltejs/kit';
import { supabase } from '$lib/utils/supabase';

export async function POST({ request }) {
	try {
		const { receiving_record_id } = await request.json();

		if (!receiving_record_id) {
			return json({ error: 'Receiving record ID is required' }, { status: 400 });
		}

		// Call the database function to sync ERP reference for specific receiving record
		const { data, error } = await supabase.rpc('sync_erp_reference_for_receiving_record', {
			receiving_record_id_param: receiving_record_id
		});

		if (error) {
			console.error('Database error syncing ERP reference:', error);
			return json({ 
				error: 'Failed to sync ERP reference: ' + error.message 
			}, { status: 500 });
		}

		return json({ 
			success: true,
			data: data,
			message: data?.synced ? 'ERP reference synced successfully' : 'No ERP reference found to sync'
		});

	} catch (error) {
		console.error('Error syncing ERP reference:', error);
		return json({ 
			error: 'Internal server error: ' + error.message 
		}, { status: 500 });
	}
}

// GET endpoint to check sync status for a receiving record
export async function GET({ url }) {
	try {
		const receiving_record_id = url.searchParams.get('receiving_record_id');

		if (!receiving_record_id) {
			return json({ error: 'Receiving record ID is required' }, { status: 400 });
		}

		// Get the current sync status
		const { data, error } = await supabase.rpc('check_erp_sync_status_for_record', {
			receiving_record_id_param: receiving_record_id
		});

		if (error) {
			console.error('Database error checking sync status:', error);
			return json({ 
				error: 'Failed to check sync status: ' + error.message 
			}, { status: 500 });
		}

		return json({ 
			success: true,
			data: data
		});

	} catch (error) {
		console.error('Error checking sync status:', error);
		return json({ 
			error: 'Internal server error: ' + error.message 
		}, { status: 500 });
	}
}