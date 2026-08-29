import { readFileSync } from 'node:fs';
import { dirname } from 'node:path';

import { ContentError, parseFrontmatter } from '../frontmatter.js';
import type {
	ContentDirectory,
	ContentDocument,
	ContentIndex,
	ContentNeighbors,
	ContentNode
} from '../types.js';
import { renderSourceDocuments, validateLinks } from './links.js';
import type { SourceDocument } from './model.js';
import { changelogPath } from './paths.js';
import { slugify } from './routes.js';
import { readSources } from './sources.js';
import { buildDirectory, createDirectory, directoryFor } from './tree.js';

let cached: ContentIndex | undefined;

function loadIndex(): ContentIndex {
	const documents = readSources();
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
	const allSources = [...documents, changelogSource];
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

	for (const document of allSources)
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
