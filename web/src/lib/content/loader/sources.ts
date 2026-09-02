import { readFileSync, readdirSync } from 'node:fs';
import { basename, resolve } from 'node:path';

import { ContentError, parseFrontmatter } from '../frontmatter.js';
import type { SourceDocument, SupportCodeRegistryEntry } from './model.js';
import { docsRoot, supportCodeRegistryPath } from './paths.js';
import { routeForRelative, sourceName } from './routes.js';

const ignoredDirectory = 'superpowers';
const registrySource = 'docs/help/errors/registry.json';

function walkMarkdown(directory: string, prefix = ''): string[] {
	const files: string[] = [];
	for (const entry of readdirSync(directory, { withFileTypes: true })) {
		if (entry.name.startsWith('.') || entry.isSymbolicLink()) continue;
		if (!prefix && entry.name === ignoredDirectory) continue;

		const relative = prefix ? `${prefix}/${entry.name}` : entry.name;
		const absolute = resolve(directory, entry.name);
		if (entry.isDirectory()) {
			files.push(...walkMarkdown(absolute, relative));
		} else if (entry.isFile() && entry.name.toLowerCase().endsWith('.md')) {
			files.push(relative);
		}
	}
	return files.sort();
}

function readSupportCodeRegistry(): SupportCodeRegistryEntry[] {
	let parsed: unknown;
	try {
		parsed = JSON.parse(readFileSync(supportCodeRegistryPath, 'utf8'));
	} catch (cause) {
		throw new ContentError(
			registrySource,
			cause instanceof Error ? cause.message : 'invalid JSON'
		);
	}
	if (!Array.isArray(parsed)) {
		throw new ContentError(registrySource, 'registry must be an array');
	}
	return parsed.map((entry, index) => {
		if (
			entry === null ||
			typeof entry !== 'object' ||
			typeof (entry as Record<string, unknown>).code !== 'string' ||
			typeof (entry as Record<string, unknown>).domain !== 'string'
		) {
			throw new ContentError(
				registrySource,
				`entry ${index + 1} must contain string code and domain fields`
			);
		}
		return entry as SupportCodeRegistryEntry;
	});
}

function validateSupportCodeRegistry(
	documents: Map<string, { source: string; domain: string; route: string }>
): void {
	const registry = new Map<string, SupportCodeRegistryEntry>();
	for (const entry of readSupportCodeRegistry()) {
		if (!/^[A-Z]+$/.test(entry.code) || entry.domain.trim() === '') {
			throw new ContentError(
				registrySource,
				`invalid support-code entry ${entry.code}`
			);
		}
		if (registry.has(entry.code)) {
			throw new ContentError(
				registrySource,
				`duplicate registry code ${entry.code}`
			);
		}
		registry.set(entry.code, entry);
	}

	for (const [code, entry] of registry) {
		const document = documents.get(code);
		if (!document) {
			throw new ContentError(
				registrySource,
				`support code ${code} has no documentation page`
			);
		}
		const expectedRoute = `/help/errors/${code.toLowerCase()}/`;
		if (document.route !== expectedRoute) {
			throw new ContentError(
				document.source,
				`support code ${code} must use route ${expectedRoute}`
			);
		}
		if (document.domain !== entry.domain) {
			throw new ContentError(
				document.source,
				`frontmatter.domain must match registry domain ${entry.domain}`
			);
		}
	}

	for (const [code, document] of documents) {
		if (!registry.has(code)) {
			throw new ContentError(
				document.source,
				`support code ${code} is missing from registry.json`
			);
		}
	}
}

export function readSources(): SourceDocument[] {
	const codes = new Map<
		string,
		{ source: string; domain: string; route: string }
	>();
	const documents = walkMarkdown(docsRoot).map((relative) => {
		if (basename(relative).toLowerCase() === 'index.md') {
			throw new ContentError(
				sourceName(relative),
				'use README.md for a directory landing page'
			);
		}
		const source = sourceName(relative);
		const parsed = parseFrontmatter(
			source,
			readFileSync(resolve(docsRoot, relative), 'utf8')
		);
		if (parsed.metadata.draft) {
			throw new ContentError(source, 'draft content cannot be published');
		}
		if (parsed.metadata.code) {
			const previous = codes.get(parsed.metadata.code);
			if (previous) {
				throw new ContentError(
					source,
					`duplicate error code ${parsed.metadata.code} already used by ${previous.source}`
				);
			}
			codes.set(parsed.metadata.code, {
				source,
				domain: parsed.metadata.domain ?? '',
				route: routeForRelative(relative)
			});
		}
		return {
			...parsed,
			relative,
			source,
			isReadme: basename(relative).toLowerCase() === 'readme.md',
			route: routeForRelative(relative)
		};
	});
	validateSupportCodeRegistry(codes);
	return documents;
}
