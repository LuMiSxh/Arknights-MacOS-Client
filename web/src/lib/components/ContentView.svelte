<script lang="ts">
	import { resolve } from '$app/paths';
	import { onMount } from 'svelte';
	import { SectionLabel } from 'anasthasia';
	import MermaidEnhancer from './MermaidEnhancer.svelte';
	import PageMetadata from './PageMetadata.svelte';
	import type {
		ContentNeighbors,
		ContentNode,
		SiteRoute
	} from '$lib/content/types.js';

	interface Props {
		content: ContentNode;
		neighbors?: ContentNeighbors;
	}

	let { content, neighbors = {} }: Props = $props();
	let activeHeading = $state('');
	let tocNavigation = $state<HTMLElement>();
	let copyStatus = $state('');
	let copyStatusTimer: number | undefined;
	let headingScanFrame: number | undefined;
	const visibleChildren = $derived(
		content.kind === 'directory'
			? content.children.filter((entry) => !entry.hidden)
			: []
	);
	const toc = $derived(
		content.toc
			? content.headings.filter((heading) => heading.level > 1)
			: []
	);
	const hasMermaid = $derived(content.html.includes('data-mermaid'));
	const breadcrumbs = $derived.by(
		(): Array<{ title: string; route: SiteRoute }> => {
			const segments = content.route.split('/').filter(Boolean);
			return segments.map((segment, index) => ({
				title:
					index === segments.length - 1
						? content.title
						: segment
								.replaceAll('-', ' ')
								.replace(/\b\w/g, (character) =>
									character.toUpperCase()
								),
				route: `/${segments.slice(0, index + 1).join('/')}/`
			}));
		}
	);

	function syncActiveHeading() {
		const offset = window.innerHeight * 0.2;
		let current = toc[0]?.id ?? '';
		for (const heading of toc) {
			const element = document.getElementById(heading.id);
			if (element && element.getBoundingClientRect().top <= offset)
				current = heading.id;
		}
		if (activeHeading === current) return;
		activeHeading = current;
		requestAnimationFrame(() => {
			tocNavigation
				?.querySelector('[aria-current="location"]')
				?.scrollIntoView({ block: 'nearest', inline: 'nearest' });
		});
	}

	function scheduleActiveHeadingSync() {
		if (headingScanFrame !== undefined) return;
		headingScanFrame = requestAnimationFrame(() => {
			headingScanFrame = undefined;
			syncActiveHeading();
		});
	}

	async function copyHeadingLink(event: MouseEvent) {
		if (!(event.target instanceof Element)) return;
		const link = event.target.closest<HTMLAnchorElement>(
			'a[data-heading-link]'
		);
		if (!link) return;

		event.preventDefault();
		const url = new URL(link.href, window.location.href);
		try {
			await navigator.clipboard.writeText(url.href);
			history.replaceState(history.state, '', url);
			link.dataset.copied = 'true';
			copyStatus = 'Section link copied';
			window.clearTimeout(copyStatusTimer);
			copyStatusTimer = window.setTimeout(() => {
				delete link.dataset.copied;
				copyStatus = '';
			}, 1500);
		} catch {
			window.location.hash = link.hash;
			copyStatus = 'Unable to copy the section link';
		}
	}

	onMount(() => {
		scheduleActiveHeadingSync();
		return () => {
			window.clearTimeout(copyStatusTimer);
			if (headingScanFrame !== undefined)
				cancelAnimationFrame(headingScanFrame);
		};
	});
</script>

<svelte:window
	onscroll={scheduleActiveHeadingSync}
	onresize={scheduleActiveHeadingSync}
/>
<svelte:document onclick={copyHeadingLink} />

<PageMetadata
	title={`${content.title} · Arknights Client`}
	description={content.description}
	path={content.route}
/>

