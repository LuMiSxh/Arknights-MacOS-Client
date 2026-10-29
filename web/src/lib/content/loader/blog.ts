import { readFileSync, readdirSync } from 'node:fs';
import { resolve } from 'node:path';

import { ContentError, parseBlogFrontmatter } from '../frontmatter.js';
import type { BlogSource } from './model.js';
import { blogRoot } from './paths.js';
import { siteRoute } from './routes.js';

// The file name carries the publication date; the URL carries only the slug, so a
// post keeps its address when its date changes.
const BLOG_FILE = /^(\d{4}-\d{2}-\d{2})-([a-z0-9]+(?:-[a-z0-9]+)*)\.md$/;

/** Drafts render only under `pnpm dev`; production output never contains them. */
const includeDrafts = import.meta.env.DEV;

export function readBlogSources(): BlogSource[] {
	const slugs = new Map<string, string>();
	const posts: BlogSource[] = [];
	for (const name of readdirSync(blogRoot).sort()) {
		if (name.startsWith('.')) continue;
		const source = `docs/blog/${name}`;
		const match = BLOG_FILE.exec(name);
		if (!match) {
			throw new ContentError(
				source,
				'blog posts must be named YYYY-MM-DD-slug.md'
			);
		}
		const [, fileDate, slug] = match;
		const parsed = parseBlogFrontmatter(
			source,
			readFileSync(resolve(blogRoot, name), 'utf8')
		);
		if (parsed.date !== fileDate) {
			throw new ContentError(
				source,
				`frontmatter.date must match the file name date ${fileDate}`
			);
		}
		// Check drafts too, so publishing a draft cannot break the build later.
		const previous = slugs.get(slug);
		if (previous) {
			throw new ContentError(
				source,
				`duplicate blog slug ${slug} already used by ${previous}`
			);
		}
		slugs.set(slug, source);
		if (parsed.metadata.draft && !includeDrafts) continue;
		posts.push({
			...parsed,
			relative: `blog/${name}`,
			source,
			isReadme: false,
			route: siteRoute(`/blog/${slug}/`)
		});
	}
	return posts;
}
