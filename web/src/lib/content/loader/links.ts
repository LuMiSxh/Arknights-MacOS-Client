import { posix } from 'node:path';

import { repositoryUrl } from '../../site.js';
import { ContentError } from '../frontmatter.js';
import { collectMarkdownLinks, renderMarkdown, siteHref } from '../markdown.js';
import type { ContentDocument, SiteRoute } from '../types.js';
import type { SourceDocument } from './model.js';
import { siteRoute } from './routes.js';

interface LinkTarget {
	key?: string;
	route?: SiteRoute;
	fragment?: string;
	external?: string;
	unsafe?: string;
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
	return /^(?:https:|mailto:)/i.test(href);
}

function isUnsupportedScheme(href: string): boolean {
	return href.startsWith('//') || /^[a-z][a-z\d+.-]*:/i.test(href);
}

function linkTarget(source: string, href: string): LinkTarget {
	const { path, fragment } = splitHref(href);
	if (isExternal(href)) return { external: href };
	if (isUnsupportedScheme(href)) return { unsafe: href };
	if (!path) return { key: source, fragment };
	if (path.startsWith('/')) {
		const route = path.replace(/\/{2,}/g, '/');
		return {
			route: siteRoute(route.endsWith('/') ? route : `${route}/`),
			fragment
		};
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
		return { key: targetRepositoryPath.slice('docs/'.length), fragment };
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
	sourceRoutes: Map<string, SiteRoute>
): string | undefined {
	const target = linkTarget(source, href);
	if (target.external) return target.external;
	if (target.route) {
		return `${siteHref(target.route)}${target.fragment ? `#${target.fragment}` : ''}`;
	}
	if (!target.key) return target.fragment ? `#${target.fragment}` : undefined;
	const route = sourceRoutes.get(target.key);
	if (!route) return undefined;
	return `${siteHref(route)}${target.fragment ? `#${target.fragment}` : ''}`;
}

export function renderSourceDocuments(
	documents: SourceDocument[],
	sourceRoutes: Map<string, SiteRoute>
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
		rendered.set(document.relative, {
			kind: 'document',
			route: document.route,
			title: document.metadata.title,
			description: document.metadata.description,
			order: document.metadata.order,
			hidden: document.metadata.hidden,
			audience: document.metadata.audience,
			html: document.rendered.html,
			headings: document.rendered.headings,
			toc: document.metadata.toc,
			...(document.metadata.code ? { code: document.metadata.code } : {})
		});
	}
	return rendered;
}

export function validateLinks(
	document: SourceDocument,
	sourceRoutes: Map<string, SiteRoute>,
	renderedBySource: Map<string, ContentDocument>
): void {
	for (const href of collectMarkdownLinks(document.body)) {
		if (isExternal(href)) continue;
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
		if (target.unsafe) {
			throw new ContentError(
				document.source,
				`unsafe link scheme is not allowed: ${target.unsafe}`
			);
		}
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
			if (target.fragment && target.fragment !== 'top') {
				const heading = [...renderedBySource.values()]
					.find((candidate) => candidate.route === target.route)
					?.headings.some(
						(candidate) => candidate.id === target.fragment
					);
				if (!heading) {
					throw new ContentError(
						document.source,
						`heading anchor does not exist: ${href}`
					);
				}
			}
		} else if (target.key) {
			const route = sourceRoutes.get(target.key);
			if (!route)
				throw new ContentError(
					document.source,
					`link target does not exist: ${href}`
				);
			if (target.fragment) {
				const heading = renderedBySource
					.get(target.key)
					?.headings.some(
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
		} else {
			throw new ContentError(
				document.source,
				`unsafe or unresolved link: ${href}`
			);
		}
	}
}
