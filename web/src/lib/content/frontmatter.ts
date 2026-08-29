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
const ERROR_CODE = /^AKC-[A-Z][A-Z0-9]*$/;
const AUDIENCES = new Set(['all', 'developers', 'users']);

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

export function parseFrontmatter(
	source: string,
	input: string
): ParsedMarkdown {
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

	const values = parsed as Record<string, unknown>;
	const audience = values.audience ?? 'all';
	if (typeof audience !== 'string' || !AUDIENCES.has(audience)) {
		throw new ContentError(
			source,
			'frontmatter.audience must be all, developers, or users'
		);
	}

	const code = values.code;
	if (
		code !== undefined &&
		(typeof code !== 'string' || !ERROR_CODE.test(code))
	) {
		throw new ContentError(source, 'frontmatter.code must match AKC-WORD');
	}
	if (
		code !== undefined &&
		(typeof values.domain !== 'string' || values.domain.trim() === '')
	) {
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
			audience: audience as DocumentMetadata['audience'],
			toc: optionalBoolean(values.toc, 'toc', source, true),
			...(code === undefined ? {} : { code }),
			...(values.domain === undefined
				? {}
				: { domain: values.domain as string })
		},
		body: input.slice(match[0].length)
	};
}
