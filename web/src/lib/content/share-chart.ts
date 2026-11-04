import { parse as parseYaml } from 'yaml';
import { ContentError } from './frontmatter.js';
import { escapeHtml } from './html.js';
import { mapping, rejectUnknownKeys } from './fenced-yaml.js';

export interface ShareChartItem {
	label: string;
	share: number;
}

export type ShareChartType = 'bar' | 'pie';

export interface ShareChartSpec {
	title: string;
	type: ShareChartType;
	items: ShareChartItem[];
}

const SPEC_KEYS = new Set(['title', 'type', 'items']);
const SERIES_SLOTS = 7;
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
	const type = parseShareType(spec.type, source);
	if (type === 'pie') {
		const total = items.reduce((sum, item) => sum + item.share, 0);
		if (total < 0.98 || total > 1.02) {
			throw new ContentError(
				source,
				`share-chart.items must add up to between 0.98 and 1.02 for type: pie (they add up to ${total.toFixed(2)})`
			);
		}
	}
	return { title: spec.title.trim(), type, items };
}

function parseShareType(value: unknown, source: string): ShareChartType {
	if (value === undefined || value === 'bar') return 'bar';
	if (value === 'pie') return 'pie';
	throw new ContentError(source, 'share-chart.type must be "bar" or "pie"');
}

/** Colours follow the order of the items. The seventh slot is a neutral grey, so the eighth item repeats the first. */
function seriesColor(index: number): string {
	return `var(--share-chart-${(index % SERIES_SLOTS) + 1})`;
}

function percent(share: number): string {
	return `${Math.round(share * 100)}%`;
}

export function renderShareChart(spec: ShareChartSpec): string {
	if (spec.type === 'pie') {
		return `<figure class="share-chart share-chart-pie"><figcaption>${escapeHtml(spec.title)}</figcaption>${renderPie(spec.items)}</figure>`;
	}
	return `<figure class="share-chart"><figcaption>${escapeHtml(spec.title)}</figcaption>${renderBars(spec.items)}</figure>`;
}

function renderBars(items: ShareChartItem[]): string {
	const rows = items
		.map((item, index) => {
			const width = `${(item.share * 100).toFixed(1)}%`;
			return `<li><span class="share-chart-label">${escapeHtml(item.label)}</span><span class="share-chart-track" aria-hidden="true"><span class="share-chart-fill" style="width: ${width}; background: ${seriesColor(index)}"></span></span><span class="share-chart-value" aria-hidden="true">${percent(item.share)}</span><span class="share-chart-verbal">: ${verbalShare(item.share)}</span></li>`;
		})
		.join('\n');
	return `<ol>\n${rows}\n</ol>`;
}

function renderPie(items: ShareChartItem[]): string {
	const total = items.reduce((sum, item) => sum + item.share, 0);
	let before = 0;
	const slices = items
		.map((item, index) => {
			const length = (item.share / total) * 100;
			const offset = 25 - before;
			before += length;
			return `<circle cx="18" cy="18" r="15.9155" fill="none" stroke-width="6" style="stroke: ${seriesColor(index)}" stroke-dasharray="${length.toFixed(3)} ${(100 - length).toFixed(3)}" stroke-dashoffset="${offset.toFixed(3)}"/>`;
		})
		.join('');
	const legend = items
		.map(
			(item, index) =>
				`<li><span class="share-chart-swatch" style="background: ${seriesColor(index)}" aria-hidden="true"></span><span class="share-chart-label">${escapeHtml(item.label)}</span><span class="share-chart-value" aria-hidden="true">${percent(item.share)}</span><span class="share-chart-verbal">: ${verbalShare(item.share)}</span></li>`
		)
		.join('\n');
	return `<div class="share-chart-pie-body"><svg class="share-chart-donut" viewBox="0 0 36 36" aria-hidden="true" focusable="false">${slices}</svg><ol class="share-chart-legend">\n${legend}\n</ol></div>`;
}
