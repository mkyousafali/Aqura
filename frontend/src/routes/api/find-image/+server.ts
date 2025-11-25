import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

export const POST: RequestHandler = async ({ request }) => {
	try {
		const { barcode, productNameEn, productNameAr } = await request.json();
		
		if (!barcode) {
			return json({ error: 'Barcode is required', images: [] }, { status: 400 });
		}
		
		console.log('[DuckDuckGo] Starting search for:', { barcode, productNameEn, productNameAr });
		
		const allImages: any[] = [];
		const seenUrls = new Set<string>();
		
		// Helper function to search using DuckDuckGo's public API
		async function searchAndGetImages(query: string, limit: number, searchType: string) {
			try {
				console.log(`[DuckDuckGo] Searching for: "${query}" (${searchType})`);
				
				// Use DuckDuckGo's instant answer API (more reliable than scraping)
				const searchUrl = `https://api.duckduckgo.com/?q=${encodeURIComponent(query + ' product image')}&format=json&no_html=1&skip_disambig=1`;
				
				const response = await fetch(searchUrl, {
					headers: {
						'User-Agent': 'AquraApp/1.0',
					}
				});
				
				if (!response.ok) {
					console.error(`[DuckDuckGo] Search failed: ${response.status}`);
					return [];
				}
				
				const data = await response.json();
				const images: any[] = [];
				
				// Extract images from various sources in the response
				if (data.Image) {
					images.push({
						url: data.Image,
						thumbnail: data.Image,
						title: data.Heading || query,
						source: data.AbstractURL || 'DuckDuckGo',
						searchType: searchType
					});
				}
				
				// Check RelatedTopics for images
				if (data.RelatedTopics && Array.isArray(data.RelatedTopics)) {
					data.RelatedTopics.slice(0, limit).forEach((topic: any) => {
						if (topic.Icon && topic.Icon.URL) {
							images.push({
								url: topic.Icon.URL,
								thumbnail: topic.Icon.URL,
								title: topic.Text || query,
								source: topic.FirstURL || 'DuckDuckGo',
								searchType: searchType
							});
						}
					});
				}
				
				console.log(`[DuckDuckGo] Found ${images.length} images for: ${query}`);
				return images.slice(0, limit);
			} catch (error) {
				console.error(`[DuckDuckGo] Error searching for "${query}":`, error);
				return [];
			}
		}
		
		// 1. Search with barcode (6 best matches)
		const barcodeImages = await searchAndGetImages(`${barcode} product`, 6, 'barcode');
		barcodeImages.forEach((img: any) => {
			if (!seenUrls.has(img.url)) {
				seenUrls.add(img.url);
				allImages.push(img);
			}
		});
		
		// 2. Search with English product name (3 best matches)
		if (productNameEn && productNameEn.trim()) {
			const enImages = await searchAndGetImages(`${productNameEn} product`, 3, 'english_name');
			enImages.forEach((img: any) => {
				if (!seenUrls.has(img.url)) {
					seenUrls.add(img.url);
					allImages.push(img);
				}
			});
		}
		
		// 3. Search with Arabic product name (3 best matches)
		if (productNameAr && productNameAr.trim()) {
			const arImages = await searchAndGetImages(`${productNameAr} منتج`, 3, 'arabic_name');
			arImages.forEach((img: any) => {
				if (!seenUrls.has(img.url)) {
					seenUrls.add(img.url);
					allImages.push(img);
				}
			});
		}
		
		console.log(`[DuckDuckGo] Total unique images found: ${allImages.length}`);
		return json({ images: allImages, barcode });
			
	} catch (error) {
		console.error('[DuckDuckGo] Error finding image:', error);
		return json({ error: 'Failed to search for images', images: [] }, { status: 500 });
	}
};
