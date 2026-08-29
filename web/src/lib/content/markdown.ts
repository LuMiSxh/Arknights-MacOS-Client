import { Marked, type RendererObject, type Token, type Tokens } from 'marked';
import {
	gfmHeadingId,
	getHeadingList,
	resetHeadings
} from 'marked-gfm-heading-id';
import { normalizeBasePath } from '../site.js';
import type { Heading } from './types.js';

export interface MarkdownLinkContext {
	source: string;
	resolve: (href: string, source: string) => string | undefined;
}

export interface RenderedMarkdown {
	html: string;
	headings: Heading[];
}

const SAFE_EXTERNAL = /^(?:https?:|mailto:)/i;
const ALERT_MARKER = /^<p>\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\](?:\r?\n)?/;
const ALERT_LABELS = {
	NOTE: 'Note',
	TIP: 'Tip',
	IMPORTANT: 'Important',
	WARNING: 'Warning',
	CAUTION: 'Caution'
} as const;
const buildBasePath = normalizeBasePath(
	typeof process === 'undefined' ? '' : (process.env.BASE_PATH ?? '')
);

function escapeHtml(value: string): string {
	return value
		.replaceAll('&', '&amp;')
		.replaceAll('<', '&lt;')
		.replaceAll('>', '&gt;')
		.replaceAll('"', '&quot;')
		.replaceAll("'", '&#39;');
}

function safeExternalHref(href: string): string | undefined {
	if (SAFE_EXTERNAL.test(href)) return href;
	if (href.startsWith('#')) return href;
	return undefined;
}

function renderInline(
	renderer: { parser: { parseInline(tokens: Token[]): string } },
	tokens: Token[]
): string {
	return renderer.parser.parseInline(tokens);
}

function renderLink(
	this: { parser: { parseInline(tokens: Token[]): string } },
	token: Tokens.Link,
	context: MarkdownLinkContext
): string {
	const href =
		context.resolve(token.href, context.source) ??
		safeExternalHref(token.href);
	const label = renderInline(this, token.tokens);
	if (!href) return label;

	const isExternal = SAFE_EXTERNAL.test(href);
	const attributes = [
		`href="${escapeHtml(href)}"`,
		token.title ? `title="${escapeHtml(token.title)}"` : '',
		isExternal ? 'target="_blank"' : '',
		isExternal ? 'rel="noreferrer"' : ''
	]
		.filter(Boolean)
		.join(' ');
	return `<a ${attributes}>${label}</a>`;
}

function renderImage(
	token: Tokens.Image,
	context: MarkdownLinkContext
): string {
	const href =
		context.resolve(token.href, context.source) ??
		safeExternalHref(token.href);
	if (!href) return escapeHtml(token.text);
	const title = token.title ? ` title="${escapeHtml(token.title)}"` : '';
	return `<img src="${escapeHtml(href)}" alt="${escapeHtml(token.text)}"${title} loading="lazy">`;
}

function addHeadingLinks(html: string): string {
	return html.replace(
		/<h([2-6]) id="([^"]+)">([\s\S]*?)<\/h\1>/g,
		(_match, level: string, id: string, content: string) =>
			`<h${level} id="${id}">${content}<a class="heading-link" href="#${id}" data-heading-link aria-label="Copy link to this section" title="Copy link to this section">#</a></h${level}>`
	);
}

export function renderMarkdown(
	source: string,
	input: string,
	context: MarkdownLinkContext
): RenderedMarkdown {
	const renderer: RendererObject = {
		html: ({ text }) => escapeHtml(text),
		blockquote(token) {
			const rendered = this.parser.parse(token.tokens);
			const match = ALERT_MARKER.exec(rendered);
			if (!match) return `<blockquote>${rendered}</blockquote>`;

			const kind = match[1] as keyof typeof ALERT_LABELS;
			const body = rendered
				.replace(ALERT_MARKER, '<p>')
				.replace(/^<p><\/p>\s*/, '');
			return `<aside class="markdown-alert markdown-alert-${kind.toLowerCase()}" role="note"><p class="markdown-alert-title">${ALERT_LABELS[kind]}</p>${body}</aside>`;
		},
		link(token) {
			return renderLink.call(this, token, context);
		},
		image(token) {
			return renderImage(token, context);
		},
		code({ text, lang }) {
			const language = lang?.trim().toLowerCase();
			if (language === 'mermaid') {
				return `<div class="mermaid-shell" data-mermaid><pre><code>${escapeHtml(text)}</code></pre></div>`;
			}
			const className = language
				? ` class="language-${escapeHtml(language)}"`
				: '';
			return `<pre><code${className}>${escapeHtml(text)}\n</code></pre>`;
		}
	};

	const parser = new Marked({
		gfm: true,
		renderer
	});
	parser.use(gfmHeadingId());
	resetHeadings();
	const html = addHeadingLinks(parser.parse(input) as string);
	const headings = getHeadingList().map(({ level, raw, id }) => ({
		level,
		text: raw,
		id
	}));

	return { html, headings };
}

export function siteHref(route: string): string {
	return `${buildBasePath}${route.startsWith('/') ? route : `/${route}`}`;
}

export function collectMarkdownLinks(input: string): string[] {
	const links: string[] = [];
	const tokens = new Marked({ gfm: true }).lexer(input);

	function visit(items: Token[]): void {
		for (const token of items) {
			if (token.type === 'link' || token.type === 'image')
				links.push(token.href);
			if ('tokens' in token && Array.isArray(token.tokens))
				visit(token.tokens);
			if (token.type === 'list' && token.items) {
				for (const item of token.items) visit(item.tokens);
			}
		}
	}

	visit(tokens);
	return links;
}
