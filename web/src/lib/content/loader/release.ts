import type {
	InlineSegment,
	ReleaseCategory,
	ReleaseItem,
	ReleaseNote
} from '../types.js';

const RELEASE_SECTION =
	/^## \[(\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?)\] - (\d{4}-\d{2}-\d{2})[ \t]*$([\s\S]*?)(?=^## |(?![\s\S]))/m;
/** Categories fill the home page list in this order. */
const CATEGORIES: readonly ReleaseCategory[] = ['Added', 'Changed', 'Fixed'];
/** The home page shows at most this many items. */
const ITEM_LIMIT = 5;

/**
 * Reads the newest released section, or returns null before the first release.
 * **Unreleased** does not match the heading pattern.
 */
export function readLatestRelease(markdown: string): ReleaseNote | null {
	const section = RELEASE_SECTION.exec(markdown);
	if (!section) return null;
	const [, version, date, body] = section;
	if (version === undefined || date === undefined || body === undefined)
		return null;
	const items: ReleaseItem[] = [];
	for (const category of CATEGORIES) {
		for (const text of listItems(categorySection(body, category))) {
			items.push({ category, segments: inlineSegments(text) });
		}
	}
	const shown = items.slice(0, ITEM_LIMIT);
	return {
		version,
		date,
		items: shown,
		categorized: new Set(shown.map((item) => item.category)).size > 1
	};
}

function categorySection(body: string, category: ReleaseCategory): string {
	const pattern = new RegExp(
		`^### ${category}[ \\t]*$([\\s\\S]*?)(?=^##|(?![\\s\\S]))`,
		'm'
	);
	return pattern.exec(body)?.[1] ?? '';
}

function listItems(markdown: string): string[] {
	const items: string[] = [];
	for (const line of markdown.split('\n')) {
		const bulletText = /^- (.*)$/.exec(line)?.[1];
		if (bulletText !== undefined) items.push(bulletText.trim());
		else if (items.length && /^\s+\S/.test(line))
			items.push(`${items.pop()} ${line.trim()}`);
	}
	return items;
}

/** Splits **bold** runs from plain text. Links keep their label; code keeps its text. */
function inlineSegments(markdown: string): InlineSegment[] {
	return markdown
		.replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')
		.replace(/`([^`]+)`/g, '$1')
		.split('**')
		.map((text, index) => ({ text, strong: index % 2 === 1 }))
		.filter((segment) => segment.text !== '');
}
