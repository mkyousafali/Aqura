export interface ApiSetupGuide {
 steps: string[];
 enable: string[];
 notes: string[];
 check: string;
 links: Array<{ label: string; url: string }>;
}

// Setup guidance checked against the linked provider documentation, September 2026.
export const API_SETUP_GUIDES: Record<string, ApiSetupGuide> = {
 openai: {
  steps: [
   'Open OpenAI Platform and select or create the project for Aqura.',
   'Configure API billing and usage limits for that project.',
   'Open API keys, create a secret key, and copy it.',
   'Use Add key or Replace key on the OpenAI card, save, and keep it Active.'
  ],
  enable: ['Allow the project and key to use Chat Completions and Images generation/editing.', 'Ensure the project can access the text and image models configured in Aqura.'],
  notes: ['API billing is managed in OpenAI Platform. Check its billing page before testing.', 'If an image request reports a model-access or verification error, follow the project dashboard instructions. Saving a key does not grant model access.'],
  check: 'Try a text rewrite, then generate a flyer image. Saving the key does not test it.',
  links: [
   { label: 'Create API key', url: 'https://platform.openai.com/api-keys' },
   { label: 'API billing', url: 'https://platform.openai.com/settings/organization/billing/overview' },
   { label: 'Official setup guide', url: 'https://developers.openai.com/api/docs/quickstart' },
   { label: 'Project access and limits', url: 'https://developers.openai.com/api/docs/guides/production-best-practices' }
  ]
 },
 google_gemini: {
  steps: [
   'Open Google AI Studio and sign in.',
   'Select a project, or import your Google Cloud project in the Projects page.',
   'Open API Keys and create a key for that project.',
   'Save it on the Google Gemini card and keep it Active.'
  ],
  enable: ['Gemini API (Generative Language API). New AI Studio keys are restricted to it by default.', 'Set up billing if required by your selected model or usage tier.'],
  notes: ['Use a separate Gemini key from the Google shared key.', 'For older standard keys, restrict API access to Generative Language API. Gemini rejects unrestricted standard keys.', 'This key serves automatic WhatsApp AI replies. WhatsApp account tokens and AI reply settings must also be configured.'],
  check: 'Send a message to a connected WhatsApp account with AI replies enabled and check the reply.',
  links: [
   { label: 'Create Gemini key', url: 'https://aistudio.google.com/apikey' },
   { label: 'Official key setup', url: 'https://ai.google.dev/gemini-api/docs/api-key' },
   { label: 'Billing and tiers', url: 'https://ai.google.dev/gemini-api/docs/billing' }
  ]
 },
 google: {
  steps: [
   'Open Google Cloud Console and select or create the Aqura project.',
   'Link a billing account. In APIs & Services > Library, enable the APIs below in the same project.',
   'Open APIs & Services > Credentials > Create credentials > API key.',
   'Under API restrictions, allow the listed APIs. Review the shared-key limitation below before choosing application restrictions.',
   'Save on the Google shared key card, keep it Active, and reload open map pages.'
  ],
  enable: ['Maps JavaScript API - map display.', 'Places API - the current location search uses the legacy Places widget.', 'Geocoding API - address lookup from the map.', 'Cloud Vision API - image text extraction.', 'Cloud Text-to-Speech API - order announcements.', 'Routes API - branch driving distances.'],
  notes: ['The current app shares this key between browser maps and server requests. Website-only restrictions can block server calls; server-IP-only restrictions can block customer maps. Separate browser and server keys require an app change. Do not solve this by making the key unrestricted.', 'If a new project cannot enable legacy Places, the location search needs an app update to Places API (New). Enabling only the new API does not change the existing widget.'],
  check: 'Test map display, location search, address lookup, receipt scanning, order audio and branch distance. Check billing, API restrictions and quotas if any fail.',
  links: [
   { label: 'Google Cloud Console', url: 'https://console.cloud.google.com/apis/dashboard' },
   { label: 'Key restrictions', url: 'https://developers.google.com/maps/api-security-best-practices' },
   { label: 'Places setup', url: 'https://developers.google.com/maps/documentation/javascript/legacy/place-autocomplete' },
   { label: 'Geocoding setup', url: 'https://developers.google.com/maps/documentation/javascript/geocoding' },
   { label: 'Vision setup', url: 'https://cloud.google.com/vision/docs/setup' },
   { label: 'Voice setup', url: 'https://cloud.google.com/text-to-speech/docs/before-you-begin' },
   { label: 'Routes setup', url: 'https://developers.google.com/maps/documentation/routes/get-api-key' }
  ]
 }
};
