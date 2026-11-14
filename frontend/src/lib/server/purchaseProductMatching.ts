export type PurchaseProductName = { id: string; name: string };

function nameTokens(name: string): string[] {
	const normalized = name.normalize('NFKC').toLowerCase()
		.replace(/[\u064B-\u065F\u0670\u0640]/g, '')
		.replace(/[أإآ]/g, 'ا')
		.replace(/(\d)\s*(?:grams?|gms?|gm|g)\b/g, '$1 g')
		.replace(/(\d)\s*(?:millilitres?|milliliters?|ml)\b/g, '$1 ml')
		.replace(/(\d)\s*(?:litres?|liters?|ltr|lt|l)\b/g, '$1 l')
		.replace(/(\d)\s*(?:kilograms?|kgs?|kg)\b/g, '$1 kg')
		.replace(/(\d)(\p{L})/gu, '$1 $2')
		.replace(/[^\p{L}\p{N}.]+/gu, ' ');
	return [...new Set(normalized.split(/\s+/).filter((token) => token && token !== 'al'))];
}

function tokenSimilarity(left: string, right: string): number {
	if (left === right) return 1;
	if (/^\d/.test(left) || /^\d/.test(right)) return 0;
	const shorter = left.length < right.length ? left : right;
	const longer = left.length < right.length ? right : left;
	if (shorter.length >= 2 && longer.startsWith(shorter)) return 0.8;
	if (shorter.length < 4) return 0;
	const pairs = new Set(Array.from({ length: left.length - 1 }, (_, index) => left.slice(index, index + 2)));
	const otherPairs = new Set(Array.from({ length: right.length - 1 }, (_, index) => right.slice(index, index + 2)));
	const overlap = [...pairs].filter((pair) => otherPairs.has(pair)).length;
	const similarity = 2 * overlap / (pairs.size + otherPairs.size);
	return similarity >= 0.5 ? similarity : 0;
}

export function closestPurchasedProducts(names: string[], products: PurchaseProductName[]): string[][] {
	const catalog = products.map((product) => ({ ...product, tokens: nameTokens(product.name) }));
	const occurrences = new Map<string, number>();
	for (const product of catalog) {
		for (const token of product.tokens) occurrences.set(token, (occurrences.get(token) || 0) + 1);
	}
	const weight = (token: string) => 1 + Math.log((catalog.length + 1) / ((occurrences.get(token) || 0) + 1));
	function coverage(source: string[], target: string[]): number {
		const total = source.reduce((sum, token) => sum + weight(token), 0);
		if (!total || !target.length) return 0;
		return source.reduce((sum, token) => sum + weight(token)
			* Math.max(...target.map((other) => tokenSimilarity(token, other))), 0) / total;
	}
	return names.map((name) => {
		const tokens = nameTokens(name);
		if (!tokens.length) return [];
		return catalog.map((product) => ({
			id: product.id,
			score: 0.65 * coverage(tokens, product.tokens) + 0.35 * coverage(product.tokens, tokens)
		}))
			.filter((product) => product.score > 0)
			.sort((left, right) => right.score - left.score || left.id.localeCompare(right.id))
			.slice(0, 5)
			.map((product) => product.id);
	});
}
