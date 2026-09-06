import assert from 'node:assert/strict';
import {
	existsSync,
	globSync,
	readFileSync,
	statSync,
	writeFileSync
} from 'node:fs';
import { relative, resolve } from 'node:path';

const build = resolve(import.meta.dirname, '../build');
const basePath = normalizeBasePath(process.env.BASE_PATH ?? '');
const siteUrl = `https://lumisxh.github.io${basePath}`;

function normalizeBasePath(value) {
	if (!value || value === '/') return '';
	return `/${value.replace(/^\/+|\/+$/g, '')}`;
}

function buildFiles(extension) {
	return globSync(`**/*.${extension}`, { cwd: build }).map((path) =>
		resolve(build, path)
	);
}

function routeFor(path) {
	const name = relative(build, path);
	if (name === 'index.html') return `${basePath}/`;
	if (name.endsWith('/index.html'))
		return `${basePath}/${name.slice(0, -10)}`;
	return `${basePath}/${name}`;
}

function elements(html, tag) {
	return [...html.matchAll(new RegExp(`<${tag}\\b[^>]*>`, 'gi'))].map(
		([match]) => match
	);
}

function attribute(element, key) {
	return new RegExp(`\\b${key}=["']([^"']+)["']`, 'i').exec(element)?.[1];
}

function normalizePath(path) {
	return path.replace(/\/+$/, '') || '/';
}

function contrastRatio(first, second) {
	const luminance = (hex) => {
		const channels = [0, 2, 4].map(
			(offset) => parseInt(hex.slice(offset, offset + 2), 16) / 255
		);
		return [0.2126, 0.7152, 0.0722].reduce((sum, weight, index) => {
			const channel =
				channels[index] <= 0.03928
					? channels[index] / 12.92
					: ((channels[index] + 0.055) / 1.055) ** 2.4;
			return sum + weight * channel;
		}, 0);
	};
	const values = [luminance(first.slice(1)), luminance(second.slice(1))];
	return (Math.max(...values) + 0.05) / (Math.min(...values) + 0.05);
}

function assertLightContrast() {
	const css = buildFiles('css')
		.map((path) => readFileSync(path, 'utf8'))
		.join('\n');
	const token = (name) =>
		new RegExp(`--${name}:\\s*(#[0-9a-f]{6})`, 'i').exec(css)?.[1];
	const background = token('color-anasthasia-bg');
	const accent = token('color-anasthasia-accent');
	assert.ok(background && accent, 'light contrast tokens are missing');
	const ratio = contrastRatio(background, accent);
	assert.ok(
		ratio >= 4.5,
		`light accent contrast is below WCAG AA: ${ratio.toFixed(3)}:1`
	);
}

function publicPages() {
	return buildFiles('html').filter((path) => !path.endsWith('/spa.html'));
}

