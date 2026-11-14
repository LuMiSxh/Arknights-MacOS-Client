<script lang="ts">
	import { base, resolve } from '$app/paths';
	import PageMetadata from '$lib/components/PageMetadata.svelte';
	import PublisherCards from '$lib/components/PublisherCards.svelte';

	import { servers } from '$lib/servers.js';
	import {
		absoluteSiteUrl,
		normalizeBasePath,
		releaseUrl
	} from '$lib/site.js';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();

	const version = $derived(data.release?.version);
	const description =
		'Play Arknights PC on an Apple silicon Mac with this free, unofficial launcher. Supports macOS 15 or later.';
	const basePath = normalizeBasePath(
		typeof process !== 'undefined' && process.env.BASE_PATH
			? process.env.BASE_PATH
			: base
	);
	const homeUrl = absoluteSiteUrl('/', basePath);
	const structuredData = $derived(
		JSON.stringify({
			'@context': 'https://schema.org',
			'@graph': [
				{
					'@type': 'WebSite',
					'@id': `${homeUrl}#website`,
					name: 'Arknights Client',
					alternateName: [
						'Arknights macOS Client',
						'Arknights-MacOS-Client'
					],
					url: homeUrl
				},
				{
					'@type': 'SoftwareApplication',
					'@id': `${homeUrl}#app`,
					name: 'Arknights Client',
					applicationCategory: 'GameApplication',
					operatingSystem: 'macOS 15 or later',
					softwareVersion: version,
					description,
					url: homeUrl,
					downloadUrl: releaseUrl,
					offers: {
						'@type': 'Offer',
						price: '0',
						priceCurrency: 'USD'
					}
				}
			]
		}).replace(/</g, '\\u003c')
	);
</script>

