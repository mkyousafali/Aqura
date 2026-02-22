// Google Cloud Text-to-Speech Service
import { supabase } from '$lib/utils/supabase';
import { get } from 'svelte/store';
import { currentUser } from '$lib/utils/persistentAuth';

let cachedApiKey: string | null = null;

async function getGoogleTTSApiKey(): Promise<string | null> {
	if (cachedApiKey) return cachedApiKey;

	// First try system_api_keys table (DB-first)
	try {
		const { data, error } = await supabase
			.from('system_api_keys')
			.select('api_key')
			.eq('service_name', 'google')
			.eq('is_active', true)
			.single();

		if (!error && data?.api_key) {
			cachedApiKey = data.api_key;
			return data.api_key;
		}
	} catch (err) {
		console.error('[TTS] Error fetching API key from system_api_keys:', err);
	}

	// Fallback to environment variable
	const envKey = import.meta.env.VITE_GOOGLE_TTS_API_KEY;
	if (envKey) {
		cachedApiKey = envKey;
		return envKey;
	}

	return null;
}

// ── Available voice options ──
export interface VoiceOption {
	id: string;
	name: string;
	nameAr: string;
	languageCode: string;
	voiceName: string;
	ssmlGender: 'FEMALE' | 'MALE';
	speakingRate: number;
	pitch: number;
}

export const VOICE_OPTIONS: VoiceOption[] = [
	// English voices
	{ id: 'en-neural2-a', name: '🇬🇧 British Woman (Neural)', nameAr: '🇬🇧 بريطانية (عصبي)', languageCode: 'en-GB', voiceName: 'en-GB-Neural2-A', ssmlGender: 'FEMALE', speakingRate: 1.1, pitch: 1.0 },
	{ id: 'en-neural2-c', name: '🇬🇧 British Woman 2 (Neural)', nameAr: '🇬🇧 بريطانية ٢ (عصبي)', languageCode: 'en-GB', voiceName: 'en-GB-Neural2-C', ssmlGender: 'FEMALE', speakingRate: 1.1, pitch: 1.0 },
	{ id: 'en-neural2-f', name: '🇬🇧 British Woman 3 (Neural)', nameAr: '🇬🇧 بريطانية ٣ (عصبي)', languageCode: 'en-GB', voiceName: 'en-GB-Neural2-F', ssmlGender: 'FEMALE', speakingRate: 1.1, pitch: 1.0 },
	{ id: 'en-wavenet-a', name: '🇬🇧 British Woman (Wavenet)', nameAr: '🇬🇧 بريطانية (ويفنت)', languageCode: 'en-GB', voiceName: 'en-GB-Wavenet-A', ssmlGender: 'FEMALE', speakingRate: 1.1, pitch: 1.0 },
	{ id: 'en-us-neural2-c', name: '🇺🇸 American Woman (Neural)', nameAr: '🇺🇸 أمريكية (عصبي)', languageCode: 'en-US', voiceName: 'en-US-Neural2-C', ssmlGender: 'FEMALE', speakingRate: 1.1, pitch: 1.0 },
	{ id: 'en-us-neural2-e', name: '🇺🇸 American Woman 2 (Neural)', nameAr: '🇺🇸 أمريكية ٢ (عصبي)', languageCode: 'en-US', voiceName: 'en-US-Neural2-E', ssmlGender: 'FEMALE', speakingRate: 1.1, pitch: 1.0 },
	{ id: 'en-gb-neural2-b', name: '🇬🇧 British Man (Neural)', nameAr: '🇬🇧 بريطاني (عصبي)', languageCode: 'en-GB', voiceName: 'en-GB-Neural2-B', ssmlGender: 'MALE', speakingRate: 1.05, pitch: -1.0 },
	{ id: 'en-us-neural2-d', name: '🇺🇸 American Man (Neural)', nameAr: '🇺🇸 أمريكي (عصبي)', languageCode: 'en-US', voiceName: 'en-US-Neural2-D', ssmlGender: 'MALE', speakingRate: 1.05, pitch: -1.0 },
	// Arabic voices
	{ id: 'ar-wavenet-a', name: '🇸🇦 Arabic Woman (Wavenet)', nameAr: '🇸🇦 عربية ١ (ويفنت)', languageCode: 'ar-XA', voiceName: 'ar-XA-Wavenet-A', ssmlGender: 'FEMALE', speakingRate: 0.95, pitch: 0.5 },
	{ id: 'ar-wavenet-d', name: '�� Arabic Woman 2 (Wavenet)', nameAr: '�� عربية ٢ (ويفنت)', languageCode: 'ar-XA', voiceName: 'ar-XA-Wavenet-D', ssmlGender: 'FEMALE', speakingRate: 0.95, pitch: 0.5 },
	{ id: 'ar-standard-a', name: '�� Arabic Woman 3 (Standard)', nameAr: '�� عربية ٣ (عادي)', languageCode: 'ar-XA', voiceName: 'ar-XA-Standard-A', ssmlGender: 'FEMALE', speakingRate: 0.95, pitch: 0.5 },
	{ id: 'ar-standard-d', name: '🇸🇦 Arabic Woman 4 (Standard)', nameAr: '🇸🇦 عربية ٤ (عادي)', languageCode: 'ar-XA', voiceName: 'ar-XA-Standard-D', ssmlGender: 'FEMALE', speakingRate: 0.95, pitch: 0.5 },
	{ id: 'ar-standard-c', name: '🇸🇦 Arabic Woman 5 (Standard)', nameAr: '🇸🇦 عربية ٥ (عادي)', languageCode: 'ar-XA', voiceName: 'ar-XA-Standard-C', ssmlGender: 'FEMALE', speakingRate: 0.95, pitch: 0.5 },
	{ id: 'ar-wavenet-b', name: '�� Arabic Man (Wavenet)', nameAr: '�� عربي ذكر (ويفنت)', languageCode: 'ar-XA', voiceName: 'ar-XA-Wavenet-B', ssmlGender: 'MALE', speakingRate: 0.95, pitch: -2.0 },
	{ id: 'ar-wavenet-c', name: '�� Arabic Man 2 (Wavenet)', nameAr: '�� عربي ذكر ٢ (ويفنت)', languageCode: 'ar-XA', voiceName: 'ar-XA-Wavenet-C', ssmlGender: 'MALE', speakingRate: 0.95, pitch: -2.0 },
];

