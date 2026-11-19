import { error } from '@sveltejs/kit';
import { breadcrumbTrail } from '$lib/content/breadcrumbs.js';
import {
	contentAtRoute,
	contentEntries,
	contentNeighbors,
	getContent
} from '$lib/content/loader/index.js';

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
	const breadcrumbs = breadcrumbTrail(route).map((crumb) => ({
		...crumb,
		title: byRoute.get(crumb.route)?.title ?? crumb.title
	}));
	return { content, neighbors: contentNeighbors(route), breadcrumbs };
}
