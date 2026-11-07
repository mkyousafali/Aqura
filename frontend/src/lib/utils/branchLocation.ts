interface BranchLocation {
	name_en?: string | null;
	name_ar?: string | null;
	location_en?: string | null;
	location_ar?: string | null;
	location_url?: string | null;
}

/** Build the preview from the saved destination, never a directions viewport. */
export function branchMapEmbedUrl(branch: BranchLocation, language = 'en'): string {
	let query = [branch.name_en || branch.name_ar, branch.location_en || branch.location_ar]
		.filter(Boolean).join(', ');
	try {
		const saved = new URL(branch.location_url || '');
		const googleHost = /(^|\.)google\.(?:com|com\.sa|co\.uk)$/.test(saved.hostname);
		if (googleHost && saved.pathname.startsWith('/maps/embed')) {
			saved.protocol = 'https:';
			return saved.href;
		}
		if (googleHost) {
			const destination = saved.searchParams.get('destination') || saved.searchParams.get('q') || saved.searchParams.get('query');
			const coordinates = saved.pathname.match(/!1d(-?\d+(?:\.\d+)?)!2d(-?\d+(?:\.\d+)?)/);
			const placeCoordinates = saved.pathname.match(/!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)/);
			const place = saved.pathname.match(/\/maps\/dir\/[^/]*\/([^/@]+)/) || saved.pathname.match(/\/maps\/place\/([^/@]+)/);
			if (destination) query = destination;
			// Named businesses retain Google's listing card and Open in Maps
			// control; a coordinates-only query shows just a generic map pin.
			else if (place) query = decodeURIComponent(place[1].replace(/\+/g, ' '));
			else if (coordinates) query = `${coordinates[2]},${coordinates[1]}`;
			else if (placeCoordinates) query = `${placeCoordinates[1]},${placeCoordinates[2]}`;
		}
	} catch { /* Short or malformed map links fall back to the saved branch address. */ }
	const embed = new URL('https://maps.google.com/maps');
	embed.searchParams.set('q', query);
	embed.searchParams.set('output', 'embed');
	embed.searchParams.set('hl', language === 'ar' ? 'ar' : 'en');
	embed.searchParams.set('z', '15');
	return embed.href;
}