<header class="content-header">
	<nav class="breadcrumbs" aria-label="Breadcrumb">
		<a href={resolve('/')}>Home</a>
		{#each breadcrumbs as crumb, index (crumb.route)}
			<span aria-hidden="true">/</span>
			{#if index === breadcrumbs.length - 1}
				<span aria-current="page">{crumb.title}</span>
			{:else}
				<a href={resolve(crumb.route)}>{crumb.title}</a>
			{/if}
		{/each}
	</nav>
	<div class="content-title-row">
		<div>
			<div class="eyebrow">
				{content.kind === 'directory'
					? 'Documentation section'
					: 'Documentation'}
			</div>
			<h1>{content.title}</h1>
			{#if !content.code}<p>{content.description}</p>{/if}
		</div>
	</div>
</header>

<div class={`content-layout${toc.length > 0 ? ' with-toc' : ''}`}>
	{#if toc.length > 0}
		<aside class="content-toc" aria-label="On this page">
			<SectionLabel>On this page</SectionLabel>
			<nav bind:this={tocNavigation}>
				{#each toc as heading (heading.id)}
					<a
						class={heading.level > 2 ? 'toc-nested' : undefined}
						href={`#${heading.id}`}
						aria-current={activeHeading === heading.id
							? 'location'
							: undefined}>{heading.text}</a
					>
				{/each}
			</nav>
		</aside>
	{/if}

	<article class="content-copy">
		<p class="copy-status" aria-live="polite">{copyStatus}</p>
		{#if content.html}
			{@html content.html}
		{:else}
			<p class="empty-directory-note">Choose a page below</p>
		{/if}

		{#if content.kind === 'directory' && visibleChildren.length > 0}
			<section
				class="directory-children"
				aria-labelledby="section-contents"
			>
				<div class="directory-heading" id="section-contents">
					<SectionLabel>In this section</SectionLabel>
				</div>
				<nav class="directory-list" aria-label="Pages in this section">
					{#each visibleChildren as entry (entry.route)}
						<a href={resolve(entry.route)}>
							<span>
								<strong>{entry.title}</strong>
								<small>{entry.description}</small>
							</span>
							<span aria-hidden="true">→</span>
						</a>
					{/each}
				</nav>
			</section>
		{/if}
	</article>
</div>

{#if neighbors.previous || neighbors.next}
	<nav class="page-neighbors" aria-label="Adjacent documentation pages">
		{#if neighbors.previous}
			<a href={resolve(neighbors.previous.route)}>
				<small>Previous</small>
				<strong>← {neighbors.previous.title}</strong>
			</a>
		{:else}<span></span>{/if}
		{#if neighbors.next}
			<a class="next-page" href={resolve(neighbors.next.route)}>
				<small>Next</small>
				<strong>{neighbors.next.title} →</strong>
			</a>
		{/if}
	</nav>
{/if}

{#if hasMermaid}
	{#key content.route}
		<MermaidEnhancer route={content.route} />
	{/key}
{/if}

<style>
	.content-header {
		border-bottom: 1px solid var(--site-line);
		margin: clamp(1rem, 3vw, 2.5rem) 0 1.5rem;
		padding-bottom: 1.2rem;
	}

	.breadcrumbs {
		display: flex;
		align-items: center;
		flex-wrap: wrap;
		gap: 0.35rem;
		margin-bottom: 1.2rem;
		color: var(--color-anasthasia-muted);
		font-family: var(--font-anasthasia-mono);
		font-size: 0.6rem;
		letter-spacing: 0.04em;
		text-transform: uppercase;
	}

	.breadcrumbs a {
		color: inherit;
		text-decoration: none;
	}

	.breadcrumbs a:hover {
		color: var(--color-anasthasia-text);
	}

	.content-title-row {
		display: flex;
		align-items: flex-start;
		justify-content: space-between;
		gap: 1.5rem;
	}

	.content-title-row h1 {
		margin: 0.45rem 0 0;
		font-size: clamp(1.9rem, 3.2vw, 2.85rem);
		letter-spacing: -0.045em;
		line-height: 1;
	}

	.content-title-row p {
		margin: 0.65rem 0 0;
		color: var(--color-anasthasia-muted);
		font-size: 0.9rem;
	}

	.content-layout {
		position: relative;
	}

	.content-layout.with-toc {
		display: grid;
		grid-template-columns: minmax(0, 1fr) 11rem;
		grid-template-areas: 'copy toc';
		gap: 1.5rem;
	}

	.content-copy {
		grid-area: copy;
		min-width: 0;
	}

	.copy-status {
		position: absolute;
		width: 1px;
		height: 1px;
		padding: 0;
		clip: rect(0, 0, 0, 0);
		clip-path: inset(50%);
		overflow: hidden;
		white-space: nowrap;
	}

	.content-copy :global(.heading-link) {
		display: inline-grid;
		min-width: 2.75rem;
		min-height: 2.75rem;
		place-items: center;
		margin-left: 0.4em;
		color: var(--color-anasthasia-muted);
		font-family: var(--font-anasthasia-mono);
		font-size: 0.72em;
		font-weight: 500;
		line-height: 1;
		opacity: 0;
		text-decoration: none;
		vertical-align: middle;
		transition:
			opacity 120ms ease,
			color 120ms ease;
	}

	.content-copy :global(:is(h2, h3, h4, h5, h6):hover .heading-link),
	.content-copy :global(.heading-link:focus-visible),
	.content-copy :global(.heading-link[data-copied='true']) {
		opacity: 1;
	}

	@media (hover: none), (pointer: coarse) {
		.content-copy :global(.heading-link) {
			opacity: 1;
		}
	}

	.content-copy :global(.heading-link:hover),
	.content-copy :global(.heading-link:focus-visible) {
		color: var(--color-anasthasia-accent);
	}

	.content-copy :global(.heading-link[data-copied='true']) {
		color: var(--color-anasthasia-success);
	}

	.empty-directory-note {
		border-left: 2px solid var(--color-anasthasia-text);
		padding-left: 0.8rem;
	}

	.content-toc {
		grid-area: toc;
		position: sticky;
		top: 1.25rem;
		align-self: start;
		display: flex;
		max-height: calc(100dvh - 2.5rem);
		flex-direction: column;
		border-left: 1px solid var(--site-line);
		padding-left: 0.8rem;
		overflow: hidden;
	}

	.content-toc nav {
		display: grid;
		min-height: 0;
		gap: 0.15rem;
		margin-top: 0.6rem;
		overflow-y: auto;
		overscroll-behavior: contain;
		scrollbar-gutter: stable;
	}

	.content-toc a {
		border-left: 2px solid transparent;
		padding: 0.22rem 0.4rem;
		color: var(--color-anasthasia-muted);
		font-size: 0.7rem;
		line-height: 1.35;
		text-decoration: none;
	}

	.content-toc a:hover,
	.content-toc a[aria-current='location'] {
		color: var(--color-anasthasia-text);
	}

	.content-toc a[aria-current='location'] {
		border-left-color: var(--color-anasthasia-text);
		background: color-mix(
			in srgb,
			var(--color-anasthasia-text) 8%,
			transparent
		);
		font-weight: 700;
	}

	.content-toc a.toc-nested {
		padding-left: 0.8rem;
		font-size: 0.66rem;
	}

	.directory-children {
		border-top: 1px solid var(--site-line);
		margin-top: 2rem;
		padding-top: 1rem;
	}

	.directory-heading {
		margin-bottom: 0.6rem;
	}

	.directory-list {
		display: grid;
	}

	.directory-list a {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 1.5rem;
		border-bottom: 1px solid var(--site-line);
		padding: 0.75rem 0;
		color: var(--color-anasthasia-text);
		text-decoration: none;
	}

	.directory-list a:first-child {
		border-top: 1px solid var(--site-line);
	}

	.directory-list strong,
	.directory-list small {
		display: block;
	}

	.directory-list strong {
		font-size: 0.85rem;
	}

	.directory-list small {
		margin-top: 0.2rem;
		color: var(--color-anasthasia-muted);
		font-size: 0.7rem;
	}

	.page-neighbors {
		display: grid;
		grid-template-columns: repeat(2, minmax(0, 1fr));
		gap: 1rem;
		border-top: 1px solid var(--site-line);
		margin-top: 2rem;
		padding-top: 1rem;
	}

	.page-neighbors a {
		display: grid;
		gap: 0.2rem;
		color: var(--color-anasthasia-text);
		text-decoration: none;
	}

	.page-neighbors a:hover strong {
		text-decoration: underline;
		text-underline-offset: 0.2em;
	}

	.page-neighbors small {
		color: var(--color-anasthasia-muted);
		font-family: var(--font-anasthasia-mono);
		font-size: 0.6rem;
		text-transform: uppercase;
	}

	.next-page {
		text-align: right;
	}

	@media (max-width: 1100px) {
		.content-layout.with-toc {
			display: grid;
			grid-template-columns: 1fr;
			grid-template-areas: 'toc' 'copy';
		}

		.content-toc {
			position: static;
			display: block;
			max-height: none;
			border-top: 1px solid var(--site-line);
			border-left: 0;
			margin-top: 2rem;
			padding: 1rem 0 0;
			overflow: visible;
		}

		.content-toc nav {
			overflow: visible;
			scrollbar-gutter: auto;
		}
	}

	@media (max-width: 760px) {
		.content-title-row {
			flex-direction: column;
		}

		.page-neighbors {
			grid-template-columns: 1fr;
		}

		.page-neighbors > span {
			display: none;
		}

		.next-page {
			text-align: left;
		}
	}
</style>
