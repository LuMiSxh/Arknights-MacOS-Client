import { json } from '@sveltejs/kit';
import { getContent } from '$lib/content/loader/index.js';
import { createSearchIndex } from '$lib/content/search.js';

export const prerender = true;

export function GET() {
	return json(createSearchIndex(getContent()));
}
