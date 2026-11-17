import type { SiteRoute } from './types.js';

export interface Breadcrumb {
	title: string;
	route: SiteRoute;
}

function humanizeSegment(segment: string): string {
	return segment
		.replaceAll('-', ' ')
		.replace(/\b\w/g, (character) => character.toUpperCase());
}

/**
 * Build the breadcrumb trail for a route. `lastTitle` replaces the final
 * segment's title when the page already knows its own title.
 */
export function breadcrumbTrail(
	route: string,
	lastTitle?: string
): Breadcrumb[] {
	const segments = route.split('/').filter(Boolean);
	return segments.map((segment, index) => {
		const crumbRoute: SiteRoute = `/${segments.slice(0, index + 1).join('/')}/`;
		return {
			title:
				index === segments.length - 1 && lastTitle !== undefined
					? lastTitle
					: humanizeSegment(segment),
			route: crumbRoute
		};
	});
}