function assertSearchIndex() {
	const indexPath = resolve(build, 'search-index.json');
	assert.ok(existsSync(indexPath), 'search index asset is missing');
	assert.equal(
		routeFor(indexPath),
		`${basePath}/search-index.json`,
		'search index asset is not base-path safe'
	);
	const index = JSON.parse(readFileSync(indexPath, 'utf8'));
	assert.ok(
		Array.isArray(index) && index.length > 0,
		'search index is empty'
	);
	const pages = publicPages();
	for (const path of pages) {
		assert.doesNotMatch(
			readFileSync(path, 'utf8'),
			/["']?search["']?\s*:\s*\[/i,
			`${relative(build, path)} serializes the full search index`
		);
	}
	const clientSource = buildFiles('js')
		.map((path) => readFileSync(path, 'utf8'))
		.join('\n');
	assert.match(
		clientSource,
		/search-index\.json/,
		'search index is not lazy-loaded'
	);
	if (basePath)
		assert.ok(
			clientSource.includes(basePath),
			'client bundle is missing the configured base path'
		);
}

// prettier-ignore
function assertPages(pages, routes) {
	for (const path of pages) {
		const page = relative(build, path), route = routeFor(path), html = readFileSync(path, 'utf8');
		const canonical = page === '404.html' ? `${siteUrl}/404.html` : `${siteUrl}${route.slice(basePath.length)}`;
		for (const [tag, key, value, expected, attributeName] of [
			['meta', 'name', 'description'], ['link', 'rel', 'canonical', canonical, 'href'],
			['meta', 'property', 'og:url', canonical], ['meta', 'property', 'og:image', `${siteUrl}/AppIcon-128.png`],
			['meta', 'name', 'twitter:card'], ['meta', 'name', 'twitter:title'],
			['meta', 'name', 'twitter:description'], ['meta', 'name', 'twitter:image', `${siteUrl}/AppIcon-128.png`]
		]) {
			const matches = elements(html, tag).filter((element) => attribute(element, key) === value);
			assert.equal(matches.length, 1, `${page}: ${key}=${value}`);
			if (expected) assert.equal(attribute(matches[0], attributeName ?? 'content'), expected, `${page}: ${value}`);
		}
		assert.equal(
			elements(html, 'link').filter((element) => attribute(element, 'rel') === 'icon').length,
			1,
			`${page}: favicon is missing or duplicated`
		);
		assert.match(html, /<title>[^<]+<\/title>/i, page);
		assert.match(html, /<h1\b/i, page);
		for (const anchor of elements(html, 'a')) {
			const href = attribute(anchor, 'href');
			if (attribute(anchor, 'target') === '_blank') assert.match(attribute(anchor, 'rel') ?? '', /\bnoopener\b[^"']*\bnoreferrer\b/i, `${page}: blank target lacks opener isolation`);
			if (!href || href.startsWith('#') || /^(?:https?:|mailto:|data:)/i.test(href) || href.startsWith('//')) continue;
			const pathname = new URL(href, `https://build.invalid${route}`).pathname;
			if (!routes.has(pathname) && !pathname.startsWith(`${basePath}/_app/`) && !/\.(?:css|js|json|map|png|svg|ico|txt|xml)$/i.test(pathname)) assert.fail(`${page}: missing internal route ${href}`);
		}
		const navigation = [...html.matchAll(/<nav\b[\s\S]*?<\/nav>/gi)].map(([markup]) => markup).filter((markup) => /\bsite-nav\b|aria-label=["']Mobile primary["']/i.test(markup)).join('\n');
		const expectedPath = normalizePath(route);
		for (const anchor of elements(navigation, 'a')) {
			const href = attribute(anchor, 'href');
			if (!href) continue;
			const anchorPath = normalizePath(new URL(href, `https://build.invalid${route}`).pathname);
			if (attribute(anchor, 'aria-current') === 'page') assert.equal(anchorPath, expectedPath, `${page}: aria-current=page must identify the exact current route`);
			if (anchorPath === expectedPath) assert.equal(attribute(anchor, 'aria-current'), 'page', `${page}: exact navigation target must be marked aria-current=page`);
		}
		const toc = html.indexOf('<aside class="content-toc');
		if (toc !== -1) assert.ok(html.indexOf('<article class="content-copy') > toc, `${page}: table of contents must precede article in DOM order`);
	}
}

// prettier-ignore
function writeDiscoveryFiles() {
	const pages = publicPages(), routes = new Set(pages.filter((path) => !path.endsWith('/404.html')).map(routeFor));
	const locations = [...routes].sort().map((route) => `  <url><loc>${siteUrl}${route.slice(basePath.length)}</loc></url>`).join('\n');
	writeFileSync(resolve(build, 'robots.txt'), `User-agent: *\nAllow: /\nSitemap: ${siteUrl}/sitemap.xml\n`, 'utf8');
	writeFileSync(resolve(build, 'sitemap.xml'), `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${locations}\n</urlset>\n`, 'utf8');
	const home = `${basePath}/`, canonical = `${siteUrl}/404.html`, description = 'The requested Arknights Client documentation page could not be found.', icon = `${siteUrl}/AppIcon-128.png`, favicon = `${basePath}/favicon.ico`;
	const notFound = `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>404 · Page not found · Arknights Client</title><meta name="description" content="${description}"><meta name="robots" content="noindex"><link rel="icon" type="image/x-icon" sizes="any" href="${favicon}"><link rel="canonical" href="${canonical}"><meta property="og:type" content="website"><meta property="og:title" content="Page not found · Arknights Client"><meta property="og:description" content="${description}"><meta property="og:url" content="${canonical}"><meta property="og:image" content="${icon}"><meta name="twitter:card" content="summary"><meta name="twitter:title" content="Page not found · Arknights Client"><meta name="twitter:description" content="${description}"><meta name="twitter:image" content="${icon}"><style>body{max-width:42rem;margin:10vh auto;padding:1.5rem;font:1rem/1.6 system-ui,sans-serif;color:#f5f7f8;background:#090b0d}a{color:#78d7ff}</style></head><body><main><p>Error 404</p><h1>Page not found</h1><p>The page may have moved, or the link may be stale.</p><a href="${home}">Return home</a></main></body></html>\n`;
	writeFileSync(resolve(build, '404.html'), notFound, 'utf8');
}

function assertBuildOutput() {
	const pages = publicPages();
	const routes = new Set(
		pages.filter((path) => !path.endsWith('/404.html')).map(routeFor)
	);
	assertPages(pages, routes);
	assertSearchIndex();

	const development = readFileSync(
		resolve(build, 'development/index.html'),
		'utf8'
	);
	assert.doesNotMatch(development, /href=["'][^"']*\/proposals\/["']/i);
	assert.doesNotMatch(development, />Proposals<\/[^>]+>/i);
	const webIcon = resolve(build, 'AppIcon-128.png');
	assert.ok(existsSync(webIcon));
	assert.ok(statSync(webIcon).size <= 32 * 1024, 'web icon exceeds 32 KiB');
	const webFavicon = resolve(build, 'favicon.ico');
	assert.ok(existsSync(webFavicon));
	assert.ok(
		statSync(webFavicon).size <= 32 * 1024,
		'web favicon exceeds 32 KiB'
	);
	const robots = readFileSync(resolve(build, 'robots.txt'), 'utf8');
	const sitemap = readFileSync(resolve(build, 'sitemap.xml'), 'utf8');
	assert.match(robots, new RegExp(`Sitemap: ${siteUrl}/sitemap\\.xml`));
	assert.match(sitemap, new RegExp(`<loc>${siteUrl}/</loc>`));
	assert.match(sitemap, new RegExp(`<loc>${siteUrl}/installation/</loc>`));
	assertLightContrast();
}

writeDiscoveryFiles();
assertBuildOutput();
console.log('✔ post-build assertions passed');
