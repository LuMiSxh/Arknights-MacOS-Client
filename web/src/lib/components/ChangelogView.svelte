<script lang="ts">
	import { SectionLabel } from 'anasthasia';
	import type { ContentDocument, Heading } from '$lib/content/types.js';

	interface Props {
		content: ContentDocument;
	}

	interface ReleaseSection {
		id: string;
		title: string;
		headingHtml: string;
		bodyHtml: string;
		isUnreleased: boolean;
	}

	interface ParsedChangelog {
		introHtml: string;
		releases: ReleaseSection[];
	}

	const H1 = /<h1\b[^>]*>[\s\S]*?<\/h1>/i;
	const H2 = /<h2\b[^>]*id="([^"]+)"[^>]*>([\s\S]*?)<\/h2>/gi;
	const H3 = /<h3\b[^>]*id="([^"]+)"[^>]*>([\s\S]*?)<\/h3>/gi;

	let { content }: Props = $props();
	const parsed = $derived.by(() =>
		parseChangelog(content.html, content.headings)
	);

	function textFromHtml(value: string): string {
		return value.replaceAll(/<[^>]+>/g, '').trim();
	}

	function categoryFor(id: string, headingHtml: string): string {
		const category = textFromHtml(headingHtml).toLowerCase();
		if (
			category === 'added' ||
			category === 'changed' ||
			category === 'fixed'
		)
			return category;
		if (category === 'removed') return 'removed';
		return id.replace(/-\d+$/, '') || 'other';
	}

	function decorateCategories(html: string): string {
		const headings = [...html.matchAll(H3)];
		if (!headings.length) return html;

		let output = html.slice(0, headings[0].index ?? 0);
		for (const [index, heading] of headings.entries()) {
			const start = heading.index ?? 0;
			const end = headings[index + 1]?.index ?? html.length;
			const category = categoryFor(heading[1], heading[2]);
			output += `<section class="changelog-category changelog-category-${category}" data-category="${category}">${html.slice(start, end)}</section>`;
		}
		return output;
	}

	function parseChangelog(
		html: string,
		headings: Heading[]
	): ParsedChangelog {
		const sections = [...html.matchAll(H2)];
		const firstReleaseStart = sections[0]?.index ?? html.length;
		const introHtml = html.slice(0, firstReleaseStart).replace(H1, '');
		const releases = sections.map((section, index) => {
			const start = (section.index ?? 0) + section[0].length;
			const end = sections[index + 1]?.index ?? html.length;
			const id = section[1];
			const title =
				headings.find(
					(heading) => heading.level === 2 && heading.id === id
				)?.text ?? textFromHtml(section[2]);
			return {
				id,
				title,
				headingHtml: section[2],
				bodyHtml: decorateCategories(html.slice(start, end)),
				isUnreleased: id === 'unreleased'
			};
		});

		return { introHtml, releases };
	}
</script>

<svelte:head>
	<title>{content.title} · Arknights Client</title>
	<meta name="description" content={content.description} />
</svelte:head>

