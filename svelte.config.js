import adapter from '@sveltejs/adapter-static';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

/** @type {import('@sveltejs/kit').Config} */
const config = {
	preprocess: vitePreprocess(),
	kit: {
		adapter: adapter({
			pages: 'build',
			assets: 'build',
			fallback: '404.html',
			precompress: false,
			strict: true
		}),
		paths: {
			// Leer fuer lokale Entwicklung und eigene Domain.
			// Fuer GitHub Pages im Unterpfad: BASE_PATH=/die-akademie npm run build
			base: process.env.BASE_PATH ?? ''
		}
	}
};

export default config;
