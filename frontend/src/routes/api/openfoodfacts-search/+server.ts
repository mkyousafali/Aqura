import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

export const POST: RequestHandler = async ({ request }) => {
	try {
		const { barcode, productNameEn } = await request.json();

		if (!barcode) {
			return json({ error: 'Barcode is required', images: [] }, { status: 400 });
		}

		console.log('[Open Food Facts] Searching for:', { barcode, productNameEn });

		const allImages: any[] = [];
		const seenUrls = new Set<string>();

		// 1. Search by exact barcode on Open Food Facts (free, no API key)
		try {
			const response = await fetch(
				`https://world.openfoodfacts.org/api/v2/product/${barcode}.json`,
				{
					headers: {
						'User-Agent': 'Aqura-ProductMaster/1.0 (contact@urbanaqura.com)'
					}
				}
			);

			if (response.ok) {
				const data = await response.json();
				if (data.status === 1 && data.product) {
					const product = data.product;

					// Main image
					if (product.image_url) {
						allImages.push({
							url: product.image_url,
							thumbnail: product.image_small_url || product.image_url,
							title: product.product_name || barcode,
							source: 'Open Food Facts',
							searchType: 'barcode'
						});
						seenUrls.add(product.image_url);
					}

					// Front image
					if (product.image_front_url && !seenUrls.has(product.image_front_url)) {
						allImages.push({
							url: product.image_front_url,
							thumbnail: product.image_front_small_url || product.image_front_url,
							title: `${product.product_name || barcode} (Front)`,
							source: 'Open Food Facts',
							searchType: 'barcode'
						});
						seenUrls.add(product.image_front_url);
					}

					// Ingredients image
					if (product.image_ingredients_url && !seenUrls.has(product.image_ingredients_url)) {
						allImages.push({
							url: product.image_ingredients_url,
							thumbnail: product.image_ingredients_small_url || product.image_ingredients_url,
							title: `${product.product_name || barcode} (Ingredients)`,
							source: 'Open Food Facts',
							searchType: 'barcode'
						});
						seenUrls.add(product.image_ingredients_url);
					}

					// Nutrition image
					if (product.image_nutrition_url && !seenUrls.has(product.image_nutrition_url)) {
						allImages.push({
							url: product.image_nutrition_url,
							thumbnail: product.image_nutrition_small_url || product.image_nutrition_url,
							title: `${product.product_name || barcode} (Nutrition)`,
							source: 'Open Food Facts',
							searchType: 'barcode'
						});
						seenUrls.add(product.image_nutrition_url);
					}

					// Additional selected images
					if (product.selected_images) {
						for (const [key, value] of Object.entries(product.selected_images)) {
							const imgData = value as any;
							const displayUrl = imgData?.display?.en || imgData?.display?.fr || Object.values(imgData?.display || {})[0] as string;
							const smallUrl = imgData?.small?.en || imgData?.small?.fr || Object.values(imgData?.small || {})[0] as string;
							if (displayUrl && !seenUrls.has(displayUrl)) {
								allImages.push({
									url: displayUrl,
									thumbnail: smallUrl || displayUrl,
									title: `${product.product_name || barcode} (${key})`,
									source: 'Open Food Facts',
									searchType: 'barcode'
								});
								seenUrls.add(displayUrl);
							}
						}
					}
				}
			}
		} catch (error) {
			console.error('[Open Food Facts] Error searching by barcode:', error);
		}

		// 2. If no images found and we have a product name, try searching by name
		if (allImages.length === 0 && productNameEn && productNameEn.trim()) {
			try {
				const searchResponse = await fetch(
					`https://world.openfoodfacts.org/cgi/search.pl?search_terms=${encodeURIComponent(productNameEn)}&search_simple=1&action=process&json=1&page_size=5`,
					{
						headers: {
							'User-Agent': 'Aqura-ProductMaster/1.0 (contact@urbanaqura.com)'
						}
					}
				);

				if (searchResponse.ok) {
					const searchData = await searchResponse.json();
					if (searchData.products && searchData.products.length > 0) {
						for (const product of searchData.products) {
							if (product.image_url && !seenUrls.has(product.image_url)) {
								allImages.push({
									url: product.image_url,
									thumbnail: product.image_small_url || product.image_url,
									title: product.product_name || 'Product',
									source: 'Open Food Facts',
									searchType: 'name'
								});
								seenUrls.add(product.image_url);
							}
							if (product.image_front_url && !seenUrls.has(product.image_front_url)) {
								allImages.push({
									url: product.image_front_url,
									thumbnail: product.image_front_small_url || product.image_front_url,
									title: `${product.product_name || 'Product'} (Front)`,
									source: 'Open Food Facts',
									searchType: 'name'
								});
								seenUrls.add(product.image_front_url);
							}
						}
					}
				}
			} catch (error) {
				console.error('[Open Food Facts] Error searching by name:', error);
			}
		}

		console.log(`[Open Food Facts] Total images found: ${allImages.length}`);

		return json({
			images: allImages,
			total: allImages.length
		});
	} catch (error) {
		console.error('[Open Food Facts] Unexpected error:', error);
		return json({ error: 'Failed to search Open Food Facts', images: [] }, { status: 500 });
	}
};
