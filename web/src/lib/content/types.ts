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
}