{#snippet externalIcon()}
	<svg viewBox="0 0 24 24" width="14" height="14" aria-hidden="true">
		<path
			d="M13.5 4H20v6.5M20 4l-9 9M18 14v4.5a1.5 1.5 0 0 1-1.5 1.5h-11A1.5 1.5 0 0 1 4 18.5v-11A1.5 1.5 0 0 1 5.5 6H10"
			fill="none"
			stroke="currentColor"
			stroke-width="1.8"
			stroke-linecap="round"
			stroke-linejoin="round"
		/>
	</svg>
{/snippet}

<svelte:head>
	<meta
		name="google-site-verification"
		content="rKSkIR3sV4QdLRzh6LfguydNElkuRCFjlw7EIqDHnyI"
	/>
	{@html `<script type="application/ld+json">${structuredData}</script>`}
</svelte:head>

<PageMetadata
	title="Play Arknights PC on Mac · Arknights Client"
	{description}
	path="/"
/>

<section class="hero" aria-labelledby="hero-title">
	<div class="hero-hud">
		<div class="hero-pills">
			<p class="hero-status glass-surface">
				Free · macOS 15 or later
				{#if version}· Version {version}{/if}
			</p>
		</div>
		<div class="hero-bar glass-surface glass-float">
			<div class="hero-copy">
				<h1 id="hero-title">
					Play Arknights PC on your Apple silicon Mac
				</h1>
			</div>
			<div class="hero-actions">
				<a class="quiet-action" href={resolve('/installation/')}>
					Installation guide
				</a>
				<a class="accent-action" href={releaseUrl}>
					Download
					{@render externalIcon()}
					<span class="sr-only"> (opens GitHub Releases)</span>
				</a>
			</div>
		</div>
	</div>
</section>

<div class="home-content home-sheet">
	<section class="home-section" aria-labelledby="servers-title">
		<h2 id="servers-title">Servers</h2>
		<p class="section-description">
			Choose your server in the setup assistant.
		</p>
		<PublisherCards {servers} />
		<p class="section-note">
			The publisher handles accounts and payments.
			<a href={`${resolve('/help/')}#publisher-support-routing`}
				>See publisher support</a
			>.
		</p>
	</section>

	<section class="home-section" aria-labelledby="requirements-title">
		<h2 id="requirements-title">Requirements</h2>
		<div class="band">
			<div>
				<h3>What you need</h3>
				<ul class="requirement-list">
					<li>
						An Apple silicon Mac: an M-series Mac, or the MacBook
						Neo (A18 Pro)
					</li>
					<li>An account for your server</li>
					<li>
						An internet connection and free space for the game and
						its updates
					</li>
				</ul>
			</div>
			<div>
				<h3>Get started</h3>
				<ol class="steps">
					<li>
						<span class="step-text"
							>Download the DMG and drag <strong
								>Arknights Client</strong
							>
							to <strong>Applications</strong>.</span
						>
					</li>
					<li>
						<span class="step-text"
							>If macOS blocks the app, <a
								href={`${resolve('/installation/')}#if-macos-blocks-the-app`}
								>follow the steps</a
							>
							and choose <strong>Open Anyway</strong>.</span
						>
					</li>
					<li>
						<span class="step-text"
							>Open the app and follow the setup assistant. Choose
							your server.</span
						>
					</li>
				</ol>
			</div>
		</div>

		<h3 class="strip-title">Runtime by macOS version</h3>
		<ul class="runtime-strip">
			<li>
				<a href={resolve('/performance/')}>
					<span>macOS 15–25</span>
					<span>x86_64 · Rosetta 2</span>
				</a>
			</li>
			<li class="is-recommended">
				<a href={resolve('/performance/')}>
					<span>macOS 26–27</span>
					<span>ARM64 recommended</span>
				</a>
			</li>
			<li>
				<a href={resolve('/performance/')}>
					<span>macOS 28+</span>
					<span>ARM64 only</span>
				</a>
			</li>
		</ul>
		<p class="footnote">
			Runs the official PC client through Wine and DXMT. Read about
			<a href={resolve('/performance/')}>Performance</a>.
		</p>
	</section>

	<section class="home-section" aria-labelledby="whats-new-title">
		<h2 id="whats-new-title">What's new</h2>
		<div class="split">
			<div class="release-card">
				{#if data.release}
					<p class="release-head">
						<strong>Version {data.release.version}</strong>
						<time datetime={data.release.date}
							>{data.release.date}</time
						>
					</p>
					{#if data.release.items.length}
						<ul class="release-items">
							{#each data.release.items.slice(0, 3) as item, index (index)}
								<li>
									{#if data.release.categorized}
										<span class="release-category"
											>{item.category}</span
										>
									{/if}
									{#each item.segments as segment, segmentIndex (segmentIndex)}
										{#if segment.strong}<strong
												>{segment.text}</strong
											>{:else}{segment.text}{/if}
									{/each}
								</li>
							{/each}
						</ul>
					{/if}
				{/if}
				<a class="panel-link" href={resolve('/changelog/')}
					>Read the changelog</a
				>
			</div>
			{#if data.post}
				<a class="post-card" href={resolve(data.post.route)}>
					<time datetime={data.post.date}>{data.post.date}</time>
					<strong>{data.post.title}</strong>
					<span>{data.post.summary}</span>
				</a>
			{/if}
		</div>
	</section>

	<section class="home-section" aria-labelledby="help-title">
		<h2 id="help-title">Need help?</h2>
		<nav class="help-tiles" aria-label="Help pages">
			<a class="help-tile" href={resolve('/help/troubleshooting/')}>
				<span class="help-tile-text">
					<strong>Troubleshooting</strong>
					<small>Fix launch, download, and sign-in problems.</small>
				</span>
				<span class="chevron" aria-hidden="true">›</span>
			</a>
			<a class="help-tile" href={resolve('/help/errors/')}>
				<span class="help-tile-text">
					<strong>Error codes</strong>
					<small>Find the code you see and its next step.</small>
				</span>
				<span class="chevron" aria-hidden="true">›</span>
			</a>
			<a class="help-tile" href={resolve('/help/faq/')}>
				<span class="help-tile-text">
					<strong>FAQ</strong>
					<small>Answers to common questions.</small>
				</span>
				<span class="chevron" aria-hidden="true">›</span>
			</a>
			<a class="help-tile" href={`${resolve('/help/')}#report-a-problem`}>
				<span class="help-tile-text">
					<strong>Report a problem</strong>
					<small
						>Choose <b>Help → Report a Problem…</b> in the app.</small
					>
				</span>
				<span class="chevron" aria-hidden="true">›</span>
			</a>
		</nav>
	</section>
</div>

<style>
	.hero {
		display: flex;
		/* 16:9 artwork height, capped so the HUD pill stays above the fold below the top bar. */
		min-height: min(56.25vw, calc(100svh - var(--top-bar-height)));
		flex-direction: column;
		justify-content: flex-end;
		padding: 0 var(--site-gutter) var(--site-space-5);
	}

	/* Mirrors the client Home HUD: a trailing pill row above a full-width control bar. */
	.hero-hud {
		display: grid;
		gap: var(--site-space-3);
	}

	.hero-pills {
		display: flex;
		justify-content: flex-end;
		padding-right: 2px;
	}

	.hero-status {
		--glass-tint: rgb(19 20 23 / 0.8);
		border-radius: var(--site-radius-capsule);
	}

	/* Capsule like the buttons; the stacked mobile bar uses a fixed radius so the h1 stays inside the curve. */
	.hero-bar {
		--glass-tint: rgb(19 20 23 / 0.8);
		border-radius: var(--site-radius-capsule);
	}

	/* Collapsed pill: 28 pt tall with 12 pt by 6 pt padding and caption type. */
	.hero-status {
		display: inline-flex;
		min-height: 1.75rem;
		align-items: center;
		margin: 0;
		padding: 0.375rem 0.75rem;
		color: var(--site-text-secondary);
		font-size: 0.75rem;
		font-weight: 500;
		font-variant-numeric: tabular-nums;
	}

	/* Control bar: 16 pt panel padding, leading title, trailing actions. */
	.hero-bar {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: var(--site-space-4);
		padding: var(--site-space-4);
	}

	.hero-copy {
		min-width: 0;
	}

	.hero h1 {
		margin: 0;
		font-size: 1.375rem;
		font-weight: 500;
		line-height: 1.2;
		letter-spacing: -0.01em;
	}

	.hero-actions {
		display: flex;
		flex: none;
		flex-wrap: wrap;
		align-items: center;
		gap: var(--site-space-2);
	}

	/* Secondary control is 34 pt tall. The primary control is 38 pt. */
	.accent-action,
	.quiet-action {
		display: inline-flex;
		min-height: 2.125rem;
		align-items: center;
		gap: var(--site-space-2);
		border: 1px solid var(--site-hairline);
		border-radius: var(--site-radius-capsule);
		padding: 0 var(--site-space-4);
		font-size: 0.8125rem;
		font-weight: 500;
		text-decoration: none;
	}

	/* The accent tint sits over a dark base, so the label stays readable on bright artwork. */
	.accent-action {
		position: relative;
		isolation: isolate;
		min-height: 2.375rem;
		border-color: var(--site-accent-glass-stroke);
		background:
			linear-gradient(
				var(--site-accent-glass-tint),
				var(--site-accent-glass-tint)
			),
			var(--site-sheet);
		color: var(--site-accent-ink);
	}

	/* The client's accent halo: a static glow behind the primary action, with one arrival pulse. */
	.accent-action::before {
		position: absolute;
		z-index: -1;
		inset: -6px;
		border-radius: inherit;
		background: var(--site-accent-fill);
		opacity: 0.1125;
		filter: blur(5px);
		content: '';
	}

	@media (prefers-reduced-motion: no-preference) {
		.accent-action::before {
			animation: hero-halo-arrive var(--site-dur-present)
				var(--site-ease-state) 1 both;
		}
	}

	@media (prefers-reduced-transparency: reduce) {
		.accent-action::before {
			display: none;
		}
	}

	@keyframes hero-halo-arrive {
		50% {
			opacity: 0.25;
		}
	}

	.quiet-action {
		background: var(--site-control-fill);
		color: var(--site-text-primary);
	}

	/* Landing sections: one centered column, each section with its own shape. */
	.home-content {
		padding-block: calc(var(--site-space-12) * 2);
	}

	.home-content strong {
		font-weight: 500;
	}

	.home-section {
		max-width: 1100px;
		margin-inline: auto;
	}

	.home-section + .home-section {
		margin-top: calc(var(--site-space-12) * 2);
	}

	.home-section > h2 {
		margin: 0 0 var(--site-space-6);
		font-size: 1.375rem;
		font-weight: 500;
		line-height: 1.25;
	}

	.home-section > h2:has(+ .section-description) {
		margin-bottom: var(--site-space-2);
	}

	.section-description {
		margin: 0 0 var(--site-space-6);
		color: var(--site-text-secondary);
		font-size: 0.95rem;
	}

	.section-note,
	.footnote {
		margin: var(--site-space-4) 0 0;
		color: var(--site-text-secondary);
		font-size: 0.85rem;
	}

	.footnote {
		color: var(--site-text-tertiary);
		font-family: var(--site-font-mono);
		font-size: 0.75rem;
	}

	.band {
		display: grid;
		grid-template-columns: repeat(2, minmax(0, 1fr));
		gap: var(--site-space-8);
	}

	.band h3,
	.strip-title {
		margin: 0 0 var(--site-space-3);
		color: var(--site-text-primary);
		font-size: 1rem;
		font-weight: 500;
	}

	.requirement-list,
	.steps {
		margin: 0;
		padding: 0;
		color: var(--site-text-secondary);
		font-size: 0.9rem;
		list-style: none;
	}

	.requirement-list li,
	.steps li {
		display: flex;
		gap: var(--site-space-4);
		padding: var(--site-space-3) 0;
	}

	.requirement-list li + li,
	.steps li + li {
		border-top: 1px solid var(--site-hairline);
	}

	.steps {
		counter-reset: step;
	}

	.steps li {
		counter-increment: step;
	}

	.steps li::before {
		flex: none;
		width: 1.25rem;
		color: var(--site-accent-ink);
		font-family: var(--site-font-mono);
		content: counter(step);
	}

	.strip-title {
		margin-top: var(--site-space-8);
	}

	.runtime-strip {
		display: grid;
		grid-template-columns: repeat(3, minmax(0, 1fr));
		margin: 0;
		padding: 0;
		border: 1px solid var(--site-hairline);
		border-radius: var(--site-radius-group);
		overflow: hidden;
		list-style: none;
	}

	.runtime-strip li + li {
		border-left: 1px solid var(--site-hairline);
	}

	.runtime-strip a {
		display: grid;
		gap: var(--site-space-1);
		height: 100%;
		padding: var(--site-space-4) var(--site-space-5);
		color: var(--site-text-primary);
		font-family: var(--site-font-mono);
		font-size: 0.8125rem;
		text-decoration: none;
		transition: background-color var(--site-dur-state)
			var(--site-ease-state);
	}

	.runtime-strip a:hover {
		background: var(--site-control-fill);
	}

	.runtime-strip a span:last-child {
		color: var(--site-text-secondary);
		font-size: 0.75rem;
	}

	.runtime-strip .is-recommended a span:last-child {
		color: var(--site-accent-ink);
	}

	.split {
		display: grid;
		grid-template-columns: minmax(0, 2fr) minmax(0, 1fr);
		gap: var(--site-space-4);
	}

	.split > :only-child {
		grid-column: 1 / -1;
	}

	.release-card,
	.post-card {
		border: 1px solid var(--site-hairline);
		border-radius: var(--site-radius-group);
		background: var(--site-group-fill);
		padding: var(--site-space-5) var(--site-space-6);
	}

	.release-head {
		margin: 0;
		color: var(--site-text-secondary);
	}

	.release-head strong {
		color: var(--site-text-primary);
	}

	.release-items {
		margin: var(--site-space-3) 0 0;
		padding: 0;
		color: var(--site-text-secondary);
		font-size: 0.9rem;
		list-style: none;
	}

	.release-items li {
		padding: var(--site-space-3) 0;
	}

	.release-items li + li {
		border-top: 1px solid var(--site-hairline);
	}

	.release-category {
		margin-right: var(--site-space-2);
		color: var(--site-accent-ink);
		font-family: var(--site-font-mono);
		font-size: 0.75rem;
	}

	.panel-link {
		display: inline-block;
		margin-top: var(--site-space-4);
		color: var(--site-accent-ink);
		font-size: 0.9rem;
		text-decoration: none;
	}

	.post-card {
		display: grid;
		align-content: start;
		gap: var(--site-space-2);
		color: var(--site-text-secondary);
		font-size: 0.9rem;
		text-decoration: none;
		transition: border-color var(--site-dur-state) var(--site-ease-state);
	}

	.post-card:hover {
		border-color: color-mix(
			in srgb,
			var(--site-accent-ink) 45%,
			transparent
		);
	}

	.post-card time {
		color: var(--site-text-tertiary);
		font-family: var(--site-font-mono);
		font-size: 0.75rem;
	}

	.post-card strong {
		color: var(--site-text-primary);
		font-size: 1rem;
		font-weight: 500;
	}

	.help-tiles {
		display: grid;
		grid-template-columns: repeat(4, minmax(0, 1fr));
		gap: var(--site-space-3);
	}

	.help-tile {
		display: flex;
		align-items: flex-start;
		justify-content: space-between;
		gap: var(--site-space-3);
		border: 1px solid var(--site-hairline);
		border-radius: var(--site-radius-group);
		background: var(--site-group-fill);
		padding: var(--site-space-4);
		color: var(--site-text-primary);
		text-decoration: none;
		transition: border-color var(--site-dur-state) var(--site-ease-state);
	}

	.help-tile-text {
		display: grid;
		gap: var(--site-space-1);
		line-height: 1.3;
	}

	.help-tile > .chevron {
		align-self: center;
	}

	.help-tile small {
		color: var(--site-text-tertiary);
		font-size: 0.8rem;
		line-height: 1.4;
	}

	.help-tile:hover {
		border-color: color-mix(
			in srgb,
			var(--site-accent-ink) 45%,
			transparent
		);
	}

	.help-tile:hover .chevron {
		color: var(--site-accent-ink);
	}

	@media (max-width: 760px) {
		.home-content {
			padding-block: calc(var(--site-space-8) * 2);
		}

		.home-section + .home-section {
			margin-top: calc(var(--site-space-8) * 2);
		}

		.band,
		.split,
		.runtime-strip {
			grid-template-columns: minmax(0, 1fr);
		}

		.band {
			gap: var(--site-space-6);
		}

		.runtime-strip li + li {
			border-left: 0;
			border-top: 1px solid var(--site-hairline);
		}

		.help-tiles {
			grid-template-columns: repeat(2, minmax(0, 1fr));
		}
	}

	.hero-status {
		margin: 0;
		color: var(--site-text-secondary);
		font-family: var(--site-font-ui);
		font-size: 0.875rem;
	}

	@media (max-width: 760px) {
		.hero {
			min-height: 0;
			padding: 0 var(--site-space-4) var(--site-space-4);
		}

		/* The HUD starts 48px above the artwork's bottom edge, so the artwork stays visible above it. */
		.hero-hud {
			margin-top: calc(56.25vw - var(--site-space-12));
		}

		.hero-bar {
			flex-direction: column;
			align-items: stretch;
			border-radius: 28px;
		}

		.hero-actions {
			flex-direction: column-reverse;
			align-items: stretch;
		}

		.accent-action,
		.quiet-action {
			min-height: var(--site-touch-target);
			justify-content: center;
		}
	}
</style>
