import type { RequestHandler } from './$types';

export const POST: RequestHandler = async ({ request }) => {
	try {
		const formData = await request.formData();
		const file = formData.get('file') as File;
		const phoneNumberId = formData.get('phone_number_id') as string;
		const accessToken = formData.get('access_token') as string;

		if (!file || !phoneNumberId || !accessToken) {
			return new Response(JSON.stringify({ error: 'Missing required fields: file, phone_number_id, access_token' }), {
				status: 400,
				headers: { 'Content-Type': 'application/json' }
			});
		}

		const fileBuffer = await file.arrayBuffer();
		const fileSize = file.size;
		const fileType = file.type;

		// Step 1: Create resumable upload session
		const createRes = await fetch(
			`https://graph.facebook.com/v22.0/app/uploads?file_length=${fileSize}&file_type=${encodeURIComponent(fileType)}&access_token=${encodeURIComponent(accessToken)}`,
			{ method: 'POST' }
		);
		const createJson = await createRes.json();
		if (!createRes.ok) {
			return new Response(JSON.stringify({ error: createJson.error?.message || 'Failed to create upload session' }), {
				status: 400,
				headers: { 'Content-Type': 'application/json' }
			});
		}

		const uploadSessionId = createJson.id;

		// Step 2: Upload file bytes
		const uploadRes = await fetch(
			`https://graph.facebook.com/v22.0/${uploadSessionId}`,
			{
				method: 'POST',
				headers: {
					'Authorization': `OAuth ${accessToken}`,
					'file_offset': '0'
				},
				body: fileBuffer
			}
		);
		const uploadJson = await uploadRes.json();
		if (!uploadRes.ok) {
			return new Response(JSON.stringify({ error: uploadJson.error?.message || 'Failed to upload file' }), {
				status: 400,
				headers: { 'Content-Type': 'application/json' }
			});
		}

		const fileHandle = uploadJson.h;

		// Step 3: Set profile picture
		const profileRes = await fetch(
			`https://graph.facebook.com/v22.0/${phoneNumberId}/whatsapp_business_profile`,
			{
				method: 'POST',
				headers: {
					'Authorization': `Bearer ${accessToken}`,
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({
					messaging_product: 'whatsapp',
					profile_picture_handle: fileHandle
				})
			}
		);
		const profileJson = await profileRes.json();
		if (!profileRes.ok) {
			return new Response(JSON.stringify({ error: profileJson.error?.message || 'Failed to set profile picture' }), {
				status: 400,
				headers: { 'Content-Type': 'application/json' }
			});
		}

		return new Response(JSON.stringify({ success: true, message: 'Profile picture updated successfully' }), {
			headers: { 'Content-Type': 'application/json' }
		});

	} catch (e: any) {
		return new Response(JSON.stringify({ error: e.message || 'Internal server error' }), {
			status: 500,
			headers: { 'Content-Type': 'application/json' }
		});
	}
};
