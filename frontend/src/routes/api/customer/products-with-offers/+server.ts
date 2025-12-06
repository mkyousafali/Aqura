import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { supabase } from '$lib/utils/supabase';

export const GET: RequestHandler = async ({ url }) => {
	const branchId = url.searchParams.get('branchId');
	const serviceType = url.searchParams.get('serviceType'); // 'delivery' or 'pickup'

	if (!branchId) {
		return json({ error: 'Missing branchId parameter' }, { status: 400 });
	}

	try {
		const now = new Date().toISOString();

	// Step 1: Get all active offers (product, BOGO, and bundle)
	const { data: offers, error: offersError } = await supabase
		.from('offers')
		.select('*')
		.eq('is_active', true)
		.in('type', ['product', 'bogo', 'bundle'])
		.lte('start_date', now)
		.gte('end_date', now);		if (offersError) {
			console.error('Error fetching offers:', offersError);
			return json({ error: 'Failed to fetch offers' }, { status: 500 });
		}

		console.log(`📊 Found ${offers?.length || 0} active offers (product + BOGO + bundle)`);

		// Filter offers by branch and service type
		const filteredOffers = (offers || []).filter((offer) => {
			// Check branch restriction
			// If branch_id is null, it's available for all branches
			if (offer.branch_id && offer.branch_id !== branchId) {
				return false;
			}

			// Check service type restriction
			// 'both' means available for both delivery and pickup
			// 'delivery' or 'pickup' means specific service type only
			if (offer.service_type && offer.service_type !== 'both' && offer.service_type !== serviceType) {
				return false;
			}

			return true;
		});

		console.log(`📊 After filtering: ${filteredOffers.length} offers for branch/service`);

		// Step 2: Get products for these offers (only special price offers)
		const offerIds = filteredOffers.map((o) => o.id);
		
		if (offerIds.length === 0) {
		// No offers, return regular products with proper field transformation
		const { data: products, error: productsError } = await supabase
			.from('products')
			.select('*')
			.eq('is_active', true)
			.order('product_name_en');			if (productsError) {
				console.error('Error fetching products:', productsError);
				return json({ error: 'Failed to fetch products' }, { status: 500 });
			}

			// Transform field names to match expected format
			const transformedProducts = (products || []).map(product => ({
				id: product.id,
				product_serial: product.product_serial,
				nameEn: product.product_name_en,
				nameAr: product.product_name_ar,
				category: product.category_id,
				categoryNameEn: product.category_name_en,
				categoryNameAr: product.category_name_ar,
				image: product.image_url,
				barcode: product.barcode,
				stock: product.current_stock,
				lowStockThreshold: product.minimum_qty_alert,
				
				unitEn: product.unit_name_en,
				unitAr: product.unit_name_ar,
				unitQty: product.unit_qty,
				
				originalPrice: parseFloat(product.sale_price),
				offerPrice: null,
				savings: 0,
				discountPercentage: 0,
				
				hasOffer: false,
				offerType: null,
				offerId: null,
				offerNameEn: null,
				offerNameAr: null,
				offerQty: null,
				maxUses: null,
				offerEndDate: null,
				isExpiringSoon: false
			}));

			return json({ products: transformedProducts, offersCount: 0 });
		}

	// Get offer products with special price
	const { data: offerProducts, error: offerProductsError } = await supabase
		.from('offer_products')
		.select(`
				id,
				offer_id,
				product_id,
				offer_qty,
				offer_percentage,
				offer_price,
				max_uses,
				products:product_id (
					id,
					product_serial,
					product_name_ar,
					product_name_en,
					sale_price,
					cost,
					image_url,
					category_id,
					category_name_ar,
					category_name_en,
					unit_name_ar,
					unit_name_en,
					unit_qty,
					barcode,
					current_stock,
					minimum_qty_alert,
					is_active
				)
			`)
			.in('offer_id', offerIds);

		if (offerProductsError) {
			console.error('Error fetching offer products:', offerProductsError);
			return json({ error: 'Failed to fetch offer products' }, { status: 500 });
		}

		console.log(`📦 Found ${offerProducts?.length || 0} offer products`);

	// Step 3: Get BOGO offer rules
	const { data: bogoRules, error: bogoError } = await supabase
		.from('bogo_offer_rules')
		.select(`
				id,
				offer_id,
				buy_product_id,
				buy_quantity,
				get_product_id,
				get_quantity,
				discount_type,
				discount_value,
				buy_product:buy_product_id (
					id,
					product_serial,
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
					barcode,
					current_stock,
					minimum_qty_alert,
					is_active
				),
				get_product:get_product_id (
					id,
					product_serial,
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
					barcode,
					current_stock,
					minimum_qty_alert,
					is_active
				)
			`)
			.in('offer_id', offerIds);

		if (bogoError) {
			console.error('Error fetching BOGO rules:', bogoError);
		}

		console.log(`🎁 Found ${bogoRules?.length || 0} BOGO rules`);

		// Step 4: Enrich products with offer data
		const productMap = new Map();

		(offerProducts || []).forEach((offerProduct) => {
			const product = offerProduct.products;
			if (!product || !product.is_active) return;

			const offer = filteredOffers.find((o) => o.id === offerProduct.offer_id);
			if (!offer) return;

			// Check if this is a percentage offer or special price offer
			const hasPercentage = offerProduct.offer_percentage && offerProduct.offer_percentage > 0;
			const hasSpecialPrice = offerProduct.offer_price && offerProduct.offer_price > 0;
			
			if (!hasPercentage && !hasSpecialPrice) return;

			const productSerial = product.product_serial;
			const productId = product.id;

			// Calculate offer details
			const originalPrice = parseFloat(product.sale_price);
			let offerPrice: number;
			let discountPercentage: number;
			let offerType: 'percentage' | 'special_price';

			if (hasPercentage) {
				// Percentage offer
				discountPercentage = parseFloat(offerProduct.offer_percentage);
				offerPrice = originalPrice - (originalPrice * discountPercentage / 100);
				offerType = 'percentage';
			} else {
				// Special price offer
				offerPrice = parseFloat(offerProduct.offer_price);
				discountPercentage = Math.round(((originalPrice - offerPrice) / originalPrice) * 100);
				offerType = 'special_price';
			}

			const savings = originalPrice - offerPrice;

			const enrichedProduct = {
				id: productId,
				product_serial: productSerial,
				nameEn: product.product_name_en,
				nameAr: product.product_name_ar,
				category: product.category_id,
				categoryNameEn: product.category_name_en,
				categoryNameAr: product.category_name_ar,
				image: product.image_url,
				barcode: product.barcode,
				stock: product.current_stock,
				lowStockThreshold: product.minimum_qty_alert,
				
				// Unit info
				unitEn: product.unit_name_en,
				unitAr: product.unit_name_ar,
				unitQty: product.unit_qty,
				
				// Pricing
				originalPrice: originalPrice,
				offerPrice: offerPrice,
				savings: savings,
				discountPercentage: discountPercentage,
				
				// Offer info
				hasOffer: true,
				offerType: offerType,
				offerId: offer.id,
				offerNameEn: offer.name_en,
				offerNameAr: offer.name_ar,
				offerQty: offerProduct.offer_qty || 1,
				maxUses: offerProduct.max_uses,
				
				// Expiry info
				offerEndDate: offer.end_date,
				isExpiringSoon: isExpiringSoon(offer.end_date)
			};

			// Use product_id as key (not serial) to handle multi-unit products
			const key = `${productSerial}-${productId}`;
			productMap.set(key, enrichedProduct);
		});

		// Process BOGO offers - Add badge to "buy" products AND mark "get" products
		(bogoRules || []).forEach((rule) => {
			const buyProduct = rule.buy_product;
			const getProduct = rule.get_product;
			
			if (!buyProduct || !buyProduct.is_active) return;

			const offer = filteredOffers.find((o) => o.id === rule.offer_id);
			if (!offer) return;

			// DON'T add BUY or GET products to productMap with offer info
			// They should only appear as regular products
			// BOGO offers are completely separate in the bogoOffers array
		});

	// Step 5: Also get regular products (without offers)
	const { data: allProducts, error: allProductsError } = await supabase
		.from('products')
		.select('*')
		.eq('is_active', true)
		.order('product_name_en');		if (allProductsError) {
			console.error('Error fetching all products:', allProductsError);
		}

		// Add regular products that don't have offers
		(allProducts || []).forEach((product) => {
			const key = `${product.product_serial}-${product.id}`;
			
			if (!productMap.has(key)) {
				productMap.set(key, {
					id: product.id,
					product_serial: product.product_serial,
					nameEn: product.product_name_en,
					nameAr: product.product_name_ar,
					category: product.category_id,
					categoryNameEn: product.category_name_en,
					categoryNameAr: product.category_name_ar,
					image: product.image_url,
					barcode: product.barcode,
					stock: product.current_stock,
					lowStockThreshold: product.minimum_qty_alert,
					
					unitEn: product.unit_name_en,
					unitAr: product.unit_name_ar,
					unitQty: product.unit_qty,
					
					originalPrice: parseFloat(product.sale_price),
					offerPrice: null,
					savings: 0,
					discountPercentage: 0,
					
					hasOffer: false,
					offerType: null,
					offerId: null,
					offerNameEn: null,
					offerNameAr: null,
					offerQty: null,
					maxUses: null,
					offerEndDate: null,
					isExpiringSoon: false
				});
			}
		});

		const products = Array.from(productMap.values());
		console.log(`✅ Returning ${products.length} total products (${products.filter(p => p.hasOffer).length} with offers)`);

		// Step 6: Create separate BOGO offer cards
		const bogoOffers = (bogoRules || []).map((rule) => {
			const buyProduct = rule.buy_product;
			const getProduct = rule.get_product;
			const offer = filteredOffers.find((o) => o.id === rule.offer_id);

			if (!buyProduct || !getProduct || !offer) return null;
			if (!buyProduct.is_active || !getProduct.is_active) return null;

			// Calculate discount info for get product
			const getProductPrice = parseFloat(getProduct.sale_price);
			let effectivePrice = getProductPrice;
			let discountPercentage = 0;
			let isFree = false;
			
			if (rule.discount_type === 'free') {
				effectivePrice = 0;
				discountPercentage = 100;
				isFree = true;
			} else if (rule.discount_type === 'percentage' && rule.discount_value) {
				discountPercentage = parseFloat(rule.discount_value);
				effectivePrice = getProductPrice - (getProductPrice * discountPercentage / 100);
			}

			return {
				id: `bogo-${rule.id}`,
				type: 'bogo_offer',
				offerId: offer.id,
				offerNameEn: offer.name_en,
				offerNameAr: offer.name_ar,
				isExpiringSoon: isExpiringSoon(offer.end_date),
				offerEndDate: offer.end_date,
				
				// Buy product details
				buyProduct: {
					id: buyProduct.id,
					product_serial: buyProduct.product_serial,
					nameEn: buyProduct.product_name_en,
					nameAr: buyProduct.product_name_ar,
					image: buyProduct.image_url,
					unitEn: buyProduct.unit_name_en,
					unitAr: buyProduct.unit_name_ar,
					unitQty: buyProduct.unit_qty,
					price: parseFloat(buyProduct.sale_price),
					quantity: rule.buy_quantity,
					stock: buyProduct.current_stock,
					lowStockThreshold: buyProduct.minimum_qty_alert,
					barcode: buyProduct.barcode,
					category: buyProduct.category_id,
					categoryNameEn: buyProduct.category_name_en,
					categoryNameAr: buyProduct.category_name_ar
				},
				
				// Get product details
				getProduct: {
					id: getProduct.id,
					product_serial: getProduct.product_serial,
					nameEn: getProduct.product_name_en,
					nameAr: getProduct.product_name_ar,
					image: getProduct.image_url,
					unitEn: getProduct.unit_name_en,
					unitAr: getProduct.unit_name_ar,
					unitQty: getProduct.unit_qty,
					originalPrice: getProductPrice,
					offerPrice: effectivePrice,
					quantity: rule.get_quantity,
					isFree: isFree,
					discountPercentage: discountPercentage,
					stock: getProduct.current_stock,
					lowStockThreshold: getProduct.minimum_qty_alert,
					barcode: getProduct.barcode,
					category: getProduct.category_id,
					categoryNameEn: getProduct.category_name_en,
					categoryNameAr: getProduct.category_name_ar
				},
				
				// Bundle pricing
				bundlePrice: parseFloat(buyProduct.sale_price) * rule.buy_quantity + effectivePrice * rule.get_quantity,
				originalBundlePrice: parseFloat(buyProduct.sale_price) * rule.buy_quantity + getProductPrice * rule.get_quantity,
				savings: (getProductPrice - effectivePrice) * rule.get_quantity
			};
		}).filter(offer => offer !== null);

		console.log(`🎁 Created ${bogoOffers.length} separate BOGO offer cards`);

		// Step 5: Process bundle offers
		const bundleOfferIds = filteredOffers.filter(o => o.type === 'bundle').map(o => o.id);
		let bundleOffers = [];

	if (bundleOfferIds.length > 0) {
		const { data: bundleRules, error: bundleError } = await supabase
			.from('offer_bundles')
			.select('*')
			.in('offer_id', bundleOfferIds);			if (bundleError) {
				console.error('Error fetching bundle rules:', bundleError);
			} else {
				console.log(`📦 Found ${bundleRules?.length || 0} bundle rules`);

				// Process each bundle
				bundleOffers = await Promise.all(bundleRules.map(async (bundle) => {
					const offer = filteredOffers.find(o => o.id === bundle.offer_id);
					if (!offer) return null;

					// Parse required products (array of {product_id, unit_id, quantity})
					const requiredProducts = typeof bundle.required_products === 'string' 
						? JSON.parse(bundle.required_products || '[]')
						: (bundle.required_products || []);
					if (requiredProducts.length === 0 || requiredProducts.length > 6) return null;

				// Fetch all product details
				const productPromises = requiredProducts.map(async (req) => {
					const { data: prod, error: prodError } = await supabase
						.from('products')
						.select('*')
						.eq('id', req.product_id)
						.single();						if (prodError || !prod) return null;

						return {
							id: req.product_id,
							unitId: req.unit_id,
							product_serial: prod.product_serial,
							nameEn: prod.product_name_en,
							nameAr: prod.product_name_ar,
							image: prod.image_url,
							price: parseFloat(prod.sale_price),
							quantity: req.quantity || 1,
							unitQty: prod.unit_qty,
							unitEn: prod.unit_name_en,
							unitAr: prod.unit_name_ar,
							stock: prod.current_stock,
							barcode: prod.barcode
						};
					});

					const bundleProducts = (await Promise.all(productPromises)).filter(p => p !== null);
					if (bundleProducts.length !== requiredProducts.length) return null;

					// Calculate bundle pricing
					const originalPrice = bundleProducts.reduce((sum, p) => sum + (p.price * p.quantity), 0);
					const discountValue = parseFloat(bundle.discount_value) || 0;
					let bundlePrice = originalPrice;

					if (bundle.discount_type === 'percentage') {
						bundlePrice = originalPrice * (1 - discountValue / 100);
					} else if (bundle.discount_type === 'fixed') {
						bundlePrice = Math.max(0, originalPrice - discountValue);
					}

					return {
						offerId: offer.id,
						offerNameEn: offer.name_en,
						offerNameAr: offer.name_ar,
						offerType: 'bundle',
						bundleName: bundle.bundle_name,
						bundleProducts: bundleProducts,
						bundlePrice: bundlePrice,
						originalBundlePrice: originalPrice,
						savings: originalPrice - bundlePrice,
						discountType: bundle.discount_type,
						discountValue: discountValue,
						offerEndDate: offer.end_date,
						isExpiringSoon: isExpiringSoon(offer.end_date)
					};
				}));

				bundleOffers = bundleOffers.filter(b => b !== null);
				console.log(`📦 Created ${bundleOffers.length} bundle offer cards`);
			}
		}

		return json({
			products,
			bogoOffers,
			bundleOffers,
			offersCount: filteredOffers.length
		});
	} catch (error) {
		console.error('Error in products-with-offers:', error);
		return json({ error: 'Internal server error' }, { status: 500 });
	}
};

// Helper function to check if offer is expiring soon (within 24 hours)
function isExpiringSoon(endDate: string): boolean {
	const end = new Date(endDate);
	const now = new Date();
	const hoursUntilExpiry = (end.getTime() - now.getTime()) / (1000 * 60 * 60);
	return hoursUntilExpiry > 0 && hoursUntilExpiry <= 24;
}
