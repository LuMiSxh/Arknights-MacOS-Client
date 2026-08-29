import { getContent } from '$lib/content/loader.js';

export const prerender = true;

export function load() {
	return { content: getContent().changelog };
}
