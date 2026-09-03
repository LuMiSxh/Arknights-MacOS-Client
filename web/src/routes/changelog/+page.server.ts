import { getContent } from '$lib/content/loader/index.js';

export const prerender = true;

export function load() {
	return { content: getContent().changelog };
}
