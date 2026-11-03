import { supabase } from '$lib/utils/supabase';

/** The SQL Server lookup remains the only Direct Order HTTP endpoint. */
export function directOrderFetch(mobile: boolean, input: RequestInfo | URL, init: RequestInit = {}) {
	const headers = new Headers(init.headers);
	headers.set('x-aqura-interface', mobile ? 'mobile' : 'desktop');
	if (!headers.has('Accept')) headers.set('Accept', 'application/json');
	return fetch(input, { ...init, headers });
}

export async function directOrderRpc(mobile: boolean, name: string, parameters: Record<string, unknown> = {}, signal?: AbortSignal): Promise<any> {
	let query = supabase.rpc(name, { ...parameters, p_interface: mobile ? 'mobile' : 'desktop' });
	if (signal) query = query.abortSignal(signal);
	const { data, error } = await query;
	if (error) throw error;
	if (data?.success !== true) throw new Error('Direct Order RPC failed');
	return data;
}

export async function directOrderPhotoData(mobile: boolean, templateId: string, productId: string): Promise<string> {
	const data = await directOrderRpc(mobile, 'direct_order_get_photo', { p_template_id: templateId, p_product_id: productId });
	if (!['image/jpeg', 'image/png', 'image/webp'].includes(data.mimeType) || typeof data.photoBase64 !== 'string' || !data.photoBase64) {
		throw new Error('Product photo unavailable');
	}
	return `data:${data.mimeType};base64,${data.photoBase64.replace(/\s/g, '')}`;
}

export async function encodeDirectOrderPhoto(file: File): Promise<{ base64: string; mimeType: string; dataUrl: string }> {
	const dataUrl = await new Promise<string>((resolve, reject) => {
		const reader = new FileReader();
		reader.onload = () => typeof reader.result === 'string' ? resolve(reader.result) : reject(new Error('Unable to read photo'));
		reader.onerror = () => reject(new Error('Unable to read photo'));
		reader.readAsDataURL(file);
	});
	return { base64: dataUrl.slice(dataUrl.indexOf(',') + 1), mimeType: file.type, dataUrl };
}
