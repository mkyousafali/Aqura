import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || 'https://supabase.urbanaqura.com';
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzY0ODc1NTI3LCJleHAiOjIwODA0NTE1Mjd9.IT_YSPU9oivuGveKfRarwccr59SNMzX_36cw04Lf448';

// Server-side supabase client (no persistSession / localStorage)
const serverSupabase = createClient(supabaseUrl, supabaseAnonKey, {
	auth: { persistSession: false, autoRefreshToken: false },
	global: { headers: { 'X-Client-Info': 'aqura-api-server' } }
});

// Uses RPC: get_customer_products_with_offers(p_branch_id, p_service_type)
// All product + offer enrichment, BOGO cards, and bundle cards are computed server-side in PostgreSQL

export const GET: RequestHandler = async ({ url }) => {
	const branchId = url.searchParams.get('branchId');
	const serviceType = url.searchParams.get('serviceType') || 'both';

	if (!branchId) {
		return json({ error: 'Missing branchId parameter' }, { status: 400 });
	}

	try {
		const { data, error } = await serverSupabase.rpc('get_customer_products_with_offers', {
			p_branch_id: branchId,
			p_service_type: serviceType
		});

		if (error) {
			console.error('Error calling get_customer_products_with_offers RPC:', error);
			return json({ error: 'Failed to fetch products', details: error.message }, { status: 500 });
		}

		const result = data || { products: [], bogoOffers: [], bundleOffers: [], offersCount: 0 };

		console.log(`📦 RPC returned ${result.products?.length || 0} products, ${result.bogoOffers?.length || 0} BOGO offers, ${result.bundleOffers?.length || 0} bundle offers (${result.offersCount} active offers)`);

		return json({
			products: result.products || [],
			bogoOffers: result.bogoOffers || [],
			bundleOffers: result.bundleOffers || [],
			offersCount: result.offersCount || 0
		});
	} catch (error: any) {
		console.error('Error in products-with-offers:', error);
		return json({ error: 'Internal server error', details: error?.message }, { status: 500 });
	}
};
