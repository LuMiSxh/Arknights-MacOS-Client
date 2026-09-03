import assert from 'node:assert/strict';
import test from 'node:test';

import {
	ContentError,
	parseFrontmatter
} from '../.svelte-kit/content-tests/content/frontmatter.js';
import {
	absoluteSiteUrl,
	normalizeBasePath
} from '../.svelte-kit/content-tests/site.js';
import { renderMarkdown } from '../.svelte-kit/content-tests/content/markdown.js';
import { validateLinks } from '../.svelte-kit/content-tests/content/loader/links.js';
import { siteRoute } from '../.svelte-kit/content-tests/content/loader/routes.js';

function markdown(body, resolve = () => undefined) {
	return renderMarkdown('fixture.md', body, {
		source: 'fixture.md',
		resolve
	}).html;
}

// prettier-ignore
for (const [name, input, message] of [['frontmatter rejects unknown keys', '---\ntitle: Fixture\ndescription: Test fixture\nunknown: value\n---\n', 'unknown frontmatter key: unknown'], ['frontmatter validates an optional domain without a code', '---\ntitle: Fixture\ndescription: Test fixture\ndomain: 42\n---\n', 'frontmatter.domain must be a non-empty string']]) {
	test(name, () => assert.throws(() => parseFrontmatter('fixture.md', input), (error) => error instanceof ContentError && error.message.includes(message)));
}

// prettier-ignore
test('site routes reject protocol-relative paths and preserve the exact deployment base', () => {
	assert.throws(() => siteRoute('//evil.example/redirect/'), (error) => error instanceof ContentError && error.message.includes('protocol-relative'));
	for (const [input, expected] of [['/Arknights-MacOS-Client/', '/Arknights-MacOS-Client'], ['../', '']]) assert.equal(normalizeBasePath(input), expected);
	for (const [input, base, expected] of [['/Arknights-MacOS-Client/', '/Arknights-MacOS-Client', 'https://lumisxh.github.io/Arknights-MacOS-Client/'], ['//evil.example/', '/Arknights-MacOS-Client', 'https://lumisxh.github.io/Arknights-MacOS-Client/'], ['/\\evil.example/', '', 'https://lumisxh.github.io/']]) assert.equal(absoluteSiteUrl(input, base), expected);
});

test('Markdown escapes raw HTML and rejects insecure links and images', () => {
	const html = markdown(
		'<script>alert(1)</script>\n\n[unsafe](http://example.com)\n\n![unsafe](http://example.com/image.png)'
	);
	assert.match(html, /&lt;script&gt;alert\(1\)&lt;\/script&gt;/);
	assert.doesNotMatch(html, /href="http:/);
	assert.doesNotMatch(html, /src="http:/);
});

test('Markdown rejects unsupported and protocol-relative schemes even when resolved', () => {
	const html = markdown(
		'[http](http://example.com) [ftp](ftp://example.com) [script](javascript:alert(1)) [protocol](//example.com)',
		(href) => href
	);
	assert.doesNotMatch(html, /href=/i);
});

// prettier-ignore
test('absolute route fragments must resolve to a documented heading', () => {
	const source = { relative: 'source.md', source: 'docs/source.md', body: '[missing](/target/#missing)', metadata: {}, isReadme: false, route: '/source/' };
	const target = { kind: 'document', route: '/target/', title: 'Target', description: 'Target', order: 0, hidden: false, audience: 'all', html: '', headings: [], toc: true };
	assert.throws(() => validateLinks(source, new Map([['target.md', '/target/']]), new Map([['target.md', target]])), (error) => error instanceof ContentError && error.message.includes('heading anchor does not exist'));
});

// prettier-ignore
test('external Markdown links isolate the opener and referrer', () => {
	const html = markdown('[safe](https://example.com)');
	assert.match(html, /<a href="https:\/\/example\.com" target="_blank" rel="noopener noreferrer">safe<\/a>/);
});
