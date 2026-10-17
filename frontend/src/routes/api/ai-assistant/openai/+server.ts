import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { databaseClient, requireBreakUser } from '$lib/server/breakRegisterAuth';

const noStore = { 'Cache-Control': 'no-store' };

async function activeOpenAIKey(): Promise<string> {
	const { data, error } = await databaseClient()
		.from('system_api_keys')
		.select('api_key')
		.eq('service_name', 'openai')
		.eq('is_active', true)
		.limit(1)
		.maybeSingle();
	if (error || !data?.api_key) throw new Error('Active OpenAI API key is not configured in Aqura');
	return data.api_key;
}

function safeError(value: unknown): string {
	if (!value || typeof value !== 'object') return 'OpenAI request failed';
	const message = (value as any)?.error?.message;
	return typeof message === 'string' ? message.slice(0, 300) : 'OpenAI request failed';
}

export const GET: RequestHandler = async ({ cookies, fetch }) => {
	try {
		await requireBreakUser(cookies, 'desktop');
		const key = await activeOpenAIKey();
		const response = await fetch('https://api.openai.com/v1/models', {
			headers: { Authorization: `Bearer ${key}` }
		});
		const result = await response.json().catch(() => ({}));
		if (!response.ok) return json({ success: false, error: safeError(result) }, { status: response.status, headers: noStore });
		const models = Array.isArray(result?.data) ? result.data.map((item: any) => item?.id).filter((id: unknown) => typeof id === 'string') : [];
		return json({ success: true, models }, { headers: noStore });
	} catch (error: any) {
		return json({ success: false, error: error?.message || 'Desktop session required' }, { status: 401, headers: noStore });
	}
};

export const POST: RequestHandler = async ({ request, cookies, fetch }) => {
	try {
		await requireBreakUser(cookies, 'desktop');
		const raw = await request.text();
		if (raw.length > 20_000_000) return json({ success: false, error: 'AI request is too large' }, { status: 413, headers: noStore });
		const body = JSON.parse(raw || '{}');
		if (typeof body?.model !== 'string' || !body.model || !Array.isArray(body?.messages)) {
			return json({ success: false, error: 'Invalid AI request' }, { status: 400, headers: noStore });
		}
		const payload: Record<string, unknown> = {
			model: body.model.slice(0, 100),
			messages: body.messages
		};
		if (Array.isArray(body.tools) && body.tools.length) {
			payload.tools = body.tools;
			payload.tool_choice = 'auto';
			payload.reasoning_effort = 'none';
		}
		if (body.response_format?.type === 'json_object') payload.response_format = { type: 'json_object' };
		const key = await activeOpenAIKey();
		const response = await fetch('https://api.openai.com/v1/chat/completions', {
			method: 'POST',
			headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
			body: JSON.stringify(payload)
		});
		const result = await response.json().catch(() => ({}));
		if (!response.ok) return json({ success: false, error: safeError(result) }, { status: response.status, headers: noStore });
		const message = result?.choices?.[0]?.message;
		if (!message) return json({ success: false, error: 'OpenAI returned an empty response' }, { status: 502, headers: noStore });
		return json({ success: true, message }, { headers: noStore });
	} catch (error: any) {
		const status = error instanceof SyntaxError ? 400 : 401;
		return json({ success: false, error: error?.message || 'Desktop session required' }, { status, headers: noStore });
	}
};
