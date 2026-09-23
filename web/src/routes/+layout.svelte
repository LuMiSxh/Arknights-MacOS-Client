<script lang="ts">
	import { onNavigate } from '$app/navigation';
	import { asset, base, resolve } from '$app/paths';
	import { prefersReducedMotion } from 'svelte/motion';
	import { Kbd } from 'anasthasia/keyboard';
	import '../app.css';
	import type { LayoutProps } from './$types';
	import { normalizeBasePath, repositoryUrl } from '$lib/site.js';
	import ProductMark from '$lib/components/ProductMark.svelte';
	import SiteRail from '$lib/components/SiteRail.svelte';
	import { rise } from '$lib/motion.svelte.js';
	import SiteBackdrop from '$lib/components/SiteBackdrop.svelte';
	import SearchDialog from '$lib/components/SearchDialog.svelte';

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
	let mobileMenuOpen = $state(false);
	let searchOpen = $state(false);
	const isHome = $derived(isExact('/'));
	// Contributor documentation is kept apart from the player-facing guides.
	const railGroups = $derived([
		{
			label: 'Documentation',
			entries: [
				{ title: 'Home', route: '/' as const, children: [] },
				...navigation.filter(
					(entry) => entry.audience !== 'developers'
				),
				{
					title: 'Changelog',
					route: '/changelog/' as const,
					children: []
				}
			]
		},
		{
			label: 'Contributors',
			entries: navigation.filter(
				(entry) => entry.audience === 'developers'
			)
		}
	]);

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

	function closeMobileMenu() {
		mobileMenuOpen = false;
	}

	// Cross-fades between pages; the sidebar keeps its own identity so it stays in place.
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

	function closeMenuOnOutsideClick(event: MouseEvent) {
		if (!mobileMenuOpen || !(event.target instanceof Element)) return;
		if (!event.target.closest('.mobile-header')) closeMobileMenu();
	}
</script>

{#snippet searchIcon()}
	<svg viewBox="0 0 20 20" width="16" height="16" aria-hidden="true">
		<circle
			cx="8.5"
			cy="8.5"
			r="5.5"
			fill="none"
			stroke="currentColor"
			stroke-width="1.8"
		/>
		<path
			d="m13 13 4 4"
			stroke="currentColor"
			stroke-width="1.8"
			stroke-linecap="round"
		/>
	</svg>
{/snippet}

{#snippet searchTrigger(variant: 'rail' | 'compact' | 'round')}
	<button
		class={`search-trigger search-trigger-${variant}`}
		type="button"
		aria-haspopup="dialog"
		aria-expanded={searchOpen}
		aria-keyshortcuts="Control+K Meta+K"
		aria-label={variant === 'rail' ? undefined : 'Search documentation'}
		onclick={() => (searchOpen = true)}
	>
		{@render searchIcon()}
		{#if variant === 'rail'}
			<span>Search docs</span>
			<Kbd>⌘K</Kbd>
		{/if}
	</button>
{/snippet}

{#snippet footer()}
	<footer class="site-footer">
		<span>
			Copyright © 2026 <a href="https://github.com/LuMiSxh">LuMiSxh</a> · Community-maintained,
			not affiliated with Yostar, Gryphline, Hypergryph, or Bilibili
		</span>
		<span class="footer-credit">
			Artwork “Dissociative Recombination” by Krin · © Hypergryph · ©
			Yostar
		</span>
		<span>
			<a href={`${repositoryUrl}/blob/main/LICENSE`}>MPL-2.0</a> ·
			<a href={repositoryUrl}>Source</a> ·
			<a href={`${repositoryUrl}/issues`}>Report an issue</a>
		</span>
	</footer>
{/snippet}

<svelte:window
	onkeydown={(event) => event.key === 'Escape' && closeMobileMenu()}
/>
<svelte:document onclick={closeMenuOnOutsideClick} />

<svelte:head>
	<meta name="color-scheme" content="dark" />
	<meta name="theme-color" content="#0b0c0e" />
	<link rel="icon" href={faviconUrl} sizes="any" />
	<link rel="apple-touch-icon" href={appIconUrl} />
</svelte:head>

<a class="skip-link" href="#main-content">Skip to content</a>

<SearchDialog bind:open={searchOpen} />
<SiteBackdrop blurred={!isHome} />

{#if isHome}
	<div class="home-chrome">
		{@render searchTrigger('round')}
		<a
			class="round-action"
			href={repositoryUrl}
			aria-label="Source on GitHub"
		>
			<svg viewBox="0 0 16 16" width="17" height="17" aria-hidden="true">
				<path
					fill="currentColor"
					d="M8 0a8 8 0 0 0-2.53 15.59c.4.07.55-.17.55-.38v-1.34c-2.23.48-2.7-1.07-2.7-1.07-.36-.92-.89-1.17-.89-1.17-.73-.5.05-.49.05-.49.81.06 1.23.83 1.23.83.72 1.23 1.88.87 2.34.67.07-.52.28-.87.51-1.07-1.78-.2-3.65-.89-3.65-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82a7.6 7.6 0 0 1 4 0c1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.28.82 2.15 0 3.07-1.87 3.75-3.66 3.95.29.25.54.73.54 1.48v2.2c0 .21.15.46.55.38A8 8 0 0 0 8 0Z"
				/>
			</svg>
		</a>
	</div>
	<main id="main-content">
		{@render children()}
		<div class="home-footer home-sheet">{@render footer()}</div>
	</main>
{:else}
	<div class="site-shell">
		<SiteRail
			groups={railGroups}
			iconUrl={appIconUrl}
			{currentPath}
			{isCurrent}
			{currentValue}
		>
			{#snippet search()}{@render searchTrigger('rail')}{/snippet}
		</SiteRail>

		<header class="mobile-header">
			<ProductMark href={resolve('/')} iconUrl={appIconUrl} compact />
			{@render searchTrigger('compact')}
			<div class="mobile-menu-anchor">
				<button
					class="menu-trigger"
					type="button"
					aria-expanded={mobileMenuOpen}
					aria-controls="mobile-menu"
					onclick={() => (mobileMenuOpen = !mobileMenuOpen)}
					>Menu</button
				>
				{#if mobileMenuOpen}
					<div
						class="mobile-menu glass-surface"
						id="mobile-menu"
						transition:rise={{ y: -6, scale: 0.96, duration: 220 }}
					>
						<nav aria-label="Mobile primary">
							{#each railGroups as group (group.label)}
								<p class="mobile-menu-label">{group.label}</p>
								{#each group.entries as entry (entry.route)}
									<a
										href={resolve(entry.route)}
										onclick={closeMobileMenu}
										aria-current={currentValue(entry.route)}
										>{entry.title}</a
									>
								{/each}
							{/each}
						</nav>
					</div>
				{/if}
			</div>
		</header>

		<main class="site-main" id="main-content">
			<div class="site-main-inner">
				{@render children()}
				{@render footer()}
			</div>
		</main>
	</div>
{/if}
