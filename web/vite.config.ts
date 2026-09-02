import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import { sveltekit } from '@sveltejs/kit/vite';
import tailwindcss from '@tailwindcss/vite';
import { defineConfig } from 'vite';

const websiteRoot = fileURLToPath(new URL('.', import.meta.url));
const repositoryRoot = resolve(websiteRoot, '..');

export default defineConfig({
	plugins: [tailwindcss(), sveltekit()],
	server: {
		fs: {
			allow: [repositoryRoot]
		}
	}
});
