import type { ParsedMarkdown } from '../frontmatter.js';
import type { RenderedMarkdown } from '../markdown.js';
import type { DocumentMetadata } from '../types.js';

export interface SupportCodeRegistryEntry {
	code: string;
	domain: string;
}

export interface SourceDocument extends ParsedMarkdown {
	relative: string;
	source: string;
	isReadme: boolean;
	route: string;
	rendered?: RenderedMarkdown;
}

export interface DirectoryDraft {
	path: string;
	readme?: SourceDocument;
	documents: SourceDocument[];
	children: DirectoryDraft[];
	metadata?: DocumentMetadata;
}
