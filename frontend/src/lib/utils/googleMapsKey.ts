// Maps keys come from system_api_keys via the server, never a build-time environment key.
export async function fetchGoogleMapsKey(): Promise<string> {
	const response = await fetch('/api/maps-key', { cache: 'no-store' });
	if (!response.ok) throw new Error('Google Maps API key unavailable');
	const result = await response.json();
	if (!result?.success || typeof result.apiKey !== 'string' || !result.apiKey.trim()) {
		throw new Error('Google Maps API key not configured');
	}
	return result.apiKey.trim();
}
