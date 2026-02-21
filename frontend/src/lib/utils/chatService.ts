// AI Chat Service — OpenAI with Gemini fallback
import { supabase } from '$lib/utils/supabase';

export interface ChatMessage {
	role: 'user' | 'assistant' | 'system';
	content: string;
}

/** Returns { openaiKey, geminiKey } from system_api_keys table */
async function getAIKeys(): Promise<{ openaiKey: string | null; geminiKey: string | null }> {
	try {
		const { data } = await supabase
			.from('system_api_keys')
			.select('service_name, api_key, is_active')
			.in('service_name', ['openai', 'google']);

		const rows: any[] = data || [];
		const openaiRow = rows.find((r) => r.service_name === 'openai' && r.is_active && r.api_key);
		const googleRow = rows.find((r) => r.service_name === 'google' && r.is_active && r.api_key);
		return {
			openaiKey: openaiRow?.api_key || import.meta.env.VITE_OPENAI_API_KEY || null,
			geminiKey: googleRow?.api_key || import.meta.env.VITE_GOOGLE_API_KEY || null
		};
	} catch {
		return {
			openaiKey: import.meta.env.VITE_OPENAI_API_KEY || null,
			geminiKey: import.meta.env.VITE_GOOGLE_API_KEY || null
		};
	}
}

/** Call Gemini as fallback when OpenAI is unavailable */
async function sendGeminiMessage(messages: ChatMessage[], geminiKey: string): Promise<string> {
	const contents = messages
		.filter((m) => m.role !== 'system')
		.map((m) => ({ role: m.role === 'assistant' ? 'model' : 'user', parts: [{ text: m.content }] }));
	const systemMsg = messages.find((m) => m.role === 'system');
	const body: any = { contents };
	if (systemMsg) body.systemInstruction = { parts: [{ text: systemMsg.content }] };

	const res = await fetch(
		`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiKey}`,
		{ method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }
	);
	if (!res.ok) throw new Error(`Gemini error: ${res.status}`);
	const d = await res.json();
	return d.candidates?.[0]?.content?.parts?.[0]?.text?.trim() || 'No response';
}

// Fetch the AI chat guide from database
async function getAIChatGuide(): Promise<string> {
	try {
		const { data, error } = await supabase
			.from('ai_chat_guide')
			.select('guide_text')
			.order('id', { ascending: true })
			.limit(1)
			.maybeSingle();

		if (!error && data?.guide_text) return data.guide_text;
	} catch (err) {
		console.error('Error fetching AI chat guide:', err);
	}
	return '';
}

export async function sendChatMessage(
	messages: ChatMessage[],
	locale: string = 'en'
): Promise<string> {
	const { openaiKey, geminiKey } = await getAIKeys();

	// Fetch the custom guide from database
	const customGuide = await getAIChatGuide();

	const baseInstruction = locale === 'ar'
		? 'أنت مساعد ذكي ودود اسمك "أكورا". أجب بإيجاز ووضوح باللغة العربية. ساعد المستخدم في أي شيء يسأل عنه. كن محترفًا ولطيفًا.\n\nقاعدة مهمة جداً: عندما توجه المستخدم لأي قسم أو زر أو صفحة في النظام، يجب أن تذكر دائماً أن الوصول لهذه الميزة يتطلب صلاحية الزر من المسؤول (الأدمن). مثال: "يمكنك الوصول إلى هذا القسم إذا كان لديك صلاحية من المسؤول."'
		: 'You are a smart and friendly AI assistant named "Aqura". Answer concisely and clearly in English. Help the user with anything they ask. Be professional and kind.\n\nIMPORTANT RULE: Whenever you direct the user to any section, button, page, or feature in the system, you MUST always mention that accessing it requires button permission from the admin. Example: "You can access this feature only if the admin has granted you the button permission."';

	const systemContent = customGuide
		? `${baseInstruction}\n\n--- GUIDE (You MUST follow these instructions) ---\n${customGuide}\n--- END GUIDE ---`
		: baseInstruction;

	const systemMessage: ChatMessage = {
		role: 'system',
		content: systemContent
	};

	const allMessages = [systemMessage, ...messages];

	// Try OpenAI first, fall back to Gemini
	if (openaiKey) {
		try {
			const response = await fetch('https://api.openai.com/v1/chat/completions', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${openaiKey}` },
				body: JSON.stringify({ model: 'gpt-4o-mini', messages: allMessages, max_tokens: 500, temperature: 0.7 })
			});
			if (response.ok) {
				const data = await response.json();
				return data.choices?.[0]?.message?.content?.trim() || 'No response';
			}
		} catch { /* fall through to Gemini */ }
	}

	// Gemini fallback
	if (geminiKey) return sendGeminiMessage(allMessages, geminiKey);

	throw new Error('No AI provider configured. Add OpenAI or Google key in API Keys Manager.');
}
