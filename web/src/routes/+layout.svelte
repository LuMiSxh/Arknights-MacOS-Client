<script lang="ts">
	import { onNavigate } from '$app/navigation';
	import { asset, base, resolve } from '$app/paths';
	import { page } from '$app/state';
	import { prefersReducedMotion } from 'svelte/motion';
	import '../app.css';
	import type { LayoutProps } from './$types';
	import { normalizeBasePath, repositoryUrl } from '$lib/site.js';
	import SearchDialog from '$lib/components/SearchDialog.svelte';
	import SiteBackdrop from '$lib/components/SiteBackdrop.svelte';
	import SiteRail from '$lib/components/SiteRail.svelte';
	import SiteTopBar from '$lib/components/SiteTopBar.svelte';

	let { data, children }: LayoutProps = $props();

	const navigation = $derived(data.navigation);
	const currentPath = $derived(data.pathname);
	const appIconUrl = asset('/AppIcon-128.png');
	const faviconUrl = asset('/favicon.ico');
	const configuredBasePath = normalizeBasePath(
		typeof process !== 'undefined' && process.env.BASE_PATH
			? process.env.BASE_PATH
			: base
	);
	let searchOpen = $state(false);
	const isHome = $derived(isExact('/'));
	// The rail lists only the documentation tree. Every other page, including the 404 page, stays full width.
	const railRoutes: readonly string[] = [
		'/installation/',
		'/help/',
		'/performance/'
	];
	const showRail = $derived(
		!page.error && railRoutes.some((route) => isCurrent(route))
	);
	const railEntries = $derived(
		navigation.filter((entry) => railRoutes.includes(entry.route))
	);

	function isCurrent(route: string): boolean {
		const current = normalizePath(currentPath);
		const target = routePath(route);
		return route === '/'
			? current === target
			: current === target || current.startsWith(`${target}/`);
	}

	function isExact(route: string): boolean {
		return normalizePath(currentPath) === routePath(route);
	}

	function currentValue(route: string): 'page' | 'location' | undefined {
		if (isExact(route)) return 'page';
		return isCurrent(route) ? 'location' : undefined;
	}

	function normalizePath(path: string): string {
		const trimmed = path
			.replace(/\/index\.html$/i, '')
			.replace(/^\/+|\/+$/g, '');
		return trimmed ? `/${trimmed}` : '/';
	}

	function routePath(route: string): string {
		return normalizePath(`${configuredBasePath}${route}`);
	}

	// Cross-fades between pages; the rail keeps its own identity so it stays in place.
	onNavigate((navigation) => {
		if (
			!document.startViewTransition ||
			prefersReducedMotion.current ||
			navigation.from?.url.pathname === navigation.to?.url.pathname
		)
			return;
		return new Promise((resolve) => {
			document.startViewTransition(async () => {
				resolve();
				await navigation.complete;
			});
		});
	});
</script>

{#snippet footer()}
	<footer
		class="site-footer"
		class:home-footer={isHome}
		class:with-rail={showRail}
	>
		<div class="footer-inner">
			<div class="footer-about">
				<p>
					Copyright © 2026 <a href="https://github.com/LuMiSxh"
						>LuMiSxh</a
					> · Community-maintained, not affiliated with Yostar, Gryphline,
					Hypergryph, or Bilibili
				</p>
				<p class="footer-credit">
					Artwork “Dissociative Recombination” by Krin · © Hypergryph
					· © Yostar
				</p>
			</div>
			<nav class="footer-links" aria-label="Footer">
				<a href={resolve('/legal/')}>Legal</a>
				<a href={resolve('/privacy/')}>Privacy notice</a>
				<a href={resolve('/contact/')}>Contact</a>
				<a href={resolve('/ai-assistance/')}>AI assistance</a>
			</nav>
			<div class="footer-group">
				<p class="footer-label">Contributors</p>
				<a href={resolve('/development/')}>Development</a>
			</div>
			<p class="footer-links">
				<a href={`${repositoryUrl}/blob/main/LICENSE`}>MPL-2.0</a>
				<a href={`${repositoryUrl}/issues`}>Report an issue</a>
				<a href={repositoryUrl}>Source</a>
			</p>
		</div>
	</footer>
{/snippet}

<svelte:head>
	<meta name="color-scheme" content="dark" />
	<meta name="theme-color" content="#0b0c0e" />
	<link rel="icon" href={faviconUrl} sizes="any" />
	<link rel="apple-touch-icon" href={appIconUrl} />
</svelte:head>

<a class="skip-link" href="#main-content">Skip to content</a>

<SearchDialog bind:open={searchOpen} />
<SiteBackdrop blurred={!isHome} />
<SiteTopBar
	iconUrl={appIconUrl}
	{currentValue}
	onSearch={() => (searchOpen = true)}
/>

<div class="site-shell" class:no-rail={!showRail}>
	{#if showRail}
		<SiteRail
			entries={railEntries}
			{currentPath}
			{isCurrent}
			{currentValue}
		/>
	{/if}
	<main id="main-content" class:site-main={!isHome}>
		<div class="site-content">{@render children()}</div>
	</main>
</div>

{@render footer()}
