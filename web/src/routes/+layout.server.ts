import { getContent } from '$lib/content/loader.js';

export const prerender = true;
export const trailingSlash = 'always';

export function load() {
	const { root } = getContent();
	return {
		navigation: root.children.filter((entry) => !entry.hidden)
	};
}
