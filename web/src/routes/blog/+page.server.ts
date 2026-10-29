import { getContent } from '$lib/content/loader/index.js';

export const prerender = true;

export function load() {
	const posts = getContent().blog.map(
		({ route, title, description, date, draft }) => ({
			route,
			title,
			summary: description,
			date,
			draft
		})
	);
	return { posts };
}
