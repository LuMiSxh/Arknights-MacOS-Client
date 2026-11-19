import type { ParsedMarkdown } from '../frontmatter.js';
import type { RenderedMarkdown } from '../markdown.js';
import type { DocumentMetadata, SiteRoute } from '../types.js';

export interface SupportCodeRegistryEntry {
	code: string;
	domain: string;
}

/** The page facts that the support-code registry cross-checks. */
export interface SupportCodeDocument {
	source: string;
	domain: string;
	route: string;
}

export interface SourceDocument extends ParsedMarkdown {
	relative: string;
	source: string;
	isReadme: boolean;
	route: SiteRoute;
	rendered?: RenderedMarkdown;
}

export interface BlogSource extends SourceDocument {
	date: string;
}

export interface DirectoryDraft {
	path: string;
	readme?: SourceDocument;
	documents: SourceDocument[];
	children: DirectoryDraft[];
	metadata?: DocumentMetadata;
}
