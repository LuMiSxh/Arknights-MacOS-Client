import { extname } from 'node:path';

import { ContentError } from '../frontmatter.js';
import type { SiteRoute } from '../types.js';

export function siteRoute(path: string): SiteRoute {
	if (path.startsWith('//'))
		throw new ContentError(
			'routes',
			`protocol-relative routes are not allowed: ${path}`
		);
	if (!path.startsWith('/'))
		throw new ContentError('routes', `route must start with /: ${path}`);
	return path as SiteRoute;
}

export function humanize(segment: string): string {
	return segment
		.replaceAll(/[-_]+/g, ' ')
		.replace(/\b\w/g, (character) => character.toUpperCase());
}

export function slugify(segment: string): string {
	const slug = segment
		.normalize('NFKD')
		.replaceAll(/[\u0300-\u036f]/g, '')
		.toLowerCase()
		.replaceAll(/[^a-z0-9]+/g, '-')
		.replace(/^-+|-+$/g, '');
	if (!slug)
		throw new ContentError(
			'docs',
			`cannot derive a route segment from ${segment}`
		);
	return slug;
}

export function routeForRelative(relative: string): SiteRoute {
	const segments = relative.split('/');
	const file = segments.pop() ?? '';
	if (file.toLowerCase() === 'readme.md') {
		return siteRoute(
			segments.length ? `/${segments.map(slugify).join('/')}/` : '/'
		);
	}
	const stem = file.slice(0, -extname(file).length);
	return siteRoute(`/${[...segments, stem].map(slugify).join('/')}/`);
}

export function sourceName(relative: string): string {
	return relative ? `docs/${relative}` : 'docs';
}
