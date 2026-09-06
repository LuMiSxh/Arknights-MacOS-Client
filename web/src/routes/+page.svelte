<script lang="ts">
	import { resolve } from '$app/paths';
	import { Badge, SectionLabel } from 'anasthasia';
	import PageMetadata from '$lib/components/PageMetadata.svelte';
	import { releaseUrl, repositoryUrl } from '$lib/site.js';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();

	const regions = [
		{
			name: 'Global',
			publisher: 'Yostar',
			status: 'Supported',
			variant: 'success'
		},
		{
			name: 'Japan',
			publisher: 'Yostar',
			status: 'Supported',
			variant: 'success'
		},
		{
			name: 'Korea',
			publisher: 'Yostar',
			status: 'Supported',
			variant: 'success'
		},
		{
			name: 'China',
			publisher: 'Hypergryph',
			status: 'Canary',
			variant: 'warning'
		},
		{
			name: 'China — Bilibili',
			publisher: 'Hypergryph',
			status: 'Canary',
			variant: 'warning'
		}
	] as const;

	const guides = $derived(data.navigation);
</script>

<PageMetadata
	title="Arknights Client · macOS launcher"
	description="A native macOS launcher for official regional Arknights PC clients."
	path="/"
/>

<section class="home-hero" aria-labelledby="home-title">
	<div class="hero-copy">
		<SectionLabel>Unofficial macOS launcher</SectionLabel>
		<h1 class="display-title" id="home-title">Arknights on macOS</h1>
		<p class="lead">
			Run official regional Arknights PC clients on Apple Silicon. The
			launcher installs the game, keeps it updated, and collects the logs
			needed when something goes wrong.
		</p>
		<div class="hero-actions">
			<a
				class="download-action anasthasia-primary-action"
				href={releaseUrl}>Download latest ↗</a
			>
			<a class="text-action" href={resolve('/installation/')}
				>Read the installation guide →</a
			>
		</div>
		<ol class="compatibility-route" aria-label="Compatibility route">
			<li>Apple Silicon</li>
			<li>Rosetta 2</li>
			<li>Wine + DXMT</li>
			<li>Official PC client</li>
		</ol>
	</div>

	<table class="region-manifest">
		<caption id="regions-title">Supported regions</caption>
		<thead>
			<tr>
				<th scope="col">Client</th>
				<th scope="col">Manifest</th>
				<th scope="col">Status</th>
			</tr>
		</thead>
		<tbody>
			{#each regions as region (region.name)}
				<tr>
					<th scope="row">{region.name}</th>
					<td>{region.publisher}</td>
					<td
						><Badge variant={region.variant}>{region.status}</Badge
						></td
					>
				</tr>
			{/each}
		</tbody>
	</table>
</section>

<section class="home-section" aria-labelledby="guides-title">
	<div class="home-section-heading">
		<SectionLabel>Documentation</SectionLabel>
		<h2 id="guides-title">Install, troubleshoot, or contribute</h2>
	</div>
	<nav class="guide-list" aria-label="Documentation sections">
		{#each guides as guide (guide.route)}
			<a href={resolve(guide.route)}>
				<span>
					<strong>{guide.title}</strong>
					<small>
						{guide.description}
					</small>
				</span>
				<span aria-hidden="true">→</span>
			</a>
		{/each}
	</nav>
</section>

<section class="home-section" aria-labelledby="capabilities-title">
	<div class="home-section-heading">
		<SectionLabel>Launcher responsibilities</SectionLabel>
		<h2 id="capabilities-title">What it handles</h2>
	</div>
	<div class="capability-list">
		<div>
			<strong>Install and update</strong>
			<p>Keeps each region separate and resumes interrupted downloads</p>
		</div>
		<div>
			<strong>Run the Windows client</strong>
			<p>Uses the project's tested Rosetta 2, Wine, and DXMT runtime</p>
		</div>
		<div>
			<strong>Explain failures</strong>
			<p>Keeps launcher and Wine logs ready for troubleshooting</p>
		</div>
	</div>
</section>

<aside class="project-notice">
	<strong
		>Community project, not affiliated with Yostar, Hypergryph, or Bilibili</strong
	>
	<span>Game files are never bundled</span>
	<a href={`${repositoryUrl}/releases`}>View releases ↗</a>
</aside>
