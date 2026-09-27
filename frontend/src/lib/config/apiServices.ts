export interface ApiServiceUsage {
	name: string;
	title: string;
	icon: string;
	description: string;
	usage: Array<{ api: string; usedIn: string }>;
}

export const API_SERVICES: ApiServiceUsage[] = [
	{
		name: 'openai', title: 'OpenAI', icon: '🤖',
		description: 'OpenAI: flyer design and artwork, text tools, translations, HR warnings, receipt and document analysis.',
		usage: [
			{ api: 'Text and translation', usedIn: 'HR incidents, investigations and resolutions; WhatsApp manual translation; product names and groups' },
			{ api: 'Image and document analysis', usedIn: 'Scan Request; Receiving Records bill check; Start Receiving; Gift Wheel; Surprise Box' },
			{ api: 'Flyer design and images', usedIn: 'AI Flyer Generator; offer names, themes, backgrounds, artwork and editing' },
			{ api: 'Button analysis', usedIn: 'Sidebar/button detection' }
		]
	},
	{
		name: 'google_gemini', title: 'Google Gemini', icon: '💬',
		description: 'Google Gemini: WhatsApp automatic AI replies only.',
		usage: [{ api: 'Gemini', usedIn: 'WhatsApp AI Reply bot (automatic replies)' }]
	},
	{
		name: 'google', title: 'Google shared key', icon: '🌐',
		description: 'Google APIs: Maps/Places, Vision OCR, Text-to-Speech and Routes.',
		usage: [
			{ api: 'Maps / Places', usedIn: 'Location Picker; Location Map Display' },
			{ api: 'Vision OCR', usedIn: 'Start Receiving; Gift Wheel; Surprise Box; Product Request; Near Expiry' },
			{ api: 'Text-to-Speech', usedIn: 'Customer Orders Manager: English and Arabic new-order announcements' },
			{ api: 'Routes', usedIn: 'Customer start page: driving distance to branches' }
		]
	}
];

export const RETIRED_API_SERVICES = ['google_search_engine_id', 'pixabay'];
export const findApiService = (name: string) => API_SERVICES.find(service => service.name === name);
