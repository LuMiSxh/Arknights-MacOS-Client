export type ContentAudience = 'all' | 'developers' | 'users';
export type SiteRoute = `/${string}`;

export interface DocumentMetadata {
	title: string;
	description: string;
	order: number;
	hidden: boolean;
	draft: boolean;
	audience: ContentAudience;
	toc: boolean;
	code?: string;
	domain?: string;
}

export interface Heading {
	level: number;
	text: string;
	id: string;
}

export interface ContentSummary {
	kind: 'document' | 'directory';
	route: SiteRoute;
	title: string;
	description: string;
	order: number;
	hidden: boolean;
	audience: ContentAudience;
	code?: string;
}

export interface ContentDocument extends ContentSummary {
	kind: 'document';
	html: string;
	headings: Heading[];
	toc: boolean;
}

export interface BlogPost extends ContentDocument {
	date: string;
	draft: boolean;
}

export interface ContentDirectory extends ContentSummary {
	kind: 'directory';
	html: string;
	headings: Heading[];
	children: ContentSummary[];
	toc: boolean;
}

export type ContentNode = ContentDocument | ContentDirectory;

export interface ContentNeighbors {
	previous?: ContentSummary;
	next?: ContentSummary;
}

export interface ContentIndex {
	root: ContentDirectory;
	directories: ContentDirectory[];
	byRoute: Map<string, ContentNode>;
	changelog: ContentDocument;
	blog: BlogPost[];
	release: ReleaseNote | null;
}

export interface InlineSegment {
	text: string;
	strong: boolean;
}

export interface ReleaseItem {
	category: 'Added' | 'Changed' | 'Fixed';
	segments: InlineSegment[];
}

export interface ReleaseNote {
	version: string;
	date: string;
	items: ReleaseItem[];
	/** True when the shown items span more than one category, so each item names its category. */
	categorized: boolean;
}
