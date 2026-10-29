import { readFileSync } from 'node:fs';
import { dirname } from 'node:path';

import { ContentError, parseFrontmatter } from '../frontmatter.js';
import type {
	BlogPost,
	ContentDirectory,
	ContentIndex,
	ContentNeighbors,
	ContentNode,
	SiteRoute
} from '../types.js';
import { readBlogSources } from './blog.js';
import { renderSourceDocuments, validateLinks } from './links.js';
import type { SourceDocument } from './model.js';
import { changelogPath } from './paths.js';
import { siteRoute, slugify } from './routes.js';
import { readSources } from './sources.js';
import { buildDirectory, createDirectory, directoryFor } from './tree.js';

let cached: ContentIndex | undefined;

function loadIndex(): ContentIndex {
	const documents = readSources();
	const posts = readBlogSources();
	const changelogParsed = parseFrontmatter(
		'CHANGELOG.md',
		readFileSync(changelogPath, 'utf8')
	);
	if (changelogParsed.metadata.draft) {
		throw new ContentError(
			'CHANGELOG.md',
			'draft content cannot be published'
		);
	}
	const changelogSource: SourceDocument = {
		...changelogParsed,
		relative: 'CHANGELOG.md',
		source: 'CHANGELOG.md',
		isReadme: false,
		route: '/changelog/'
	};

	const root = createDirectory('');
	const sourceRoutes = new Map<string, SiteRoute>();
	for (const document of documents) {
		sourceRoutes.set(document.relative, document.route);
		const parentPath =
			dirname(document.relative) === '.'
				? ''
				: dirname(document.relative);
		const parent = directoryFor(root, parentPath);
		const parentRoute = siteRoute(
			parentPath
				? `/${parentPath.split('/').map(slugify).join('/')}/`
				: '/'
		);
		sourceRoutes.set(parentPath, parentRoute);
		sourceRoutes.set(`${parentPath}/`, parentRoute);
		if (document.isReadme) {
			if (parent.readme) {
				throw new ContentError(
					document.source,
					'duplicate README.md in directory'
				);
			}
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
	for (const post of posts) sourceRoutes.set(post.relative, post.route);
	const allSources = [...documents, ...posts, changelogSource];
	const renderedBySource = renderSourceDocuments(allSources, sourceRoutes);
	for (const document of documents) {
		if (document.isReadme) continue;
		const page = renderedBySource.get(document.relative);
		if (!page) continue;
		if (byRoute.has(page.route)) {
			throw new ContentError(
				document.source,
				`duplicate route ${page.route}`
			);
		}
		byRoute.set(page.route, page);
	}
	const changelog = renderedBySource.get('CHANGELOG.md');
	if (!changelog)
		throw new ContentError('CHANGELOG.md', 'failed to render changelog');
	byRoute.set(changelog.route, changelog);
	const blog = posts
		.map((post): BlogPost => {
			const page = renderedBySource.get(post.relative);
			if (!page)
				throw new ContentError(
					post.source,
					'failed to render blog post'
				);
			if (byRoute.has(post.route)) {
				throw new ContentError(
					post.relative,
					`duplicate route ${post.route}`
				);
			}
			return { ...page, date: post.date, draft: post.metadata.draft };
		})
		.sort(
			(left, right) =>
				right.date.localeCompare(left.date) ||
				left.title.localeCompare(right.title, 'en', {
					sensitivity: 'base'
				})
		);
	for (const post of blog) byRoute.set(post.route, post);

	for (const document of allSources)
		validateLinks(document, sourceRoutes, renderedBySource);
	const rootDirectory = buildDirectory(root, renderedBySource, byRoute);
	const directories = [...byRoute.values()].filter(
		(node): node is ContentDirectory => node.kind === 'directory'
	);

	return {
		root: rootDirectory,
		directories,
		byRoute,
		changelog,
		blog
	};
}

export function getContent(): ContentIndex {
	if (typeof process === 'undefined' || process.env.NODE_ENV !== 'production')
		return loadIndex();
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
