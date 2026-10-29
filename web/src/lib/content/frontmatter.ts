import { parse as parseYaml } from 'yaml';
import type { DocumentMetadata } from './types.js';

export class ContentError extends Error {
	readonly source: string;

	constructor(source: string, message: string) {
		super(`${source}: ${message}`);
		this.name = 'ContentError';
		this.source = source;
	}
}

export interface ParsedMarkdown {
	metadata: DocumentMetadata;
	body: string;
}

const FRONTMATTER = /^\uFEFF?---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/;
const ERROR_CODE = /^[A-Z]{2}-[A-Z]{3}$/;
const AUDIENCES = new Set<DocumentMetadata['audience']>([
	'all',
	'developers',
	'users'
]);
const FRONTMATTER_KEYS = new Set<keyof DocumentMetadata>([
	'title',
	'description',
	'order',
	'hidden',
	'draft',
	'audience',
	'toc',
	'code',
	'domain'
]);

function isAudience(value: unknown): value is DocumentMetadata['audience'] {
	return (
		typeof value === 'string' &&
		AUDIENCES.has(value as DocumentMetadata['audience'])
	);
}

function requiredString(value: unknown, key: string, source: string): string {
	if (typeof value !== 'string' || value.trim() === '') {
		throw new ContentError(
			source,
			`frontmatter.${key} must be a non-empty string`
		);
	}
	return value.trim();
}

function optionalBoolean(
	value: unknown,
	key: string,
	source: string,
	fallback: boolean
): boolean {
	if (value === undefined) return fallback;
	if (typeof value !== 'boolean') {
		throw new ContentError(source, `frontmatter.${key} must be a boolean`);
	}
	return value;
}

function optionalNumber(
	value: unknown,
	key: string,
	source: string,
	fallback: number
): number {
	if (value === undefined) return fallback;
	if (typeof value !== 'number' || !Number.isFinite(value)) {
		throw new ContentError(
			source,
			`frontmatter.${key} must be a finite number`
		);
	}
	return value;
}

function optionalString(
	value: unknown,
	key: string,
	source: string
): string | undefined {
	if (value === undefined) return undefined;
	return requiredString(value, key, source);
}

interface RawFrontmatter {
	values: Record<string, unknown>;
	body: string;
}

function readFrontmatter(source: string, input: string): RawFrontmatter {
	const match = FRONTMATTER.exec(input);
	if (!match) {
		throw new ContentError(
			source,
			'a YAML frontmatter block is required at the beginning of the file'
		);
	}

	let parsed: unknown;
	try {
		parsed = parseYaml(match[1]);
	} catch (cause) {
		const message = cause instanceof Error ? cause.message : 'invalid YAML';
		throw new ContentError(
			source,
			`frontmatter is not valid YAML: ${message}`
		);
	}
	if (
		parsed === null ||
		typeof parsed !== 'object' ||
		Array.isArray(parsed)
	) {
		throw new ContentError(source, 'frontmatter must be a YAML mapping');
	}

	const body = input.slice(match[0].length);
	return { values: parsed as Record<string, unknown>, body };
}

export function parseFrontmatter(
	source: string,
	input: string
): ParsedMarkdown {
	const { values, body } = readFrontmatter(source, input);
	for (const key of Object.keys(values)) {
		if (!FRONTMATTER_KEYS.has(key as keyof DocumentMetadata)) {
			throw new ContentError(source, `unknown frontmatter key: ${key}`);
		}
	}
	const audience = values.audience ?? 'all';
	if (!isAudience(audience)) {
		throw new ContentError(
			source,
			'frontmatter.audience must be all, developers, or users'
		);
	}

	const code = optionalString(values.code, 'code', source);
	const domain = optionalString(values.domain, 'domain', source);
	if (code !== undefined && !ERROR_CODE.test(code)) {
		throw new ContentError(
			source,
			'frontmatter.code must match XX-XXX with uppercase English letters'
		);
	}
	if (code !== undefined && domain === undefined) {
		throw new ContentError(
			source,
			'frontmatter.domain is required for error pages'
		);
	}

	return {
		metadata: {
			title: requiredString(values.title, 'title', source),
			description: requiredString(
				values.description,
				'description',
				source
			),
			order: optionalNumber(values.order, 'order', source, 1000),
			hidden: optionalBoolean(values.hidden, 'hidden', source, false),
			draft: optionalBoolean(values.draft, 'draft', source, false),
			audience,
			toc: optionalBoolean(values.toc, 'toc', source, true),
			...(code === undefined ? {} : { code }),
			...(domain === undefined ? {} : { domain })
		},
		body
	};
}

export interface ParsedBlogMarkdown extends ParsedMarkdown {
	date: string;
}

const BLOG_FRONTMATTER_KEYS = new Set(['title', 'date', 'summary', 'draft']);
const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;

function isCalendarDate(value: string): boolean {
	if (!ISO_DATE.test(value)) return false;
	const [year, month, day] = value.split('-').map(Number);
	const date = new Date(Date.UTC(year, month - 1, day));
	return (
		date.getUTCFullYear() === year &&
		date.getUTCMonth() === month - 1 &&
		date.getUTCDate() === day
	);
}

/** Blog posts carry their own frontmatter; `summary` becomes the page description. */
export function parseBlogFrontmatter(
	source: string,
	input: string
): ParsedBlogMarkdown {
	const { values, body } = readFrontmatter(source, input);
	for (const key of Object.keys(values)) {
		if (!BLOG_FRONTMATTER_KEYS.has(key)) {
			throw new ContentError(source, `unknown frontmatter key: ${key}`);
		}
	}
	const date = requiredString(values.date, 'date', source);
	if (!isCalendarDate(date)) {
		throw new ContentError(
			source,
			'frontmatter.date must be an existing date in YYYY-MM-DD form'
		);
	}
	const title = requiredString(values.title, 'title', source);
	const summary = requiredString(values.summary, 'summary', source);
	const draft = optionalBoolean(values.draft, 'draft', source, false);
	return {
		date,
		body,
		metadata: {
			title,
			description: summary,
			order: 1000,
			hidden: false,
			draft,
			audience: 'all',
			toc: true
		}
	};
}
