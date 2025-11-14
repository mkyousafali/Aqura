import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { supabaseAdmin } from '$lib/utils/supabase';

export const GET: RequestHandler = async ({ url }) => {
	const branchId = url.searchParams.get('branchId');
	const serviceType = url.searchParams.get('serviceType'); // 'delivery' or 'pickup'

	if (!branchId) {
		return json({ error: 'Missing branchId parameter' }, { status: 400 });
	}

	try {
		const now = new Date().toISOString();

		// Step 1: Get all active offers (product and BOGO)
		const { data: offers, error: offersError } = await supabaseAdmin
			.from('offers')
			.select('*')
			.eq('is_active', true)
			.in('type', ['product', 'bogo'])
			.lte('start_date', now)
			.gte('end_date', now);

		if (offersError) {
			console.error('Error fetching offers:', offersError);
			return json({ error: 'Failed to fetch offers' }, { status: 500 });
		}

		console.log(`📊 Found ${offers?.length || 0} active offers (product + BOGO)`);

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
			const { data: products, error: productsError } = await supabaseAdmin
				.from('products')
				.select('*')
				.eq('is_active', true)
				.order('product_name_en');

			if (productsError) {
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
		const { data: offerProducts, error: offerProductsError } = await supabaseAdmin
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
		const { data: bogoRules, error: bogoError } = await supabaseAdmin
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

			// Add BOGO info to BUY product
			const buyProductSerial = buyProduct.product_serial;
			const buyProductId = buyProduct.id;
			const buyKey = `${buyProductSerial}-${buyProductId}`;

			// Check if product already has a better offer
			const existingBuyProduct = productMap.get(buyKey);
			if (!existingBuyProduct || !existingBuyProduct.hasOffer) {
				// Add BOGO offer info to the buy product
				const enrichedBuyProduct = {
					id: buyProductId,
					product_serial: buyProductSerial,
					nameEn: buyProduct.product_name_en,
					nameAr: buyProduct.product_name_ar,
					category: buyProduct.category_id,
					categoryNameEn: buyProduct.category_name_en,
					categoryNameAr: buyProduct.category_name_ar,
					image: buyProduct.image_url,
					barcode: buyProduct.barcode,
					stock: buyProduct.current_stock,
					lowStockThreshold: buyProduct.minimum_qty_alert,
					
					// Unit info
					unitEn: buyProduct.unit_name_en,
					unitAr: buyProduct.unit_name_ar,
					unitQty: buyProduct.unit_qty,
					
					// Pricing (no price change for BOGO buy product)
					originalPrice: parseFloat(buyProduct.sale_price),
					offerPrice: null,
					savings: 0,
					discountPercentage: 0,
					
					// Offer info
					hasOffer: true,
					offerType: 'bogo',
					offerId: offer.id,
					offerNameEn: offer.name_en,
					offerNameAr: offer.name_ar,
					offerQty: rule.buy_quantity,
					maxUses: null,
					
					// BOGO specific info
					bogoGetProductId: rule.get_product_id,
					bogoGetQuantity: rule.get_quantity,
					bogoDiscountType: rule.discount_type,
					bogoDiscountValue: rule.discount_value,
					
					// Expiry info
					offerEndDate: offer.end_date,
					isExpiringSoon: isExpiringSoon(offer.end_date)
				};

				productMap.set(buyKey, enrichedBuyProduct);
			}

			// Mark GET product with BOGO free/discount info
			if (getProduct && getProduct.is_active) {
				const getProductSerial = getProduct.product_serial;
				const getProductId = getProduct.id;
				const getKey = `${getProductSerial}-${getProductId}`;

				const existingGetProduct = productMap.get(getKey);
				
				// Calculate the effective price for the get product
				const getProductPrice = parseFloat(getProduct.sale_price);
				let effectivePrice = getProductPrice;
				let discountPercentage = 0;
				
				if (rule.discount_type === 'free') {
					effectivePrice = 0;
					discountPercentage = 100;
				} else if (rule.discount_type === 'percentage' && rule.discount_value) {
					discountPercentage = parseFloat(rule.discount_value);
					effectivePrice = getProductPrice - (getProductPrice * discountPercentage / 100);
				}

				if (!existingGetProduct || !existingGetProduct.hasOffer) {
					const enrichedGetProduct = {
						id: getProductId,
						product_serial: getProductSerial,
						nameEn: getProduct.product_name_en,
						nameAr: getProduct.product_name_ar,
						category: getProduct.category_id,
						categoryNameEn: getProduct.category_name_en,
						categoryNameAr: getProduct.category_name_ar,
						image: getProduct.image_url,
						barcode: getProduct.barcode,
						stock: getProduct.current_stock,
						lowStockThreshold: getProduct.minimum_qty_alert,
						
						// Unit info
						unitEn: getProduct.unit_name_en,
						unitAr: getProduct.unit_name_ar,
						unitQty: getProduct.unit_qty,
						
						// Pricing for GET product (free or discounted)
						originalPrice: getProductPrice,
						offerPrice: effectivePrice,
						savings: getProductPrice - effectivePrice,
						discountPercentage: discountPercentage,
						
						// Offer info
						hasOffer: true,
						offerType: 'bogo_get', // Special type for get products
						offerId: offer.id,
						offerNameEn: offer.name_en,
						offerNameAr: offer.name_ar,
						offerQty: rule.get_quantity,
						maxUses: null,
						
						// BOGO specific info - reference to buy product
						bogoBuyProductId: rule.buy_product_id,
						bogoBuyQuantity: rule.buy_quantity,
						bogoDiscountType: rule.discount_type,
						bogoDiscountValue: rule.discount_value,
						
						// Expiry info
						offerEndDate: offer.end_date,
						isExpiringSoon: isExpiringSoon(offer.end_date)
					};

					productMap.set(getKey, enrichedGetProduct);
				}
			}
		});

		// Step 5: Also get regular products (without offers)
		const { data: allProducts, error: allProductsError } = await supabaseAdmin
			.from('products')
			.select('*')
			.eq('is_active', true)
			.order('product_name_en');

		if (allProductsError) {
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

		return json({
			products,
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