<div class="changelog-page">
	<header class="changelog-header">
		<SectionLabel>Project history</SectionLabel>
		<h1>{content.title}</h1>
		<p>{content.description}</p>
	</header>

	{#if parsed.introHtml}
		<div class="changelog-intro">{@html parsed.introHtml}</div>
	{/if}

	<div class="release-list" aria-label="Release history">
		{#each parsed.releases as release (release.id)}
			{#if release.isUnreleased}
				<section
					id={release.id}
					class="release release-current"
					aria-labelledby={`${release.id}-heading`}
				>
					<div class="release-heading-row">
						<h2 id={`${release.id}-heading`} class="release-title">
							{@html release.headingHtml}
						</h2>
						<span class="release-state">Open</span>
					</div>
					<div class="release-body">{@html release.bodyHtml}</div>
				</section>
			{:else}
				<details class="release release-published">
					<summary id={release.id}>
						<span
							class="release-title"
							role="heading"
							aria-level="2"
						>
							{@html release.headingHtml}
						</span>
						<span class="release-summary-meta">
							<span>Published release</span>
							<span class="release-chevron" aria-hidden="true"
							></span>
						</span>
					</summary>
					<div class="release-body">{@html release.bodyHtml}</div>
				</details>
			{/if}
		{/each}
	</div>
</div>

<style>
	.changelog-page {
		width: 100%;
	}

	.changelog-header {
		border-bottom: 1px solid var(--site-line);
		margin: clamp(1.5rem, 5vw, 3.5rem) 0 1.5rem;
		padding-bottom: 1.25rem;
	}

	.changelog-header h1 {
		margin: 0.55rem 0 0.4rem;
		font-size: clamp(1.9rem, 3.2vw, 2.85rem);
		letter-spacing: -0.045em;
		line-height: 1;
	}

	.changelog-header p {
		margin: 0;
		color: var(--color-anasthasia-muted);
	}

	.changelog-intro {
		border-bottom: 1px solid var(--site-line);
		padding-bottom: 1.25rem;
		color: var(--color-anasthasia-muted);
	}

	:global(.changelog-intro p) {
		margin: 0.45rem 0;
	}

	:global(.changelog-intro a) {
		color: var(--color-anasthasia-text);
		text-decoration-color: var(--color-anasthasia-border);
		text-underline-offset: 0.15em;
	}

	.release-list {
		width: 100%;
	}

	.release {
		border-bottom: 1px solid var(--site-line);
	}

	.release-current {
		border-top: 2px solid var(--color-anasthasia-text);
		padding: 1.15rem 0 1.75rem;
	}

	.release-heading-row,
	.release-published summary {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 1rem;
	}

	.release-published summary {
		cursor: pointer;
		list-style: none;
		padding: 0.9rem 0;
	}

	.release-published summary::-webkit-details-marker {
		display: none;
	}

	.release-published summary:hover {
		background: var(--color-anasthasia-panel);
	}

	.release-title {
		margin: 0;
		font-size: clamp(1.2rem, 2.5vw, 1.8rem);
		font-weight: 700;
		letter-spacing: -0.045em;
		line-height: 1.1;
	}

	:global(.release-title a) {
		color: inherit;
		text-decoration: none;
	}

	:global(.release-title a:hover) {
		text-decoration: underline;
		text-decoration-thickness: 0.08em;
		text-underline-offset: 0.16em;
	}

	.release-state,
	.release-summary-meta {
		flex: 0 0 auto;
		color: var(--color-anasthasia-muted);
		font-family: var(--font-anasthasia-mono);
		font-size: 0.62rem;
		letter-spacing: 0.08em;
		text-transform: uppercase;
	}

	.release-summary-meta {
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
	}

	.release-chevron {
		display: inline-grid;
		width: 1.5rem;
		height: 1.5rem;
		place-items: center;
		font-size: 0.9rem;
		line-height: 1;
	}

	.release-chevron::before {
		content: '↓';
	}

	details[open] .release-chevron::before {
		content: '↑';
	}

	.release-body {
		width: 100%;
		padding: 0.1rem 0 1.25rem;
	}

	:global(.release-body .changelog-category) {
		border-top: 1px solid var(--site-line);
		margin-top: 1.15rem;
		padding-top: 0.8rem;
	}

	:global(.release-body .changelog-category h3) {
		margin: 0 0 0.65rem;
		color: var(--color-anasthasia-text);
		font-family: var(--font-anasthasia-mono);
		font-size: 0.68rem;
		font-weight: 700;
		letter-spacing: 0.13em;
		line-height: 1.3;
		text-transform: uppercase;
	}

	:global(.release-body .changelog-category h3::before) {
		display: inline-block;
		width: 1.5rem;
		color: var(--color-anasthasia-muted);
		font-size: 0.85rem;
		letter-spacing: 0;
		text-align: left;
	}

	:global(.release-body .changelog-category-added h3::before) {
		content: '+';
	}

	:global(.release-body .changelog-category-changed h3::before) {
		content: '~';
	}

	:global(.release-body .changelog-category-fixed h3::before) {
		content: '✓';
	}

	:global(.release-body .changelog-category-removed h3::before) {
		content: '−';
	}

	:global(.release-body .changelog-category > ul) {
		display: block;
		margin: 0;
		padding-left: 1.35rem;
	}

	:global(.release-body li) {
		padding-left: 0.15rem;
	}

	:global(.release-body li + li) {
		margin-top: 0.45rem;
	}

	:global(.release-body a) {
		color: var(--color-anasthasia-text);
		text-decoration-color: var(--color-anasthasia-border);
		text-underline-offset: 0.15em;
	}

	:global(.release-body code) {
		border: 1px solid var(--site-line);
		border-radius: var(--radius-anasthasia-sm);
		background: var(--color-anasthasia-panel);
		padding: 0.08em 0.28em;
		font-size: 0.86em;
	}

	@media (max-width: 760px) {
		.release-heading-row,
		.release-published summary {
			align-items: flex-start;
		}

		.release-summary-meta {
			font-size: 0.56rem;
		}

		.release-summary-meta > span:first-child {
			display: none;
		}
	}
</style>
