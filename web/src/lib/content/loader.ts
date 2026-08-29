import { readFileSync, readdirSync } from 'node:fs';
import { basename, dirname, extname, posix, resolve } from 'node:path';
import {
	parseFrontmatter,
	ContentError,
	type ParsedMarkdown
} from './frontmatter.js';
import {
	collectMarkdownLinks,
	renderMarkdown,
	type RenderedMarkdown
} from './markdown.js';
import type {
	ContentDirectory,
	ContentDocument,
	ContentIndex,
	ContentNeighbors,
	ContentNode,
	ContentSummary,
	DocumentMetadata
} from './types.js';
import { repositoryUrl } from '../site.js';
import { siteHref } from './markdown.js';

// SvelteKit bundles server modules into `.svelte-kit/output`; use the build
// working directory instead of an import-relative URL that changes after bundling.
const repositoryRoot =
	basename(process.cwd()) === 'web'
		? resolve(process.cwd(), '..')
		: process.cwd();
const docsRoot = resolve(repositoryRoot, 'docs');
const changelogPath = resolve(repositoryRoot, 'CHANGELOG.md');
const ignoredDirectory = 'superpowers';

interface SourceDocument extends ParsedMarkdown {
	relative: string;
	source: string;
	isReadme: boolean;
	route: string;
	rendered?: RenderedMarkdown;
}

interface DirectoryDraft {
	path: string;
	readme?: SourceDocument;
	documents: SourceDocument[];
	children: DirectoryDraft[];
	metadata?: DocumentMetadata;
}

let cached: ContentIndex | undefined;

function humanize(segment: string): string {
	return segment
		.replaceAll(/[-_]+/g, ' ')
		.replace(/\b\w/g, (character) => character.toUpperCase());
}

