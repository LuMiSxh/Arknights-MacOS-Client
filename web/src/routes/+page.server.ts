import { getContent } from '$lib/content/loader/index.js';

export const prerender = true;

export function load() {
	const { blog, release } = getContent();
	const [latest] = blog;
	return {
		release,
		post: latest && {
			route: latest.route,
			title: latest.title,
			summary: latest.description,
			date: latest.date
		}
	};
}
