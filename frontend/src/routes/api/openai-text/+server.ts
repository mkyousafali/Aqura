import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { generateOpenAIText } from '$lib/server/openaiText';

export const POST: RequestHandler = async ({ request }) => {
	let body;
	try { body = await request.json(); } catch { return json({ error: 'Invalid JSON body' }, { status: 400 }); }
	if (!body || typeof body.prompt !== 'string' || !body.prompt.trim()
		|| (body.systemPrompt !== undefined && typeof body.systemPrompt !== 'string')
		|| (body.temperature !== undefined && (typeof body.temperature !== 'number' || !Number.isFinite(body.temperature)))
		|| (body.maxTokens !== undefined && (typeof body.maxTokens !== 'number' || !Number.isFinite(body.maxTokens)))
		|| (body.jsonMode !== undefined && typeof body.jsonMode !== 'boolean')) {
		return json({ error: 'Invalid text generation request' }, { status: 400 });
	}
	try {
		const text = await generateOpenAIText({
			prompt: body.prompt, systemPrompt: body.systemPrompt,
			temperature: body.temperature, maxTokens: body.maxTokens, jsonMode: body.jsonMode
		});
		return json({ text });
	} catch (error) {
		return json({ error: error instanceof Error ? error.message : 'Text generation failed' }, { status: 500 });
	}
};