function slugify(segment: string): string {
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

function routeForRelative(relative: string): string {
	const segments = relative.split('/');
	const file = segments.pop() ?? '';
	if (file.toLowerCase() === 'readme.md') {
		return segments.length ? `/${segments.map(slugify).join('/')}/` : '/';
	}
	const stem = file.slice(0, -extname(file).length);
	const routeSegments = [...segments, stem].map(slugify);
	return `/${routeSegments.join('/')}/`;
}

function sourceName(relative: string): string {
	return relative ? `docs/${relative}` : 'docs';
}

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

function readSources(): SourceDocument[] {
	const codes = new Map<string, string>();
	return walkMarkdown(docsRoot).map((relative) => {
		if (basename(relative).toLowerCase() === 'index.md') {
			throw new ContentError(
				sourceName(relative),
				'use README.md for a directory landing page'
			);
		}
		const source = sourceName(relative);
		const input = readFileSync(resolve(docsRoot, relative), 'utf8');
		const parsed = parseFrontmatter(source, input);
		if (parsed.metadata.draft) {
			throw new ContentError(source, 'draft content cannot be published');
		}
		if (parsed.metadata.code) {
			const previous = codes.get(parsed.metadata.code);
			if (previous) {
				throw new ContentError(
					source,
					`duplicate error code ${parsed.metadata.code} already used by ${previous}`
				);
			}
			codes.set(parsed.metadata.code, source);
		}
		return {
			...parsed,
			relative,
			source,
			isReadme: basename(relative).toLowerCase() === 'readme.md',
			route: routeForRelative(relative)
		};
	});
}

function createDirectory(path: string): DirectoryDraft {
	return { path, documents: [], children: [] };
}

function directoryFor(root: DirectoryDraft, path: string): DirectoryDraft {
	if (!path) return root;
	let current = root;
	let built = '';
	for (const segment of path.split('/')) {
		built = built ? `${built}/${segment}` : segment;
		let child = current.children.find(
			(candidate) => candidate.path === built
		);
		if (!child) {
			child = createDirectory(built);
			current.children.push(child);
		}
		current = child;
	}
	return current;
}

function sortSummaries(items: ContentSummary[]): ContentSummary[] {
	return items.sort(
		(left, right) =>
			left.order - right.order ||
			left.title.localeCompare(right.title, 'en', { sensitivity: 'base' })
	);
}

function summaryFor(node: ContentNode): ContentSummary {
	return {
		kind: node.kind,
		route: node.route,
		title: node.title,
		description: node.description,
		order: node.order,
		hidden: node.hidden,
		audience: node.audience,
		...(node.code ? { code: node.code } : {})
	};
}

function buildDirectory(
	draft: DirectoryDraft,
	renderedBySource: Map<string, ContentDocument>,
	byRoute: Map<string, ContentNode>
): ContentDirectory {
	const readme = draft.readme;
	const metadata = readme?.metadata ?? {
		title: draft.path
			? humanize(draft.path.split('/').at(-1) ?? draft.path)
			: 'Documentation',
		description: draft.path
			? `Guides and reference material in the ${humanize(draft.path.split('/').at(-1) ?? draft.path)} section.`
			: 'Guides and reference material for Arknights Client.',
		order: draft.path ? 1000 : 0,
		hidden: false,
		draft: false,
		audience: 'all',
		toc: true
	};
	const route = draft.path
		? `/${draft.path.split('/').map(slugify).join('/')}/`
		: '/';
	const intro = readme ? renderedBySource.get(readme.relative) : undefined;
	const childDirectories = draft.children
		.map((child) => buildDirectory(child, renderedBySource, byRoute))
		.filter((child) => child.children.length || child.html);
	const childDocuments = draft.documents
		.filter((document) => !document.isReadme)
		.map((document) => renderedBySource.get(document.relative))
		.filter((document): document is ContentDocument => Boolean(document));
	const children = sortSummaries([
		...childDirectories.map(summaryFor),
		...childDocuments.map(summaryFor)
	]);
	const directory: ContentDirectory = {
		kind: 'directory',
		route,
		title: metadata.title,
		description: metadata.description,
		order: metadata.order,
		hidden: metadata.hidden,
		audience: metadata.audience,
		html: intro?.html ?? '',
		headings: intro?.headings ?? [],
		children,
		toc: metadata.toc,
		...(readme ? { introSource: readme.source } : {})
	};
	if (route !== '/') {
		if (byRoute.has(route))
			throw new ContentError(
				sourceName(draft.path),
				`duplicate route ${route}`
			);
		byRoute.set(route, directory);
	}
	return directory;
}

function splitHref(href: string): { path: string; fragment?: string } {
	const hash = href.indexOf('#');
	if (hash < 0) return { path: href };
	return { path: href.slice(0, hash), fragment: href.slice(hash + 1) };
}

function decodePath(value: string): string {
	try {
		return decodeURIComponent(value);
	} catch {
		return value;
	}
}

function isExternal(href: string): boolean {
	return /^(?:https?:|mailto:)/i.test(href);
}

function linkTarget(
	source: string,
	href: string
): { key?: string; route?: string; fragment?: string; external?: string } {
	const { path, fragment } = splitHref(href);
	if (isExternal(href) || href.startsWith('//')) return { external: href };
	if (!path) return { key: source, fragment };
	if (path.startsWith('#')) return { key: source, fragment: path.slice(1) };
	if (path.startsWith('/')) {
		const route = path.replace(/\/{2,}/g, '/');
		return { route: route.endsWith('/') ? route : `${route}/`, fragment };
	}

	const sourceRepositoryPath =
		source === 'CHANGELOG.md' ? source : `docs/${source}`;
	const targetRepositoryPath = posix.normalize(
		posix.join(posix.dirname(sourceRepositoryPath), decodePath(path))
	);
	if (targetRepositoryPath === 'README.md') return { route: '/', fragment };
	if (targetRepositoryPath === 'CHANGELOG.md')
		return { route: '/changelog/', fragment };
	if (targetRepositoryPath.startsWith('docs/')) {
		if (!targetRepositoryPath.toLowerCase().endsWith('.md')) {
			return {
				external: `${repositoryUrl}/blob/main/${targetRepositoryPath}${fragment ? `#${fragment}` : ''}`
			};
		}
		const key = targetRepositoryPath.slice('docs/'.length);
		return { key, fragment };
	}
	if (
		!targetRepositoryPath.startsWith('../') &&
		!targetRepositoryPath.startsWith('/')
	) {
		return {
			external: `${repositoryUrl}/blob/main/${targetRepositoryPath}${fragment ? `#${fragment}` : ''}`
		};
	}
	return { fragment };
}

function resolvedHref(
	source: string,
	href: string,
	sourceRoutes: Map<string, string>
): string | undefined {
	const target = linkTarget(source, href);
	if (target.external) return target.external;
	if (target.route)
		return `${siteHref(target.route)}${target.fragment ? `#${target.fragment}` : ''}`;
	if (!target.key) return target.fragment ? `#${target.fragment}` : undefined;
	const route = sourceRoutes.get(target.key);
	if (!route) return undefined;
	return `${siteHref(route)}${target.fragment ? `#${target.fragment}` : ''}`;
}

function validateLinks(
	document: SourceDocument,
	sourceRoutes: Map<string, string>,
	renderedBySource: Map<string, ContentDocument>
): void {
	for (const href of collectMarkdownLinks(document.body)) {
		if (/^(?:https?:|mailto:)/i.test(href)) continue;
		if (href.startsWith('//')) {
			throw new ContentError(
				document.source,
				`protocol-relative links are not allowed: ${href}`
			);
		}
		const target = linkTarget(
			document.relative === 'CHANGELOG.md'
				? 'CHANGELOG.md'
				: document.relative,
			href
		);
		if (target.external) continue;
		if (target.route) {
			if (
				target.route !== '/changelog/' &&
				target.route !== '/' &&
				![...sourceRoutes.values()].includes(target.route)
			) {
				throw new ContentError(
					document.source,
					`link target does not exist: ${href}`
				);
			}
		} else if (target.key) {
			const route = sourceRoutes.get(target.key);
			if (!route)
				throw new ContentError(
					document.source,
					`link target does not exist: ${href}`
				);
			if (target.fragment) {
				const targetDocument = renderedBySource.get(target.key);
				const heading = targetDocument?.headings.some(
					(candidate) => candidate.id === target.fragment
				);
				if (!heading && target.fragment !== 'top') {
					throw new ContentError(
						document.source,
						`heading anchor does not exist: ${href}`
					);
				}
			}
		} else if (target.fragment) {
			const heading = document.rendered?.headings.some(
				(candidate) => candidate.id === target.fragment
			);
			if (!heading && target.fragment !== 'top') {
				throw new ContentError(
					document.source,
					`heading anchor does not exist: ${href}`
				);
			}
		} else if (!isExternal(href)) {
			throw new ContentError(
				document.source,
				`unsafe or unresolved link: ${href}`
			);
		}
	}
}

function renderSourceDocuments(
	documents: SourceDocument[],
	sourceRoutes: Map<string, string>
): Map<string, ContentDocument> {
	const rendered = new Map<string, ContentDocument>();
	for (const document of documents) {
		const titleHeading = /^\s*#\s+([^\r\n]+)(?:\r?\n|$)/.exec(
			document.body
		);
		const websiteBody =
			titleHeading?.[1].trim() === document.metadata.title
				? document.body.slice(titleHeading[0].length)
				: document.body;
		document.rendered = renderMarkdown(document.source, websiteBody, {
			source: document.relative,
			resolve: (href, source) => resolvedHref(source, href, sourceRoutes)
		});
		const page: ContentDocument = {
			kind: 'document',
			route: document.route,
			title: document.metadata.title,
			description: document.metadata.description,
			order: document.metadata.order,
			hidden: document.metadata.hidden,
			audience: document.metadata.audience,
			html: document.rendered.html,
			headings: document.rendered.headings,
			source: document.source,
			toc: document.metadata.toc,
			...(document.metadata.code ? { code: document.metadata.code } : {})
		};
		rendered.set(document.relative, page);
	}
	return rendered;
}

