export function isAlmaraiSupplier(...names: unknown[]): boolean {
	return names.some((name) => typeof name === 'string'
		&& /\bal[\s-]*marai\b|المراعي/i.test(name.replace(/[\u064B-\u065F\u0670\u0640]/g, '')));
}
