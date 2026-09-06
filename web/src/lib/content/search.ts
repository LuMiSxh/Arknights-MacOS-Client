import type { ContentIndex, ContentNode, Heading, SiteRoute } from './types.js';

export interface SearchEntry {
	route: SiteRoute;
	title: string;
	description: string;
	headings: Heading[];
	body: string;
	kind?: ContentNode['kind'];
}

export interface SearchResult {
	route: SiteRoute;
	title: string;
	description: string;
	kind?: ContentNode['kind'];
	heading?: Heading;
	excerpt?: string;
	score: number;
}

export interface SearchTextFragment {
	text: string;
	matched: boolean;
}

const SEARCH_TOKEN = /[\p{L}\p{N}]+/gu;
const SEARCH_STOP_WORDS = new Set([
	'a',
	'an',
	'and',
	'for',
	'from',
	'how',
	'in',
	'is',
	'of',
	'on',
	'the',
	'to',
	'with'
]);

function normalize(value: string): string {
	return value
		.normalize('NFKD')
		.replace(/[\u0300-\u036f]/g, '')
		.toLocaleLowerCase('en');
}

function tokens(value: string): string[] {
	return normalize(value).match(SEARCH_TOKEN) ?? [];
}

function decodeHtml(value: string): string {
	return value
		.replace(/&#(\d+);/g, (_match, code: string) =>
			String.fromCodePoint(Number(code))
		)
		.replace(/&#x([\da-f]+);/gi, (_match, code: string) =>
			String.fromCodePoint(parseInt(code, 16))
		)
		.replace(/&amp;/g, '&')
		.replace(/&lt;/g, '<')
		.replace(/&gt;/g, '>')
		.replace(/&quot;/g, '"')
		.replace(/&#39;/g, "'");
}

export function plainTextFromHtml(html: string): string {
	return decodeHtml(
		html
			.replace(/<h[1-6][^>]*>[\s\S]*?<\/h[1-6]>/gi, ' ')
			.replace(/<pre[\s\S]*?<\/pre>/gi, (block) =>
				block.replace(/<[^>]+>/g, ' ')
			)
			.replace(/<[^>]+>/g, ' ')
			.replace(/\s+/g, ' ')
	).trim();
}

export function createSearchIndex(
	content: Pick<ContentIndex, 'byRoute'>
): SearchEntry[] {
	return [...content.byRoute.values()]
		.filter((node) => !node.hidden)
		.map((node) => ({
			route: node.route,
			title: node.title,
			description: node.description,
			headings: node.headings,
			body: plainTextFromHtml(node.html),
			kind: node.kind
		}));
}

function editDistance(left: string, right: string): number {
	const previous = Array.from(
		{ length: right.length + 1 },
		(_, index) => index
	);
	for (let row = 1; row <= left.length; row += 1) {
		let diagonal = previous[0];
		previous[0] = row;
		for (let column = 1; column <= right.length; column += 1) {
			const above = previous[column];
			previous[column] = Math.min(
				previous[column] + 1,
				previous[column - 1] + 1,
				diagonal + (left[row - 1] === right[column - 1] ? 0 : 1)
			);
			diagonal = above;
		}
	}
	return previous[right.length];
}

function tokenMatch(query: string, candidate: string): number {
	if (candidate === query) return 1;
	if (candidate.startsWith(query)) return 0.82;
	if (
		query.startsWith(candidate) &&
		candidate.length >= 3 &&
		query.length - candidate.length <= 2
	)
		return 0.82;
	if (query.length < 3 || candidate.length < 3) return 0;
	const limit = query.length > 5 ? 2 : 1;
	const distance = editDistance(query, candidate);
	return distance <= limit ? 0.72 - distance * 0.1 : 0;
}

export function highlightSearchText(
	value: string,
	query: string
): SearchTextFragment[] {
	const queryTokens = tokens(query).filter(
		(token) => !SEARCH_STOP_WORDS.has(token)
	);
	if (!value || !queryTokens.length)
		return value ? [{ text: value, matched: false }] : [];

	const fragments: SearchTextFragment[] = [];
	let cursor = 0;
	for (const match of value.matchAll(/[\p{L}\p{N}\p{M}]+/gu)) {
		const start = match.index ?? cursor;
		if (start > cursor)
			fragments.push({
				text: value.slice(cursor, start),
				matched: false
			});
		const text = match[0];
		const candidate = normalize(text);
		const matched = queryTokens.some(
			(queryToken) =>
				candidate.includes(queryToken) ||
				tokenMatch(queryToken, candidate) > 0
		);
		fragments.push({ text, matched });
		cursor = start + text.length;
	}
	if (cursor < value.length)
		fragments.push({ text: value.slice(cursor), matched: false });
	return fragments;
}

function fieldScore(
	queryTokens: string[],
	field: string,
	weight: number
): number {
	if (!field) return 0;
	const normalizedField = normalize(field);
	const fieldTokens = tokens(field);
	if (!fieldTokens.length) return 0;

	let total = 0;
	let matched = 0;
	for (const queryToken of queryTokens) {
		if (normalizedField.includes(queryToken)) {
			total += 1;
			matched += 1;
			continue;
		}
		const best = Math.max(
			...fieldTokens.map((fieldToken) =>
				tokenMatch(queryToken, fieldToken)
			),
			0
		);
		if (best > 0) {
			total += best;
			matched += 1;
		}
	}
	if (!matched) return 0;

	const coverage = matched / queryTokens.length;
	return weight * (total / queryTokens.length) * (0.4 + coverage * 0.6);
}

function excerpt(body: string, queryTokens: string[]): string | undefined {
	if (!body) return undefined;
	let matchAt: number | undefined;
	let matchScore = 0;
	for (const match of body.matchAll(/[\p{L}\p{N}\p{M}]+/gu)) {
		const candidate = normalize(match[0]);
		const score = Math.max(
			...queryTokens.map((queryToken) =>
				candidate.includes(queryToken)
					? 1
					: tokenMatch(queryToken, candidate)
			),
			0
		);
		if (score > matchScore) {
			matchScore = score;
			matchAt = match.index;
		}
	}
	if (matchAt === undefined) return undefined;
	const start = Math.max(0, matchAt - 48);
	const end = Math.min(body.length, start + 140);
	const value = body.slice(start, end).trim();
	return `${start ? '…' : ''}${value}${end < body.length ? '…' : ''}`;
}

export function searchContent(
	entries: SearchEntry[],
	query: string,
	limit = 12
): SearchResult[] {
	const queryTokens = tokens(query).filter(
		(token) => !SEARCH_STOP_WORDS.has(token)
	);
	if (!queryTokens.length) return [];

	return entries
		.map((entry) => {
			const headingScores = entry.headings.map((heading) => ({
				heading,
				score: fieldScore(queryTokens, heading.text, 700)
			}));
			const bestHeading = headingScores.sort(
				(left, right) => right.score - left.score
			)[0];
			const titleScore = fieldScore(queryTokens, entry.title, 900);
			const descriptionScore = fieldScore(
				queryTokens,
				entry.description,
				500
			);
			const bodyScore = fieldScore(queryTokens, entry.body, 260);
			const headingScore = bestHeading?.score ?? 0;
			const score =
				titleScore + descriptionScore + headingScore + bodyScore;
			const headingIsBestDestination =
				bestHeading &&
				headingScore > 0 &&
				headingScore >= titleScore * 0.85 &&
				headingScore >= descriptionScore * 1.4 &&
				headingScore >= bodyScore * 1.25;
			return {
				route: entry.route,
				title: entry.title,
				description: entry.description,
				...(entry.kind ? { kind: entry.kind } : {}),
				...(headingIsBestDestination
					? { heading: bestHeading.heading }
					: {}),
				excerpt: excerpt(entry.body, queryTokens),
				score
			};
		})
		.filter((result) => result.score > 0)
		.sort(
			(left, right) =>
				right.score - left.score ||
				left.title.localeCompare(right.title, 'en', {
					sensitivity: 'base'
				}) ||
				left.route.localeCompare(right.route, 'en')
		)
		.slice(0, limit);
}
