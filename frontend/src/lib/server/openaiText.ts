import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';

// Shared by the text, receipt and document tools. WhatsApp replies use their own Gemini path.
export const OPENAI_TEXT_MODEL = 'gpt-4.1-mini';

export interface TextGenerationOptions {
	prompt: string;
	systemPrompt?: string;
	temperature?: number;
	maxTokens?: number;
	jsonMode?: boolean;
	schema?: Record<string, unknown>;
	attachments?: Array<{ mimeType: string; data: string }>;
}

export async function generateOpenAIText(options: TextGenerationOptions): Promise<string> {
	const { prompt, systemPrompt, attachments = [], schema, jsonMode = false } = options;
	if (typeof prompt !== 'string' || !prompt.trim()) throw new Error('A text prompt is required.');
	const supabaseUrl = env.VITE_SUPABASE_URL || '';
	const supabaseKey = env.SUPABASE_SERVICE_ROLE_KEY || env.VITE_SUPABASE_SERVICE_KEY || env.VITE_SUPABASE_ANON_KEY || '';
	if (!supabaseUrl || !supabaseKey) throw new Error('Database connection is not configured.');
	const db = createClient(supabaseUrl, supabaseKey);
	const { data, error } = await db.from('system_api_keys').select('api_key')
		.eq('service_name', 'openai').eq('is_active', true).limit(1).maybeSingle();
	if (error || !data?.api_key) throw new Error('Configure an active OpenAI key in API Keys Manager.');
	const key: string = data.api_key;
	const content: Array<Record<string, unknown>> = [{ type: 'text', text: prompt }];
	for (const attachment of attachments) {
		const mimeType = attachment.mimeType.toLowerCase();
		const dataUrl = `data:${mimeType};base64,${attachment.data}`;
		if (mimeType === 'application/pdf') {
			content.push({ type: 'file', file: { filename: 'document.pdf', file_data: dataUrl } });
		} else if (['image/jpeg', 'image/png', 'image/webp', 'image/gif'].includes(mimeType)) {
			content.push({ type: 'image_url', image_url: { url: dataUrl, detail: 'high' } });
		} else {
			throw new Error('Unsupported document type. Use a PDF, JPEG, PNG, WebP or GIF.');
		}
	}
	const messages: Array<Record<string, unknown>> = [];
	if (systemPrompt) messages.push({ role: 'system', content: systemPrompt });
	if (jsonMode && !schema) messages.push({ role: 'system', content: 'Return only a valid JSON object.' });
	messages.push({ role: 'user', content });
	const temperature = Number.isFinite(options.temperature) ? Math.max(0, Math.min(2, options.temperature)) : 0.3;
	const maxTokens = Number.isFinite(options.maxTokens) ? Math.max(1, Math.min(16000, Math.floor(options.maxTokens))) : 2000;
	let response: Response;
	try {
		response = await fetch('https://api.openai.com/v1/chat/completions', {
			method: 'POST',
			headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
			body: JSON.stringify({
				model: OPENAI_TEXT_MODEL,
				messages,
				temperature,
				max_completion_tokens: maxTokens,
				...(schema ? { response_format: { type: 'json_schema', json_schema: { name: 'result', strict: true, schema } } }
					: jsonMode ? { response_format: { type: 'json_object' } } : {})
			}),
			signal: AbortSignal.timeout(90000)
		});
	} catch (error) {
		if (error instanceof Error && ['TimeoutError', 'AbortError'].includes(error.name)) {
			throw new Error('OpenAI request timed out. Please retry.');
		}
		throw new Error('Could not reach OpenAI. Please retry.');
	}
	const result = await response.json().catch(() => null);
	if (!response.ok) {
		const detail = typeof result?.error?.message === 'string'
			? result.error.message.split(key).join('[redacted]').slice(0, 300) : 'Request failed';
		throw new Error(`OpenAI API error ${response.status}: ${detail}`);
	}
	const choice = result?.choices?.[0];
	if (choice?.message?.refusal || choice?.finish_reason === 'content_filter') {
		throw new Error('OpenAI could not process this request. Please review the input and retry.');
	}
	if (choice?.finish_reason === 'length') throw new Error('AI response was incomplete. Please retry with a shorter input.');
	const text = choice?.message?.content;
	if (typeof text !== 'string' || !text.trim()) throw new Error('OpenAI returned an empty response. Please retry.');
	return text.trim();
}
