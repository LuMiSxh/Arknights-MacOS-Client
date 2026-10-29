import { ContentError } from './frontmatter.js';

export function mapping(
	value: unknown,
	source: string,
	where: string
): Record<string, unknown> {
	if (value === null || typeof value !== 'object' || Array.isArray(value)) {
		throw new ContentError(source, `${where} must be a mapping`);
	}
	return value as Record<string, unknown>;
}

export function rejectUnknownKeys(
	values: Record<string, unknown>,
	allowed: Set<string>,
	source: string,
	where: string
): void {
	for (const key of Object.keys(values)) {
		if (!allowed.has(key))
			throw new ContentError(source, `unknown ${where} key: ${key}`);
	}
}
