import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

const supabase = createClient(supabaseUrl, supabaseKey);

export const GET: RequestHandler = async ({ url }) => {
	try {
		const branchId = url.searchParams.get('branch_id');
		const serviceType = url.searchParams.get('service_type') || 'delivery';
		const limit = parseInt(url.searchParams.get('limit') || '5');

		// Get current timestamp for date filtering
		const now = new Date().toISOString();

		// Build query for active offers
		let query = supabase
			.from('offers')
			.select(`
				id,
				type,
				name_ar,
				name_en,
				description_ar,
				description_en,
				discount_type,
				discount_value,
				bogo_buy_quantity,
				bogo_get_quantity,
				start_date,
				end_date,
				is_active,
				min_quantity,
				min_amount,
				max_total_uses,
				current_total_uses,
				max_uses_per_customer,
				branch_id,
				service_type,
				show_on_product_page,
				show_in_carousel
			`)
			.eq('is_active', true)
			.eq('show_in_carousel', true)
			.lte('start_date', now)
			.gte('end_date', now)
			.order('created_at', { ascending: false })
			.limit(limit);

		// Filter by branch if provided
		if (branchId && branchId !== 'null') {
			query = query.or(`branch_id.eq.${branchId},branch_id.is.null`);
		}

		// Filter by service type
		if (serviceType && serviceType !== 'both') {
			query = query.or(`service_type.eq.${serviceType},service_type.eq.both`);
		}

		const { data: offers, error } = await query;

		if (error) {
			console.error('Error fetching featured offers:', error);
			return json({ error: 'Failed to fetch offers' }, { status: 500 });
		}

		// For each offer, get the products
		const enrichedOffers = await Promise.all(
			(offers || []).map(async (offer) => {
				// Get products in this offer
				const { data: offerProducts } = await supabase
					.from('offer_products')
					.select(`
						id,
						product_id,
						offer_qty,
						offer_percentage,
						offer_price,
						max_uses,
						products:product_id (
							id,
							product_name_ar,
							product_name_en,
							sale_price,
							image_url,
							category_id,
							category_name_ar,
							category_name_en,
							unit_name_ar,
							unit_name_en,
							unit_qty,
							barcode
						)
					`)
					.eq('offer_id', offer.id);

				// Calculate remaining uses
				const totalUsesRemaining = offer.max_total_uses 
					? offer.max_total_uses - (offer.current_total_uses || 0)
					: null;

				// Calculate time remaining
				const endDate = new Date(offer.end_date);
				const timeRemaining = endDate.getTime() - Date.now();
				const hoursRemaining = Math.floor(timeRemaining / (1000 * 60 * 60));
				const daysRemaining = Math.floor(hoursRemaining / 24);

				return {
					...offer,
					products: offerProducts || [],
					total_uses_remaining: totalUsesRemaining,
					days_remaining: daysRemaining,
					hours_remaining: hoursRemaining,
					is_expiring_soon: hoursRemaining < 24 && hoursRemaining > 0
				};
			})
		);

		return json({
			success: true,
			offers: enrichedOffers,
			count: enrichedOffers.length
		});

	} catch (error) {
		console.error('Unexpected error in featured-offers API:', error);
		return json({ error: 'Internal server error' }, { status: 500 });
	}
};
