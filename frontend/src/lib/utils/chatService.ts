// AI Chat Service — Gemini only (keys from DB)
import { supabase } from '$lib/utils/supabase';

export interface ChatMessage {
	role: 'user' | 'assistant' | 'system';
	content: string;
}

/** Returns Gemini API key from system_api_keys table */
async function getGeminiKey(): Promise<string | null> {
	try {
		const { data } = await supabase
			.from('system_api_keys')
			.select('api_key')
			.eq('service_name', 'google')
			.eq('is_active', true)
			.maybeSingle();

		return data?.api_key || null;
	} catch {
		return null;
	}
}

/** Call Gemini API */
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

	// Use Gemini API
	const geminiKey = await getGeminiKey();
	if (!geminiKey) {
		throw new Error('No AI provider configured. Add a Google API key in API Keys Manager.');
	}
	return sendGeminiMessage(allMessages, geminiKey);
}
