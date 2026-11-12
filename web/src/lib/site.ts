export const repositoryUrl =
	'https://github.com/LuMiSxh/Arknights-MacOS-Client';
export const releaseUrl = `${repositoryUrl}/releases/latest`;
export const contactFormUrl = 'https://tally.so/r/gbbPYd';
// The form reads these values from its hidden `topic` field (`?topic=<topic>`).
export const contactTopics: Readonly<Record<string, string>> = {
	testing: 'Testing',
	translation: 'Translation'
};
export const siteOrigin = 'https://lumisxh.github.io';

export function normalizeBasePath(value: string): string {
	if (!value || value === '/' || /^\.\.?(?:\/|$)/.test(value)) return '';
	return `/${value.replace(/^\/+|\/+$/g, '')}`;
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
