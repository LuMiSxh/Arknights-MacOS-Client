import { error } from '@sveltejs/kit';
import {
	contentAtRoute,
	contentEntries,
	contentNeighbors,
	getContent
} from '$lib/content/loader/index.js';
import type { SiteRoute } from '$lib/content/types.js';

export const prerender = true;

export function entries() {
	return contentEntries()
		.filter((route) => route !== '/')
		.map((route) => ({
			path: route.replace(/^\//, '').replace(/\/$/, '')
		}));
}

export function load({ params }: { params: { path?: string } }) {
	const route = `/${params.path ?? ''}/`.replace(/\/{2,}/g, '/');
	const content = contentAtRoute(route);
	if (!content) error(404, 'Documentation page not found');
	const { byRoute } = getContent();
	const segments = route.split('/').filter(Boolean);
	const breadcrumbs = segments.map((segment, index) => {
		const breadcrumbRoute =
			`/${segments.slice(0, index + 1).join('/')}/` as SiteRoute;
		return {
			title:
				byRoute.get(breadcrumbRoute)?.title ??
				segment
					.replaceAll('-', ' ')
					.replace(/\b\w/g, (character) => character.toUpperCase()),
			route: breadcrumbRoute
		};
	});
	return { content, neighbors: contentNeighbors(route), breadcrumbs };
}
