import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

export const POST: RequestHandler = async ({ request }) => {
	try {
		const { barcode, productNameEn, productNameAr } = await request.json();
		
		if (!barcode) {
			return json({ error: 'Barcode is required', images: [] }, { status: 400 });
		}
		
		console.log('[Image Search] Starting search for:', { barcode, productNameEn, productNameAr });
		
		const allImages: any[] = [];
		const seenUrls = new Set<string>();
		
		// Helper function to search using HTML scraping (simpler approach)
		async function searchAndGetImages(query: string, limit: number, searchType: string) {
			try {
				console.log(`[Image Search] Searching for: "${query}" (${searchType})`);
				
				// Use DuckDuckGo HTML search page (more reliable than API)
				const searchUrl = `https://duckduckgo.com/?q=${encodeURIComponent(query)}&iax=images&ia=images`;
				
				const response = await fetch(searchUrl, {
					headers: {
						'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
						'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
						'Accept-Language': 'en-US,en;q=0.9',
						'Cache-Control': 'no-cache',
						'Pragma': 'no-cache',
					}
				});
				
				if (!response.ok) {
					console.error(`[Image Search] Search failed: ${response.status}`);
					return [];
				}
				
				const html = await response.text();
				console.log(`[Image Search] Received HTML length: ${html.length}`);
				
				// Extract image URLs from HTML using regex
				const imageRegex = /https?:\/\/[^"\s]+?\.(?:jpg|jpeg|png|gif|webp)/gi;
				const matches = html.match(imageRegex) || [];
				
				// Filter and deduplicate images
				const images = Array.from(new Set(matches))
					.filter(url => {
						// Filter out tiny icons, buttons, and logos
						return !url.includes('icon') && 
						       !url.includes('logo') && 
						       !url.includes('favicon') &&
						       !url.includes('button') &&
						       url.length < 500; // Avoid data URLs
					})
					.slice(0, limit)
					.map(url => ({
						url: url,
						thumbnail: url,
						title: query,
						source: 'Web Search',
						searchType: searchType
					}));
				
				console.log(`[Image Search] Found ${images.length} images for: ${query}`);
				return images;
			} catch (error) {
				console.error(`[Image Search] Error searching for "${query}":`, error);
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
		
		console.log(`[Image Search] Total unique images found: ${allImages.length}`);
		
		// If no images found, return a helpful message
		if (allImages.length === 0) {
			return json({ 
				error: 'No images found. Try using Google search instead.',
				images: [],
				barcode 
			});
		}
		
		return json({ images: allImages, barcode });
			
	} catch (error) {
		console.error('[Image Search] Error finding image:', error);
		return json({ 
			error: 'Search service temporarily unavailable. Please use Google search.',
			images: [] 
		}, { status: 500 });
	}
};
