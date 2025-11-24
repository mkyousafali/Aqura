import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { REMOVE_BG_API_KEY } from '$env/static/private';

export const POST: RequestHandler = async ({ request, fetch }) => {
	try {
		const { imageUrl } = await request.json();

		if (!imageUrl) {
			return json({ error: 'Image URL is required' }, { status: 400 });
		}

		// Fetch the image through our proxy to handle CORS
		const proxyUrl = `/api/proxy-image?url=${encodeURIComponent(imageUrl)}`;
		const imageResponse = await fetch(proxyUrl);

		if (!imageResponse.ok) {
			throw new Error('Failed to fetch image');
		}

		const imageBlob = await imageResponse.blob();
		
		// Convert blob to base64 for remove.bg API
		const arrayBuffer = await imageBlob.arrayBuffer();
		const buffer = Buffer.from(arrayBuffer);
		const base64Image = buffer.toString('base64');

		// Use remove.bg API (free tier: 50 images/month)
		// You need to sign up at https://www.remove.bg/api and get an API key
		
		if (!REMOVE_BG_API_KEY) {
			return json(
				{ error: 'Background removal service not configured. Please add REMOVE_BG_API_KEY to your .env file.' },
				{ status: 500 }
			);
		}

		const formData = new FormData();
		formData.append('image_file_b64', base64Image);
		formData.append('size', 'auto');

		const removeBgResponse = await fetch('https://api.remove.bg/v1.0/removebg', {
			method: 'POST',
			headers: {
				'X-Api-Key': REMOVE_BG_API_KEY
			},
			body: formData
		});

		if (!removeBgResponse.ok) {
			const errorText = await removeBgResponse.text();
			console.error('Remove.bg API error:', errorText);
			
			// Check for account limit errors
			if (removeBgResponse.status === 403) {
				return json(
					{ error: 'Background removal limit reached. Free tier allows 50 images/month.' },
					{ status: 403 }
				);
			}
			
			throw new Error(`Remove.bg API error: ${removeBgResponse.status}`);
		}

		// Get the processed image
		const processedImageBuffer = await removeBgResponse.arrayBuffer();
		const processedBase64 = Buffer.from(processedImageBuffer).toString('base64');

		// Return the image as base64 data URL
		return json({
			success: true,
			imageData: `data:image/png;base64,${processedBase64}`
		});

	} catch (error) {
		console.error('Background removal error:', error);
		return json(
			{ error: error instanceof Error ? error.message : 'Failed to remove background' },
			{ status: 500 }
		);
	}
};
