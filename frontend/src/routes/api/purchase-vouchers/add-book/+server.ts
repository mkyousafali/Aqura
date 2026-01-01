import { json } from '@sveltejs/kit';
import type { RequestHandler } from '@sveltejs/kit';
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.VITE_SUPABASE_URL || '';
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
const supabase = createClient(supabaseUrl, supabaseServiceKey);

export const POST: RequestHandler = async ({ request }) => {
	try {
		const body = await request.json();
		const {
			id,
			book_number,
			serial_start,
			serial_end,
			voucher_count,
			per_voucher_value,
			total_value,
			voucher_items
		} = body;

		// Validate required fields
		if (!id || !book_number || !serial_start || !serial_end || !per_voucher_value) {
			return json(
				{ message: 'Missing required fields' },
				{ status: 400 }
			);
		}

		// Insert main purchase voucher record
		const { data: pvData, error: pvError } = await supabase
			.from('purchase_vouchers')
			.insert({
				id,
				book_number,
				serial_start,
				serial_end,
				voucher_count,
				per_voucher_value,
				total_value,
				status: 'active'
			})
			.select();

		if (pvError) {
			console.error('Error inserting purchase voucher:', pvError);
			return json(
				{ message: `Error creating purchase voucher: ${pvError.message}` },
				{ status: 500 }
			);
		}

		// Insert individual voucher items
		const itemsToInsert = voucher_items.map((item: any) => ({
			purchase_voucher_id: id,
			serial_number: item.serial_number,
			value: item.value,
			status: 'issued'
		}));

		const { data: itemsData, error: itemsError } = await supabase
			.from('purchase_voucher_items')
			.insert(itemsToInsert)
			.select();

		if (itemsError) {
			console.error('Error inserting voucher items:', itemsError);
			return json(
				{ message: `Error creating voucher items: ${itemsError.message}` },
				{ status: 500 }
			);
		}

		return json(
			{
				message: 'Purchase voucher book saved successfully',
				id,
				voucher_count: voucher_items.length,
				items_created: itemsData?.length || 0
			},
			{ status: 200 }
		);
	} catch (error) {
		console.error('Error in add-book endpoint:', error);
		return json(
			{ message: 'Internal server error' },
			{ status: 500 }
		);
	}
};
