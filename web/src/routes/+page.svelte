<script lang="ts">
	import { asset, resolve } from '$app/paths';
	import ArtworkStage from '$lib/components/ArtworkStage.svelte';
	import PageMetadata from '$lib/components/PageMetadata.svelte';
	import RegionManifest from '$lib/components/RegionManifest.svelte';
	import { reveal } from '$lib/motion.svelte.js';
	import { releaseUrl } from '$lib/site.js';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();

	const regions = [
		{ name: 'Global', publisher: 'Yostar', status: 'Supported' },
		{ name: 'Japan', publisher: 'Yostar', status: 'Supported' },
		{ name: 'Korea', publisher: 'Yostar', status: 'Supported' },
		{ name: 'Taiwan', publisher: 'Gryphline', status: 'Canary' },
		{ name: 'China', publisher: 'Hypergryph', status: 'Canary' },
		{ name: 'China — Bilibili', publisher: 'Hypergryph', status: 'Canary' }
	] as const;
	const route = [
		'Apple Silicon',
		'Rosetta 2',
		'Wine + DXMT',
		'Official PC client'
	];

	const guides = $derived(
		data.navigation.filter((entry) => entry.audience !== 'developers')
	);
</script>

<PageMetadata
	title="Arknights Client · macOS launcher"
	description="A native macOS launcher for official regional Arknights PC clients."
	path="/"
/>

<ArtworkStage
	title="Arknights on macOS"
	detail="Unofficial launcher for the official Arknights PC clients"
	iconUrl={asset('/AppIcon-128.png')}
	installationHref={resolve('/installation/')}
	releaseHref={releaseUrl}
/>

<div class="home-content home-sheet">
	<header class="page-heading">
		<h2>Play the official PC client on your Mac</h2>
		<p>
			The launcher installs the game, keeps it updated, and collects the
			logs needed when something goes wrong.
		</p>
		<ol class="route" aria-label="Compatibility route">
			{#each route as step (step)}
				<li>{step}</li>
			{/each}
		</ol>
	</header>

	<div class="home-grid">
		<section class="panel" aria-label="Regions" {@attach reveal()}>
			<RegionManifest {regions} />
		</section>

		<section
			class="panel guides"
			aria-labelledby="guides-title"
			{@attach reveal(90)}
		>
			<h2 class="panel-title" id="guides-title">Documentation</h2>
			<nav class="row-list" aria-label="Documentation sections">
				{#each guides as guide (guide.route)}
					<a href={resolve(guide.route)}>
						<span>
							<strong>{guide.title}</strong>
							<small>{guide.description}</small>
						</span>
						<span class="chevron" aria-hidden="true">›</span>
					</a>
				{/each}
			</nav>
		</section>
	</div>
</div>

<style>
	.home-content {
		border-radius: var(--site-radius-modal) var(--site-radius-modal) 0 0;
		margin-top: var(--site-space-6);
		padding-block: var(--site-space-8) var(--site-space-12);
	}

	.route {
		display: flex;
		flex-wrap: wrap;
		gap: var(--site-space-2);
		margin: var(--site-space-4) 0 0;
		padding: 0;
		list-style: none;
	}

	.route li {
		border: 1px solid var(--site-border);
		border-radius: var(--site-radius-capsule);
		background: var(--site-panel);
		padding: 0.3rem 0.75rem;
		color: var(--site-muted);
		font-family: var(--site-font-mono);
		font-size: 0.7rem;
	}

	.route li:not(:last-child)::after {
		margin-left: var(--site-space-2);
		color: var(--site-signal-text);
		content: '→';
	}

	.home-grid {
		display: grid;
		grid-template-columns: repeat(2, minmax(0, 1fr));
		align-items: stretch;
		gap: var(--site-space-5);
		margin-top: var(--site-space-8);
	}

	/* Rows share the card height so both cards end on the same line. */
	.guides {
		display: flex;
		flex-direction: column;
	}

	.guides .row-list {
		flex: 1;
		grid-auto-rows: 1fr;
	}

	@media (max-width: 860px) {
		.home-grid {
			grid-template-columns: 1fr;
		}
	}
</style>
