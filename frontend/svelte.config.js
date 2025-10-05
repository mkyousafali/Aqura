import adapter from '@sveltejs/adapter-auto';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

/** @type {import('@sveltejs/kit').Config} */
const config = {
	preprocess: vitePreprocess(),
	kit: {
		adapter: adapter(),
		alias: {
			$lib: './src/lib',
			$components: './src/lib/components',
			$stores: './src/lib/stores',
			$utils: './src/lib/utils',
			$types: './src/lib/types',
			$i18n: './src/lib/i18n'
		},
		prerender: {
			handleHttpError: 'warn'
		},
		serviceWorker: {
			register: false // We'll use vite-plugin-pwa instead
		}
	}
};

export default config;
