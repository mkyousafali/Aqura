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

		const response = await fetch('https://api.openai.com/v1/chat/completions', {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json',
				'Authorization': `Bearer ${apiKey}`
			},
			body: JSON.stringify({
				model: 'gpt-3.5-turbo',
				messages: [
					{
						role: 'system',
						content: 'You are a professional translator. Provide only the translation without any additional explanation or text.'
					},
					{
						role: 'user',
						content: prompt
					}
				],
				temperature: 0.3,
				max_tokens: 200
			})
		});

		if (!response.ok) {
			const error = await response.json();
			throw new Error(error.error?.message || 'Translation failed');
		}

		const data = await response.json();
		const translation = data.choices[0]?.message?.content?.trim() || '';
		
		return translation;
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
		if (!apiKey) return text;

		const response = await fetch('https://api.openai.com/v1/chat/completions', {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json',
				'Authorization': `Bearer ${apiKey}`
			},
			body: JSON.stringify({
				model: 'gpt-3.5-turbo',
				messages: [
					{
						role: 'system',
						content: 'You are a spelling and grammar corrector. Fix any spelling mistakes in the given English text. Return ONLY the corrected text, nothing else. Keep the same meaning and style. If the text is already correct, return it as-is.'
					},
					{
						role: 'user',
						content: text
					}
				],
				temperature: 0.1,
				max_tokens: 200
			})
		});

		if (!response.ok) return text;

		const data = await response.json();
		return data.choices[0]?.message?.content?.trim() || text;
	} catch {
		return text;
	}
}

async function getOpenAIApiKey(): Promise<string | null> {
	// First try environment variable
	const envKey = import.meta.env.VITE_OPENAI_API_KEY;
	if (envKey) {
		return envKey;
	}

	// Try to get from Supabase settings table
	try {
		const { supabase } = await import('$lib/utils/supabase');
		const { data, error } = await supabase
			.from('settings')
			.select('value')
			.eq('key', 'openai_api_key')
			.maybeSingle();

		if (!error && data?.value) {
			return data.value;
		}
	} catch (err) {
		console.error('Error fetching OpenAI API key:', err);
	}

	return null;
}
