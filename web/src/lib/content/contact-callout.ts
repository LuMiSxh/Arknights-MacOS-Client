import { parse as parseYaml } from 'yaml';
import { contactFormUrl } from '../site.js';
import { ContentError } from './frontmatter.js';
import { escapeHtml } from './html.js';
import { mapping, rejectUnknownKeys } from './fenced-yaml.js';

export interface ContactCallout {
	title: string;
	text: string;
	topic?: string;
}

const CALLOUT_KEYS = new Set(['title', 'text', 'topic']);
const TOPIC = /^[a-z-]+$/;

function requiredText(
	values: Record<string, unknown>,
	key: 'title' | 'text',
	source: string
): string {
	const value = values[key];
	if (typeof value !== 'string' || value.trim() === '') {
		throw new ContentError(
			source,
			`contact.${key} must be a non-empty string`
		);
	}
	return value.trim();
}

function optionalTopic(value: unknown, source: string): string | undefined {
	if (value === undefined) return undefined;
	if (typeof value !== 'string' || !TOPIC.test(value)) {
		throw new ContentError(
			source,
			'contact.topic must use only lowercase letters and hyphens'
		);
	}
	return value;
}

export function parseContactCallout(
	source: string,
	input: string
): ContactCallout {
	let parsed: unknown;
	try {
		parsed = parseYaml(input);
	} catch (cause) {
		const message =
			cause instanceof Error ? cause.message : 'invalid syntax';
		throw new ContentError(source, `contact is not valid YAML: ${message}`);
	}
	const callout = mapping(parsed, source, 'contact');
	rejectUnknownKeys(callout, CALLOUT_KEYS, source, 'contact');
	return {
		title: requiredText(callout, 'title', source),
		text: requiredText(callout, 'text', source),
		topic: optionalTopic(callout.topic, source)
	};
}

export function contactHref(topic: string | undefined): string {
	if (!topic) return contactFormUrl;
	return `${contactFormUrl}?${new URLSearchParams({ topic }).toString()}`;
}

export function renderContactCallout(callout: ContactCallout): string {
	const href = escapeHtml(contactHref(callout.topic));
	return `<aside class="contact-callout"><p class="contact-callout-title">${escapeHtml(callout.title)}</p><p class="contact-callout-text">${escapeHtml(callout.text)}</p><a class="contact-callout-action" href="${href}" target="_blank" rel="noopener noreferrer">Contact me</a></aside>`;
}
