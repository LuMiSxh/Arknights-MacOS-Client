import { parse as parseYaml } from 'yaml';
import { ContentError } from './frontmatter.js';
import { escapeHtml } from './html.js';

export interface ShareChartItem {
	label: string;
	share: number;
}

export interface ShareChartSpec {
	title: string;
	items: ShareChartItem[];
}

const SPEC_KEYS = new Set(['title', 'items']);
const ITEM_KEYS = new Set(['label', 'share']);

/** The only place that turns a share into the coarse wording read by screen readers. */
export function verbalShare(share: number): string {
	if (share === 0) return 'none';
	if (share >= 0.6) return 'most';
	if (share >= 0.4) return 'about half';
	if (share >= 0.25) return 'about a third';
	if (share >= 0.15) return 'about a fifth';
	return 'a few';
}

function mapping(
	value: unknown,
	source: string,
	where: string
): Record<string, unknown> {
	if (value === null || typeof value !== 'object' || Array.isArray(value)) {
		throw new ContentError(source, `${where} must be a mapping`);
	}
	return value as Record<string, unknown>;
}

function rejectUnknownKeys(
	values: Record<string, unknown>,
	allowed: Set<string>,
	source: string,
	where: string
): void {
	for (const key of Object.keys(values)) {
		if (!allowed.has(key))
			throw new ContentError(source, `unknown ${where} key: ${key}`);
	}
}

export function parseShareChart(source: string, text: string): ShareChartSpec {
	let parsed: unknown;
	try {
		parsed = parseYaml(text);
	} catch (cause) {
		const message =
			cause instanceof Error ? cause.message : 'invalid syntax';
		throw new ContentError(
			source,
			`share-chart is not valid JSON or YAML: ${message}`
		);
	}
	const spec = mapping(parsed, source, 'share-chart');
	rejectUnknownKeys(spec, SPEC_KEYS, source, 'share-chart');
	if (typeof spec.title !== 'string' || spec.title.trim() === '') {
		throw new ContentError(
			source,
			'share-chart.title must be a non-empty string'
		);
	}
	if (!Array.isArray(spec.items) || spec.items.length === 0) {
		throw new ContentError(
			source,
			'share-chart.items must be a non-empty list'
		);
	}
	const items = spec.items.map((entry: unknown, index: number) => {
		const where = `share-chart.items[${index}]`;
		const item = mapping(entry, source, where);
		rejectUnknownKeys(item, ITEM_KEYS, source, 'share-chart item');
		if (typeof item.label !== 'string' || item.label.trim() === '') {
			throw new ContentError(
				source,
				`${where}.label must be a non-empty string`
			);
		}
		if (
			typeof item.share !== 'number' ||
			!Number.isFinite(item.share) ||
			item.share < 0 ||
			item.share > 1
		) {
			throw new ContentError(
				source,
				`${where}.share must be a number from 0 to 1`
			);
		}
		return { label: item.label.trim(), share: item.share };
	});
	return { title: spec.title.trim(), items };
}

export function renderShareChart(spec: ShareChartSpec): string {
	const rows = spec.items
		.map((item) => {
			const width = `${(item.share * 100).toFixed(1)}%`;
			return `<li><span class="share-chart-label">${escapeHtml(item.label)}</span><span class="share-chart-track" aria-hidden="true"><span class="share-chart-fill" style="width: ${width}"></span></span><span class="share-chart-verbal">: ${verbalShare(item.share)}</span></li>`;
		})
		.join('\n');
	return `<figure class="share-chart"><figcaption>${escapeHtml(spec.title)}</figcaption><ol>\n${rows}\n</ol></figure>`;
}
