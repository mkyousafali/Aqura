import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { supabaseAdmin } from '$lib/utils/supabase';

// Use service role client to bypass RLS for reading offer data
const supabase = supabaseAdmin;

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
				start_date,
				end_date,
				is_active,
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
				console.log(`🔍 API Processing offer ${offer.id} (${offer.type})`);
				let products = [];
				let bundles = [];
				let bogoRules = [];

				// Get products for product offers (percentage/special price)
				if (offer.type === 'product') {
					console.log(`  📦 Fetching products for offer ${offer.id}`);
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
					products = offerProducts || [];
				}

				// Get bundle items for bundle offers
				if (offer.type === 'bundle') {
					console.log(`  📦 Fetching bundles for offer ${offer.id}`);
					const { data: offerBundles, error: bundleError } = await supabase
						.from('offer_bundles')
						.select('*')
						.eq('offer_id', offer.id);
					
					if (bundleError) {
						console.error(`  ❌ Bundle fetch error:`, bundleError);
					} else {
						console.log(`  ✅ Found ${offerBundles?.length || 0} bundles`);
					}
					
					bundles = offerBundles || [];
					
					// For each bundle, fetch the product details from required_products
					if (bundles.length > 0) {
						console.log(`  🔄 Processing ${bundles.length} bundles...`);
						for (const bundle of bundles) {
							console.log(`    Bundle ${bundle.id}: required_products =`, bundle.required_products);
							if (bundle.required_products && Array.isArray(bundle.required_products)) {
								const productIds = bundle.required_products.map(item => item.product_id);
								console.log(`    Fetching ${productIds.length} products:`, productIds);
								const { data: products, error: prodError } = await supabase
									.from('products')
									.select('*')
									.in('id', productIds);
								
								if (prodError) {
									console.error(`    ❌ Product fetch error:`, prodError);
								} else {
									console.log(`    ✅ Found ${products?.length || 0} products`);
								}
								
								// Attach full product details to each required_product
								bundle.items_with_details = bundle.required_products.map(item => {
									const product = products?.find(p => p.id === item.product_id);
									return {
										...item,
										product
									};
								});
								console.log(`    ✅ Created items_with_details:`, bundle.items_with_details.length);
							}
						}
					}
				}

				// Get BOGO rules for buy_x_get_y offers
				if (offer.type === 'bogo' || offer.type === 'buy_x_get_y') {
					console.log(`  📦 Fetching BOGO rules for offer ${offer.id}`);
					const { data: bogoData, error: bogoError } = await supabase
						.from('bogo_offer_rules')
						.select('*')
						.eq('offer_id', offer.id);
					
					if (bogoError) {
						console.error(`  ❌ BOGO fetch error:`, bogoError);
					} else {
						console.log(`  ✅ Found ${bogoData?.length || 0} BOGO rules`);
					}
					
					// Fetch product details for buy and get products
					if (bogoData && bogoData.length > 0) {
						console.log(`  🔄 Processing ${bogoData.length} BOGO rules...`);
						for (const rule of bogoData) {
							console.log(`    Rule ${rule.id}: Buy ${rule.buy_product_id}, Get ${rule.get_product_id}`);
							const { data: buyProduct, error: buyError } = await supabase
								.from('products')
								.select('*')
								.eq('id', rule.buy_product_id)
								.single();
							
							const { data: getProduct, error: getError } = await supabase
								.from('products')
								.select('*')
								.eq('id', rule.get_product_id)
								.single();
							
							if (buyError) console.error(`    ❌ Buy product error:`, buyError);
							if (getError) console.error(`    ❌ Get product error:`, getError);
							
							rule.buy_product = buyProduct;
							rule.get_product = getProduct;
							console.log(`    ✅ Attached products:`, { buy: buyProduct?.product_name_en, get: getProduct?.product_name_en });
						}
					}
					bogoRules = bogoData || [];
				}

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
					products,
					bundles,
					bogo_rules: bogoRules,
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