// Default voice IDs per locale
const DEFAULT_VOICE_ID: Record<string, string> = {
	en: 'en-neural2-a',
	ar: 'ar-wavenet-d'
};

// Currently selected voice per locale
let selectedVoiceId: Record<string, string> = { ...DEFAULT_VOICE_ID };
let voicePrefsLoaded = false;
let saveInProgress = false;
let pendingSave: { lang: string; voiceId: string } | null = null;

export function getVoicesForLocale(locale: string): VoiceOption[] {
	const lang = locale === 'ar' ? 'ar' : 'en';
	return VOICE_OPTIONS.filter(v => v.languageCode.startsWith(lang === 'ar' ? 'ar' : 'en'));
}

export function getSelectedVoiceId(locale: string): string {
	const lang = locale === 'ar' ? 'ar' : 'en';
	return selectedVoiceId[lang] || DEFAULT_VOICE_ID[lang];
}

export function setSelectedVoiceId(locale: string, voiceId: string) {
	const lang = locale === 'ar' ? 'ar' : 'en';
	selectedVoiceId[lang] = voiceId;
	// Save to DB in background
	saveVoicePreference(lang, voiceId);
}

// Load user voice preferences from Supabase
export async function loadVoicePreferences(): Promise<void> {
	if (voicePrefsLoaded) return;
	try {
		const user = get(currentUser);
		if (!user?.id) return;
		const { data, error } = await supabase
			.from('user_voice_preferences')
			.select('locale, voice_id')
			.eq('user_id', user.id);
		if (!error && data) {
			data.forEach(row => {
				// Verify the voice ID exists
				if (VOICE_OPTIONS.some(v => v.id === row.voice_id)) {
					selectedVoiceId[row.locale] = row.voice_id;
				}
			});
			voicePrefsLoaded = true;
		}
	} catch (err) {
		console.error('[TTS] Error loading voice preferences:', err);
	}
}

// Save voice preference to Supabase
async function saveVoicePreference(lang: string, voiceId: string): Promise<void> {
	// Queue save if one is already in progress
	if (saveInProgress) {
		pendingSave = { lang, voiceId };
		return;
	}
	saveInProgress = true;
	try {
		const user = get(currentUser);
		if (!user?.id) return;
		console.log('[TTS] Saving voice pref for user:', user.id, 'locale:', lang, 'voice:', voiceId);

		// Try update first
		const { data: updated, error: updateErr } = await supabase
			.from('user_voice_preferences')
			.update({ voice_id: voiceId, updated_at: new Date().toISOString() })
			.eq('user_id', user.id)
			.eq('locale', lang)
			.select();

		if (updateErr) {
			console.error('[TTS] Update error:', updateErr);
		}

		// If no row was updated, insert new one
		if (!updated || updated.length === 0) {
			const { error: insertErr } = await supabase
				.from('user_voice_preferences')
				.insert({
					user_id: user.id,
					locale: lang,
					voice_id: voiceId
				});
			if (insertErr) {
				console.error('[TTS] Insert error:', insertErr);
			}
		}
	} catch (err) {
		console.error('[TTS] Error saving voice preference:', err);
	} finally {
		saveInProgress = false;
		// Process pending save if any
		if (pendingSave) {
			const next = pendingSave;
			pendingSave = null;
			saveVoicePreference(next.lang, next.voiceId);
		}
	}
}

interface TTSRequest {
	input: { text?: string; ssml?: string };
	voice: {
		languageCode: string;
		name: string;
		ssmlGender: string;
	};
	audioConfig: {
		audioEncoding: string;
		speakingRate: number;
		pitch: number;
		volumeGainDb: number;
		effectsProfileId: string[];
	};
}