function loadIndex(): ContentIndex {
	const documents = readSources();
	const changelogInput = readFileSync(changelogPath, 'utf8');
	const changelogParsed = parseFrontmatter('CHANGELOG.md', changelogInput);
	if (changelogParsed.metadata.draft)
		throw new ContentError(
			'CHANGELOG.md',
			'draft content cannot be published'
		);
	const changelogSource: SourceDocument = {
		...changelogParsed,
		relative: 'CHANGELOG.md',
		source: 'CHANGELOG.md',
		isReadme: false,
		route: '/changelog/'
	};

	const root = createDirectory('');
	const sourceRoutes = new Map<string, string>();
	for (const document of documents) {
		sourceRoutes.set(document.relative, document.route);
		const parentPath =
			dirname(document.relative) === '.'
				? ''
				: dirname(document.relative);
		const parent = directoryFor(root, parentPath);
		const parentRoute = parentPath
			? `/${parentPath.split('/').map(slugify).join('/')}/`
			: '/';
		sourceRoutes.set(parentPath, parentRoute);
		sourceRoutes.set(`${parentPath}/`, parentRoute);
		if (document.isReadme) {
			if (parent.readme)
				throw new ContentError(
					document.source,
					'duplicate README.md in directory'
				);
			parent.readme = document;
			parent.metadata = document.metadata;
		} else {
			parent.documents.push(document);
		}
	}
	root.readme = documents.find(
		(document) => document.relative.toLowerCase() === 'readme.md'
	);

	const byRoute = new Map<string, ContentNode>();
	sourceRoutes.set('CHANGELOG.md', '/changelog/');
	const renderedBySource = renderSourceDocuments(
		[...documents, changelogSource],
		sourceRoutes
	);
	for (const document of documents) {
		if (document.isReadme) continue;
		const page = renderedBySource.get(document.relative);
		if (!page) continue;
		if (byRoute.has(page.route))
			throw new ContentError(
				document.source,
				`duplicate route ${page.route}`
			);
		byRoute.set(page.route, page);
	}
	const changelog = renderedBySource.get('CHANGELOG.md');
	if (!changelog)
		throw new ContentError('CHANGELOG.md', 'failed to render changelog');
	byRoute.set(changelog.route, changelog);

	for (const document of [...documents, changelogSource])
		validateLinks(document, sourceRoutes, renderedBySource);
	const rootDirectory = buildDirectory(root, renderedBySource, byRoute);
	const directories = [...byRoute.values()].filter(
		(node): node is ContentDirectory => node.kind === 'directory'
	);
	const publicDocuments = [...byRoute.values()].filter(
		(node): node is ContentDocument =>
			node.kind === 'document' && node.route !== '/changelog/'
	);

	return {
		root: rootDirectory,
		documents: publicDocuments,
		directories,
		byRoute,
		bySource: renderedBySource,
		changelog
	};
}

export function getContent(): ContentIndex {
	return (cached ??= loadIndex());
}

export function contentEntries(): string[] {
	return [...getContent().byRoute.keys()].filter(
		(route) => route !== '/changelog/'
	);
}

export function contentAtRoute(route: string): ContentNode | undefined {
	return getContent().byRoute.get(route.endsWith('/') ? route : `${route}/`);
}

export function contentNeighbors(route: string): ContentNeighbors {
	const { root, directories } = getContent();
	for (const directory of [root, ...directories]) {
		const children = directory.children.filter((entry) => !entry.hidden);
		const index = children.findIndex((entry) => entry.route === route);
		if (index < 0) continue;
		return {
			...(index > 0 ? { previous: children[index - 1] } : {}),
			...(index + 1 < children.length
				? { next: children[index + 1] }
				: {})
		};
	}
	return {};
}
