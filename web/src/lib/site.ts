export const repositoryUrl =
	'https://github.com/LuMiSxh/Arknights-MacOS-Client';
export const releaseUrl = `${repositoryUrl}/releases/latest`;
export const contactFormUrl = 'https://tally.so/r/gbbPYd';
// The form reads these values from its hidden `topic` field (`?topic=<topic>`).
export const contactTopics = {
	testing: 'Testing',
	translation: 'Translation'
} as const;

export type ContactTopic = keyof typeof contactTopics;

const siteOrigin = 'https://lumisxh.github.io';

export function normalizeBasePath(value: string): string {
	if (!value || value === '/' || /^\.\.?(?:\/|$)/.test(value)) return '';
	return `/${value.replace(/^\/+|\/+$/g, '')}`;
}

/**
 * Resolve the site base path from `BASE_PATH`. The caller supplies `base` from
 * `$app/paths`, or `''` where the app paths module is unavailable.
 */
export function resolveBasePath(fallback: string): string {
	const configured =
		typeof process === 'undefined' ? undefined : process.env.BASE_PATH;
	return normalizeBasePath(configured ?? fallback);
}

export function absoluteSiteUrl(route: string, basePath: string): string {
	const configuredBasePath = normalizeBasePath(basePath);
	const safeRoute =
		route.startsWith('/') &&
		!route.startsWith('//') &&
		!route.includes('\\')
			? route
			: '/';
	const routeWithoutBase =
		configuredBasePath &&
		(safeRoute === configuredBasePath ||
			safeRoute.startsWith(`${configuredBasePath}/`))
			? safeRoute.slice(configuredBasePath.length) || '/'
			: safeRoute;
	return new URL(`${configuredBasePath}${routeWithoutBase}`, siteOrigin).href;
}
