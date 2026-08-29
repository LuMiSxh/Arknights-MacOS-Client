import { getContent } from '$lib/content/loader.js';

export const prerender = true;
export const trailingSlash = 'always';

export function load() {
	const { byRoute, root } = getContent();
	return {
		navigation: root.children
			.filter((entry) => !entry.hidden)
			.map((entry) => {
				const node = byRoute.get(entry.route);
				return {
					...entry,
					children:
						node?.kind === 'directory'
							? node.children.filter((child) => !child.hidden)
							: []
				};
			})
	};
}
