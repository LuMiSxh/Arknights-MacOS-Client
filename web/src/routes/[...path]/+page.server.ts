import { error } from '@sveltejs/kit';
import {
	contentAtRoute,
	contentEntries,
	contentNeighbors
} from '$lib/content/loader.js';

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
	return { content, neighbors: contentNeighbors(route) };
}