let currentAudio: HTMLAudioElement | null = null;

export function stopSpeaking() {
	if (currentAudio) {
		currentAudio.pause();
		currentAudio.src = '';
		currentAudio = null;
	}
}

export async function speakWithGoogleTTS(
	text: string,
	locale: string = 'en',
	voiceIdOverride?: string
): Promise<void> {
	const apiKey = await getGoogleTTSApiKey();
	if (!apiKey) {
		console.warn('[TTS] No Google TTS API key — falling back to browser speech');
		fallbackBrowserSpeak(text, locale);
		return;
	}

	// Stop any current playback
	stopSpeaking();

	// Clean emojis from text
	const clean = text.replace(/\p{Emoji_Presentation}|\p{Extended_Pictographic}/gu, '')
		// Fix app name pronunciation — prevent letter-by-letter spelling
		.replace(/\bAQURA\b/gi, 'Akura')
		.replace(/\bأكورا\b/g, 'أكورا')
		.replace(/\bأيربن\b/g, 'أُربَن')
		// Replace separator lines
		.replace(/[─]{2,}/g, '')
		.trim();
	if (!clean) return;

	// Convert newlines to SSML breaks for natural pauses
	const ssmlText = '<speak>' + clean
		.split('\n')
		.filter(line => line.trim())
		.map(line => line.trim().replace(/\s*-\s*/g, '<break time="400ms"/>'))
		.join('<break time="600ms"/>') + '</speak>';

	const isArabic = locale === 'ar';
	const voiceId = voiceIdOverride || getSelectedVoiceId(locale);
	const voiceConfig = VOICE_OPTIONS.find(v => v.id === voiceId) || VOICE_OPTIONS[0];

	const requestBody: TTSRequest = {
		input: { ssml: ssmlText },
		voice: {
			languageCode: voiceConfig.languageCode,
			name: voiceConfig.voiceName,
			ssmlGender: voiceConfig.ssmlGender
		},
		audioConfig: {
			audioEncoding: 'MP3',
			speakingRate: voiceConfig.speakingRate,
			pitch: voiceConfig.pitch,
			volumeGainDb: 2.0,
			effectsProfileId: ['small-bluetooth-speaker-class-device']
		}
	};

	try {
		const response = await fetch(
			`https://texttospeech.googleapis.com/v1/text:synthesize?key=${apiKey}`,
			{
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify(requestBody)
			}
		);

		if (!response.ok) {
			const err = await response.json().catch(() => ({}));
			console.error('[TTS] Google TTS API error:', err);
			fallbackBrowserSpeak(text, locale);
			return;
		}

		const data = await response.json();
		if (!data.audioContent) {
			console.error('[TTS] No audio content in response');
			fallbackBrowserSpeak(text, locale);
			return;
		}

		// Play the audio and wait for it to finish
		const audioSrc = `data:audio/mp3;base64,${data.audioContent}`;
		currentAudio = new Audio(audioSrc);
		currentAudio.volume = 1;
		await new Promise<void>((resolve, reject) => {
			if (!currentAudio) { resolve(); return; }
			currentAudio.onended = () => resolve();
			currentAudio.onerror = () => reject(new Error('Audio playback error'));
			currentAudio.play().catch(reject);
		});
	} catch (err) {
		console.error('[TTS] Error calling Google TTS:', err);
		fallbackBrowserSpeak(text, locale);
	}
}

// Browser fallback if no API key or API error
function fallbackBrowserSpeak(text: string, locale: string) {
	if (!window.speechSynthesis) return;
	window.speechSynthesis.cancel();
	const clean = text.replace(/\p{Emoji_Presentation}|\p{Extended_Pictographic}/gu, '').trim();
	if (!clean) return;

	const utter = new SpeechSynthesisUtterance(clean);
	utter.lang = locale === 'ar' ? 'ar-SA' : 'en-GB';
	utter.rate = 1.25;
	utter.pitch = 1.4;
	utter.volume = 1;

	const voices = window.speechSynthesis.getVoices();
	const femaleKeywords = [
		'libby', 'maisie', 'sonia', 'hazel', 'jenny', 'aria', 'sara',
		'susan', 'zira', 'samantha', 'karen', 'moira', 'fiona', 'kate',
		'serena', 'stephanie', 'emma', 'amy', 'joanna', 'female',
		'hoda', 'salma', 'laila', 'zahra', 'maryam', 'fatima', 'amira'
	];
	const isArabic = locale === 'ar';
	const langPat = isArabic ? /^ar/i : /^en/i;
	const voice = voices.find(v => langPat.test(v.lang) && femaleKeywords.some(k => v.name.toLowerCase().includes(k)))
		|| voices.find(v => langPat.test(v.lang));
	if (voice) {
		utter.voice = voice;
		utter.lang = voice.lang;
	}
	window.speechSynthesis.speak(utter);
}

export function isTTSAvailable(): boolean {
	return true; // Always available — has browser fallback
}
