import { ContentError } from '../frontmatter.js';
import type {
	ContentDirectory,
	ContentDocument,
	ContentNode,
	ContentSummary
} from '../types.js';
import type { DirectoryDraft } from './model.js';
import { humanize, siteRoute, slugify, sourceName } from './routes.js';

export function createDirectory(path: string): DirectoryDraft {
	return { path, documents: [], children: [] };
}

export function directoryFor(
	root: DirectoryDraft,
	path: string
): DirectoryDraft {
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

function summaryFor(
	node: ContentNode,
	inheritedHidden = false
): ContentSummary {
	return {
		kind: node.kind,
		route: node.route,
		title: node.title,
		description: node.description,
		order: node.order,
		hidden: inheritedHidden || node.hidden,
		audience: node.audience,
		...(node.code ? { code: node.code } : {})
	};
}

export function buildDirectory(
	draft: DirectoryDraft,
	renderedBySource: Map<string, ContentDocument>,
	byRoute: Map<string, ContentNode>,
	inheritedHidden = false
): ContentDirectory {
	const readme = draft.readme;
	const sectionName = humanize(draft.path.split('/').at(-1) ?? draft.path);
	const metadata = readme?.metadata ?? {
		title: draft.path ? sectionName : 'Documentation',
		description: draft.path
			? `Guides and reference material in the ${sectionName} section.`
			: 'Guides and reference material for Arknights Client.',
		order: draft.path ? 1000 : 0,
		hidden: false,
		draft: false,
		audience: 'all',
		toc: true
	};
	const hiddenByMetadata = inheritedHidden || metadata.hidden;
	const route = siteRoute(
		draft.path ? `/${draft.path.split('/').map(slugify).join('/')}/` : '/'
	);
	const intro = readme ? renderedBySource.get(readme.relative) : undefined;
	const childDirectories = draft.children
		.map((child) =>
			buildDirectory(child, renderedBySource, byRoute, hiddenByMetadata)
		)
		.filter((child) => child.children.length || child.html);
	const childDocuments = draft.documents
		.filter((document) => !document.isReadme)
		.map((document) => renderedBySource.get(document.relative))
		.filter((document): document is ContentDocument => Boolean(document))
		.map((document) => {
			if (!hiddenByMetadata) return document;
			const hiddenDocument = { ...document, hidden: true };
			byRoute.set(hiddenDocument.route, hiddenDocument);
			return hiddenDocument;
		});
	const hasVisibleChild =
		childDirectories.some((child) => !child.hidden) ||
		childDocuments.some((document) => !document.hidden);
	const hidden = hiddenByMetadata || (!readme && !hasVisibleChild);
	const directory: ContentDirectory = {
		kind: 'directory',
		route,
		title: metadata.title,
		description: metadata.description,
		order: metadata.order,
		hidden,
		audience: metadata.audience,
		html: intro?.html ?? '',
		headings: intro?.headings ?? [],
		children: sortSummaries([
			...childDirectories.map((child) => summaryFor(child, hidden)),
			...childDocuments.map((document) => summaryFor(document, hidden))
		]),
		toc: metadata.toc
	};
	if (route !== '/') {
		if (byRoute.has(route)) {
			throw new ContentError(
				sourceName(draft.path),
				`duplicate route ${route}`
			);
		}
		byRoute.set(route, directory);
	}
	return directory;
}
