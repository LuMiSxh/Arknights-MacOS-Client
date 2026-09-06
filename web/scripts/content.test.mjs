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
import {
	buildDirectory,
	createDirectory
} from '../.svelte-kit/content-tests/content/loader/tree.js';
import {
	highlightSearchText,
	searchContent
} from '../.svelte-kit/content-tests/content/search.js';
import { scrollDeltaFor } from '../.svelte-kit/content-tests/scroll.js';

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

test('Markdown wraps tables for constrained-width scrolling', () => {
	const html = markdown(
		'| Name | Value |\n| --- | --- |\n| prefix | portable |'
	);
	assert.match(
		html,
		/<div class="markdown-table-scroll"><table>[\s\S]*<\/table>\s*<\/div>/
	);
});

test('hidden sections hide descendants from the content index', () => {
	const root = createDirectory('');
	const hiddenSection = createDirectory('private');
	const hiddenMetadata = {
		title: 'Private',
		description: 'Hidden content.',
		order: 1,
		hidden: true,
		draft: false,
		audience: 'all',
		toc: true
	};
	hiddenSection.readme = {
		isReadme: true,
		relative: 'private/README.md',
		metadata: hiddenMetadata
	};
	const source = { isReadme: false, relative: 'private/page.md' };
	hiddenSection.documents.push(source);
	root.children.push(hiddenSection);
	const page = {
		kind: 'document',
		route: '/private/page/',
		title: 'Private page',
		description: 'Hidden page.',
		order: 1,
		hidden: false,
		audience: 'all',
		html: 'secret',
		headings: [],
		toc: true
	};
	const byRoute = new Map([['/private/page/', page]]);

	const renderedReadme = {
		kind: 'document',
		route: '/private/',
		title: 'Private',
		description: 'Hidden content.',
		order: 1,
		hidden: true,
		audience: 'all',
		html: '',
		headings: [],
		toc: true
	};
	buildDirectory(
		root,
		new Map([
			['private/README.md', renderedReadme],
			['private/page.md', page]
		]),
		byRoute
	);

	assert.equal(byRoute.get('/private/page/').hidden, true);
});

test('fuzzy search finds body text and links a heading match directly', () => {
	const results = searchContent(
		[
			{
				route: '/installation/',
				title: 'Installation guide',
				description: 'Install and update the launcher.',
				headings: [
					{
						level: 2,
						text: 'Wine prefix setup',
						id: 'wine-prefix-setup'
					}
				],
				body: 'Create a portable Wine prefix before launching the game.'
			},
			{
				route: '/troubleshooting/',
				title: 'Troubleshooting',
				description: 'Recover from common errors.',
				headings: [],
				body: 'Review the launcher log when a service request fails.'
			}
		],
		'portable wine perfix'
	);

	assert.equal(results[0]?.route, '/installation/');
	assert.equal(results[0]?.heading?.id, 'wine-prefix-setup');

	const typoOnly = searchContent(
		[
			{
				route: '/installation/',
				title: 'Installation guide',
				description: 'Install and update the launcher.',
				headings: [],
				body: 'Create a portable Wine prefix before launching the game.'
			}
		],
		'perfix'
	);
	assert.match(typoOnly[0]?.excerpt ?? '', /prefix/);
});

test('search keeps page destination when the title is the strongest match', () => {
	const results = searchContent(
		[
			{
				route: '/installation/',
				title: 'Wine prefix',
				description: 'Set up the launcher.',
				headings: [
					{ level: 2, text: 'Wine prefix details', id: 'details' }
				],
				body: 'Create the prefix and launch the game.'
			}
		],
		'wine prefix'
	);

	assert.equal(results[0]?.route, '/installation/');
	assert.equal(results[0]?.heading, undefined);
});

test('search rejects gibberish and short unrelated candidates', () => {
	const entries = [
		{
			route: '/short/',
			title: 'P',
			description: 'Q',
			headings: [],
			body: 'X'
		},
		{
			route: '/keyboard/',
			title: 'Qwerty',
			description: 'Keyboard layout',
			headings: [],
			body: 'Keys'
		}
	];

	assert.deepEqual(searchContent(entries, 'zzzzzz'), []);
	assert.deepEqual(searchContent(entries, 'qwertyuiop'), []);
	assert.deepEqual(searchContent(entries, 'prefix'), []);
});

test('search highlighting preserves text and marks exact and fuzzy words', () => {
	assert.deepEqual(highlightSearchText('Wine prefix', 'wine perfix'), [
		{ text: 'Wine', matched: true },
		{ text: ' ', matched: false },
		{ text: 'prefix', matched: true }
	]);

	assert.deepEqual(highlightSearchText('The guide', 'the'), [
		{ text: 'The guide', matched: false }
	]);
});

test('search result scrolling follows only the local list edges', () => {
	const list = { top: 100, bottom: 300 };
	assert.equal(scrollDeltaFor(list, { top: 130, bottom: 260 }), 0);
	assert.equal(scrollDeltaFor(list, { top: 230, bottom: 340 }), 40);
	assert.equal(scrollDeltaFor(list, { top: 60, bottom: 170 }), -40);
});
