// AI Chat Service using OpenAI API
import { supabase } from '$lib/utils/supabase';

export interface ChatMessage {
	role: 'user' | 'assistant' | 'system';
	content: string;
}

async function getOpenAIApiKey(): Promise<string | null> {
	// First try environment variable
	const envKey = import.meta.env.VITE_OPENAI_API_KEY;
	if (envKey) return envKey;

	// Try to get from Supabase settings table
	try {
		const { data, error } = await supabase
			.from('settings')
			.select('value')
			.eq('key', 'openai_api_key')
			.maybeSingle();

		if (!error && data?.value) return data.value;
	} catch (err) {
		console.error('Error fetching OpenAI API key:', err);
	}

	return null;
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
	const apiKey = await getOpenAIApiKey();
	if (!apiKey) {
		throw new Error('OpenAI API key not configured');
	}

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

	const response = await fetch('https://api.openai.com/v1/chat/completions', {
		method: 'POST',
		headers: {
			'Content-Type': 'application/json',
			Authorization: `Bearer ${apiKey}`
		},
		body: JSON.stringify({
			model: 'gpt-4o-mini',
			messages: [systemMessage, ...messages],
			max_tokens: 500,
			temperature: 0.7
		})
	});

	if (!response.ok) {
		const error = await response.json().catch(() => ({}));
		throw new Error(error?.error?.message || `API error: ${response.status}`);
	}

	const data = await response.json();
	return data.choices?.[0]?.message?.content?.trim() || 'No response';
}
