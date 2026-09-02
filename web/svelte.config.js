import adapter from '@sveltejs/adapter-static';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

/** @type {import('@sveltejs/kit').Config} */
const config = {
	preprocess: vitePreprocess(),
	kit: {
		adapter: adapter({
			fallback: '404.html',
			precompress: true,
			strict: true
		}),
		paths: {
			base: process.env.BASE_PATH ?? ''
		},
		prerender: {
			// A broken internal link is a content error and must fail a release build.
			handleHttpError: 'fail'
		}
	}
};

export default config;
