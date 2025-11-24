import type { RequestHandler } from './$types';

export const GET: RequestHandler = async ({ url, fetch }) => {
	try {
		const imageUrl = url.searchParams.get('url');
		
		if (!imageUrl) {
			return new Response('Image URL is required', { status: 400 });
		}
		
		console.log('Proxying image:', imageUrl);
		
		// Try multiple user agents if the first one fails
		const userAgents = [
			'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
			'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
			'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
		];
		
		let lastError = null;
		
		for (const userAgent of userAgents) {
			try {
				// Fetch the image with proper headers to avoid blocking
				const response = await fetch(imageUrl, {
					headers: {
						'User-Agent': userAgent,
						'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
						'Accept-Language': 'en-US,en;q=0.9',
						'Accept-Encoding': 'gzip, deflate, br',
						'Referer': new URL(imageUrl).origin + '/',
						'DNT': '1',
						'Connection': 'keep-alive',
						'Upgrade-Insecure-Requests': '1'
					},
					redirect: 'follow'
				});
				
				if (response.ok) {
					// Get the image data
					const imageBuffer = await response.arrayBuffer();
					
					// Get content type or default to jpeg
					const contentType = response.headers.get('content-type') || 'image/jpeg';
					
					// Return the image with proper headers
					return new Response(imageBuffer, {
						headers: {
							'Content-Type': contentType,
							'Cache-Control': 'public, max-age=3600',
							'Access-Control-Allow-Origin': '*',
						}
					});
				}
				
				lastError = `HTTP ${response.status}: ${response.statusText}`;
			} catch (err) {
				lastError = err instanceof Error ? err.message : 'Unknown error';
				console.log(`User agent failed, trying next...`);
			}
		}
		
		console.error('All attempts failed. Last error:', lastError);
		return new Response(`Failed to fetch image: ${lastError}`, { status: 502 });
		
	} catch (error) {
		console.error('Error proxying image:', error);
		const errorMessage = error instanceof Error ? error.message : 'Error fetching image';
		return new Response(errorMessage, { status: 500 });
	}
};
