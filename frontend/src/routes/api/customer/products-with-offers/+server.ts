import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { supabase } from '$lib/utils/supabase';

// Uses RPC: get_customer_products_with_offers(p_branch_id, p_service_type)
// All product + offer enrichment, BOGO cards, and bundle cards are computed server-side in PostgreSQL

export const GET: RequestHandler = async ({ url }) => {
	const branchId = url.searchParams.get('branchId');
	const serviceType = url.searchParams.get('serviceType') || 'both';

	if (!branchId) {
		return json({ error: 'Missing branchId parameter' }, { status: 400 });
	}

	try {
		const { data, error } = await supabase.rpc('get_customer_products_with_offers', {
			p_branch_id: branchId,
			p_service_type: serviceType
		});

		if (error) {
			console.error('Error calling get_customer_products_with_offers RPC:', error);
			return json({ error: 'Failed to fetch products' }, { status: 500 });
		}

		const result = data || { products: [], bogoOffers: [], bundleOffers: [], offersCount: 0 };

		console.log(`📦 RPC returned ${result.products?.length || 0} products, ${result.bogoOffers?.length || 0} BOGO offers, ${result.bundleOffers?.length || 0} bundle offers (${result.offersCount} active offers)`);

		return json({
			products: result.products || [],
			bogoOffers: result.bogoOffers || [],
			bundleOffers: result.bundleOffers || [],
			offersCount: result.offersCount || 0
		});
	} catch (error) {
		console.error('Error in products-with-offers:', error);
		return json({ error: 'Internal server error' }, { status: 500 });
	}
};
