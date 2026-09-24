<script lang="ts">
	import { resolve } from '$app/paths';
	import { onMount, tick } from 'svelte';
	import { SlideIndicator } from '$lib/motion.svelte.js';
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
		breadcrumbs?: Array<{ title: string; route: SiteRoute }>;
	}

	let { content, neighbors = {}, breadcrumbs = [] }: Props = $props();
	let activeHeading = $state('');
	let tocNavigation = $state<HTMLElement>();
	let copyStatus = $state('');
	const tocIndicator = new SlideIndicator();

	// The accent segment follows the active heading along the table of contents track.
	function trackHeading(node: HTMLElement) {
		void activeHeading;
		void tick().then(() =>
			tocIndicator.move(
				node.querySelector<HTMLElement>('[aria-current="location"]')
			)
		);
	}
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
	const breadcrumbTrail = $derived.by(
		(): Array<{ title: string; route: SiteRoute }> => {
			if (breadcrumbs.length) return breadcrumbs;
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
		{#each breadcrumbTrail as crumb, index (crumb.route)}
			<span aria-hidden="true">/</span>
			{#if index === breadcrumbTrail.length - 1}
				<span aria-current="page">{crumb.title}</span>
			{:else}
				<a href={resolve(crumb.route)}>{crumb.title}</a>
			{/if}
		{/each}
	</nav>
	<div class="page-heading">
		<h1>{content.title}</h1>
		{#if !content.code}<p>{content.description}</p>{/if}
	</div>
</header>

<div class={`content-layout${toc.length > 0 ? ' with-toc' : ''}`}>
	{#if toc.length > 0}
		<aside class="content-toc" aria-label="On this page">
			<p class="toc-label">On this page</p>
			<nav bind:this={tocNavigation} {@attach trackHeading}>
				<span
					class="toc-indicator"
					class:visible={tocIndicator.visible}
					style:transform={`translateY(${tocIndicator.top}px)`}
					style:height={`${tocIndicator.height}px`}
					aria-hidden="true"
				></span>
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
				class="directory-children panel"
				aria-labelledby="section-contents"
			>
				<h2 class="panel-title" id="section-contents">
					In this section
				</h2>
				<nav class="row-list" aria-label="Pages in this section">
					{#each visibleChildren as entry (entry.route)}
						<a href={resolve(entry.route)}>
							<span>
								<strong>{entry.title}</strong>
								<small>{entry.description}</small>
							</span>
							<span class="chevron" aria-hidden="true">›</span>
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
		margin-bottom: var(--site-space-8);
	}

	.breadcrumbs {
		display: flex;
		align-items: center;
		flex-wrap: wrap;
		gap: 0.4rem;
		margin-bottom: var(--site-space-4);
		color: var(--site-faint);
		font-size: 0.8rem;
	}

	.breadcrumbs a {
		color: var(--site-muted);
		text-decoration: none;
	}

	.breadcrumbs a:hover {
		color: var(--site-text);
	}

	.content-layout {
		position: relative;
	}

	.content-layout.with-toc {
		display: grid;
		grid-template-columns: minmax(0, 1fr) 15rem;
		grid-template-areas: 'copy toc';
		gap: var(--site-space-8);
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

	/* The glyph sits right after the heading text; a transparent overlay keeps a 44px target. */
	.content-copy :global(.heading-link) {
		position: relative;
		margin-left: 0.3em;
		color: var(--site-faint);
		font-family: var(--site-font-mono);
		font-size: 0.8em;
		font-weight: 500;
		opacity: 0;
		text-decoration: none;
		transition:
			opacity var(--site-motion-fast) ease,
			color var(--site-motion-fast) ease;
	}

	.content-copy :global(.heading-link::after) {
		position: absolute;
		top: 50%;
		left: 50%;
		width: var(--site-touch-target);
		height: var(--site-touch-target);
		transform: translate(-50%, -50%);
		content: '';
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
		color: var(--site-signal-text);
	}

	.content-copy :global(.heading-link[data-copied='true']) {
		color: var(--site-success);
	}

	.empty-directory-note {
		color: var(--site-muted);
	}

	.content-toc {
		grid-area: toc;
		position: sticky;
		top: var(--site-space-6);
		align-self: start;
		display: flex;
		max-height: calc(100dvh - 3rem);
		flex-direction: column;
		overflow: hidden;
	}

	.toc-label {
		margin: 0 0 var(--site-space-3);
		color: var(--site-faint);
		font-family: var(--site-font-mono);
		font-size: 0.7rem;
		letter-spacing: 0.18em;
		text-transform: uppercase;
	}

	/* A hairline track with a gliding accent segment, the launcher's page-heading motif. */
	.content-toc nav {
		position: relative;
		display: grid;
		min-height: 0;
		border-left: 1px solid var(--site-line);
		overflow-y: auto;
		overscroll-behavior: contain;
	}

	.toc-indicator {
		position: absolute;
		top: 0;
		left: -1px;
		width: 2px;
		border-radius: var(--site-radius-capsule);
		background: var(--site-signal);
		opacity: 0;
		pointer-events: none;
	}

	.toc-indicator.visible {
		opacity: 1;
	}

	.content-toc a {
		padding: 0.4rem 0 0.4rem var(--site-space-4);
		color: var(--site-faint);
		font-size: 0.84rem;
		line-height: 1.4;
		text-decoration: none;
		transition: color var(--site-motion-fast) ease;
	}

	.content-toc a:hover {
		color: var(--site-text);
	}

	.content-toc a[aria-current='location'] {
		color: var(--site-signal-text);
		font-weight: 600;
	}

	.content-toc a.toc-nested {
		padding-left: calc(var(--site-space-4) + 0.75rem);
		font-size: 0.8rem;
	}

	.directory-children {
		margin-top: var(--site-space-8);
	}

	.page-neighbors {
		display: grid;
		grid-template-columns: repeat(2, minmax(0, 1fr));
		gap: var(--site-space-4);
		margin-top: var(--site-space-12);
	}

	.page-neighbors a {
		display: grid;
		gap: 0.2rem;
		border: 1px solid var(--site-border);
		border-radius: var(--site-radius-panel);
		background: var(--site-panel);
		padding: var(--site-space-4) var(--site-space-5);
		color: var(--site-text);
		text-decoration: none;
		transition: border-color var(--site-motion-fast) ease;
	}

	.page-neighbors a:hover {
		border-color: var(--site-signal-border);
	}

	.page-neighbors small {
		color: var(--site-faint);
		font-size: 0.75rem;
	}

	.page-neighbors strong {
		font-weight: 600;
	}

	.next-page {
		text-align: right;
	}

	@media (max-width: 1100px) {
		.content-layout.with-toc {
			grid-template-columns: 1fr;
			grid-template-areas: 'toc' 'copy';
			gap: 0;
		}

		.content-toc {
			position: static;
			display: block;
			max-height: none;
			border: 1px solid var(--site-border);
			border-radius: var(--site-radius-panel);
			background: var(--site-panel);
			margin-bottom: var(--site-space-8);
			padding: var(--site-space-4);
			overflow: visible;
		}

		.content-toc nav {
			overflow: visible;
		}
	}

	@media (max-width: 760px) {
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
