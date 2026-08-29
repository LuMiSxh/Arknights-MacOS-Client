export const repositoryUrl =
	'https://github.com/LuMiSxh/Arknights-MacOS-Client';
export const releaseUrl = `${repositoryUrl}/releases/latest`;

export function normalizeBasePath(value: string): string {
	if (!value || value === '/') return '';
	return `/${value.replace(/^\/+|\/+$/g, '')}`;
}
