import { getContent } from '$lib/content/loader/index.js';

export const prerender = true;
export const trailingSlash = 'always';

export function load({ url }: { url: URL }) {
	const { byRoute, root } = getContent();
	return {
		pathname: url.pathname,
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
