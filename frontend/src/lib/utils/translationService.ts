// Translation service using OpenAI API
export interface TranslationOptions {
	text: string;
	targetLanguage: 'ar' | 'en';
	sourceLanguage?: 'ar' | 'en';
}

export async function translateText(options: TranslationOptions): Promise<string> {
	const { text, targetLanguage, sourceLanguage } = options;

	if (!text || text.trim() === '') {
		return '';
	}

	try {
		// Get OpenAI API key from environment or settings
		const apiKey = await getOpenAIApiKey();
		
		if (!apiKey) {
			throw new Error('OpenAI API key not configured');
		}

		const prompt = sourceLanguage
			? `Translate the following text from ${sourceLanguage === 'en' ? 'English' : 'Arabic'} to ${targetLanguage === 'en' ? 'English' : 'Arabic'}. Provide only the translation without any additional text:\n\n${text}`
			: `Translate the following text to ${targetLanguage === 'en' ? 'English' : 'Arabic'}. Provide only the translation without any additional text:\n\n${text}`;

		if (apiKey) {
			try {
				const response = await fetch('https://api.openai.com/v1/chat/completions', {
					method: 'POST',
					headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}` },
					body: JSON.stringify({
						model: 'gpt-3.5-turbo',
						messages: [
							{ role: 'system', content: 'You are a professional translator. Provide only the translation without any additional explanation or text.' },
							{ role: 'user', content: prompt }
						],
						temperature: 0.3, max_tokens: 200
					})
				});
				if (response.ok) {
					const data = await response.json();
					return data.choices[0]?.message?.content?.trim() || '';
				}
			} catch { /* fall through to Gemini */ }
		}

		// Gemini fallback
		const geminiKey = await getGeminiKey();
		if (geminiKey) return translateWithGemini(prompt, geminiKey);

		throw new Error('No AI translation provider configured');
	} catch (error) {
		console.error('Translation error:', error);
		throw error;
	}
}

export async function correctSpelling(text: string): Promise<string> {
	if (!text || text.trim() === '') {
		return text;
	}

	try {
		const apiKey = await getOpenAIApiKey();
		if (apiKey) {
			try {
				const response = await fetch('https://api.openai.com/v1/chat/completions', {
					method: 'POST',
					headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}` },
					body: JSON.stringify({
						model: 'gpt-3.5-turbo',
						messages: [
							{ role: 'system', content: 'You are a spelling and grammar corrector. Fix any spelling mistakes in the given English text. Return ONLY the corrected text, nothing else. Keep the same meaning and style. If the text is already correct, return it as-is.' },
							{ role: 'user', content: text }
						],
						temperature: 0.1, max_tokens: 200
					})
				});
				if (response.ok) {
					const data = await response.json();
					return data.choices[0]?.message?.content?.trim() || text;
				}
			} catch { /* fall through to Gemini */ }
		}
		// Gemini fallback for spell check
		const geminiKey = await getGeminiKey();
		if (geminiKey) {
			const corrected = await translateWithGemini(
				`Fix spelling mistakes in this English text. Return ONLY the corrected text, nothing else:\n\n${text}`,
				geminiKey
			);
			return corrected || text;
		}
		return text;
	} catch {
		return text;
	}
}

async function getOpenAIApiKey(): Promise<string | null> {
	try {
		const { supabase } = await import('$lib/utils/supabase');
		const { data } = await supabase
			.from('system_api_keys')
			.select('api_key')
			.eq('service_name', 'openai')
			.eq('is_active', true)
			.maybeSingle();
		if (data?.api_key) return data.api_key;
	} catch { /* ignore */ }
	// Fallback to .env
	return import.meta.env.VITE_OPENAI_API_KEY || null;
}

async function getGeminiKey(): Promise<string | null> {
	try {
		const { supabase } = await import('$lib/utils/supabase');
		const { data } = await supabase
			.from('system_api_keys')
			.select('api_key')
			.eq('service_name', 'google')
			.eq('is_active', true)
			.maybeSingle();
		if (data?.api_key) return data.api_key;
	} catch { /* ignore */ }
	return import.meta.env.VITE_GOOGLE_API_KEY || null;
}

async function translateWithGemini(prompt: string, geminiKey: string): Promise<string> {
	const res = await fetch(
		`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiKey}`,
		{
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({ contents: [{ role: 'user', parts: [{ text: prompt }] }] })
		}
	);
	if (!res.ok) throw new Error(`Gemini error: ${res.status}`);
	const d = await res.json();
	return d.candidates?.[0]?.content?.parts?.[0]?.text?.trim() || '';
}
