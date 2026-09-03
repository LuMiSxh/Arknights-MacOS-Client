<script lang="ts">
	import { asset, base, resolve } from '$app/paths';
	import { onMount } from 'svelte';
	import { SegmentedControl, theme, type ThemeMode } from 'anasthasia';
	import '../app.css';
	import type { LayoutProps } from './$types';
	import { normalizeBasePath, repositoryUrl } from '$lib/site.js';

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
	let themeMode = $state<ThemeMode>('system');
	let mobileMenuOpen = $state(false);
	const themeOptions = [
		{ value: 'light' as const, label: 'Light' },
		{ value: 'system' as const, label: 'Auto' },
		{ value: 'dark' as const, label: 'Dark' }
	];

	onMount(() => {
		theme.init('system');
		themeMode = theme.mode;
		return () => theme.destroy();
	});

	function setTheme(mode: ThemeMode) {
		themeMode = mode;
		theme.setMode(mode);
	}

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
</script>

<svelte:head>
	<meta name="color-scheme" content="light dark" />
	<meta
		name="theme-color"
		media="(prefers-color-scheme: light)"
		content="#f2f3f5"
	/>
	<meta
		name="theme-color"
		media="(prefers-color-scheme: dark)"
		content="#090b0d"
	/>
	<link rel="icon" href={faviconUrl} sizes="any" />
	<link rel="apple-touch-icon" href={appIconUrl} />
</svelte:head>

<a class="skip-link" href="#main-content">Skip to content</a>

<div class="site-shell">
	<aside class="site-rail" aria-label="Site navigation">
		<a
			class="site-mark"
			href={resolve('/')}
			aria-label="Arknights Client home"
		>
			<img class="site-mark-icon" src={appIconUrl} alt="" />
			<span>Arknights<br />Client</span>
		</a>
		<div class="rail-theme">
			<SegmentedControl
				ariaLabel="Color scheme"
				options={themeOptions}
				value={themeMode}
				onchange={setTheme}
			/>
		</div>

		<div class="rail-navigation">
			<p class="site-rail-label">Navigation</p>
			<nav class="site-nav" aria-label="Primary">
				<a href={resolve('/')} aria-current={currentValue('/')}>Home</a>
				{#each navigation as entry (entry.route)}
					{#if entry.children.length}
						<details
							class="site-nav-group"
							open={isCurrent(entry.route)}
						>
							<summary
								data-current={isCurrent(entry.route)
									? 'true'
									: undefined}>{entry.title}</summary
							>
							<div class="site-nav-children">
								<a
									href={resolve(entry.route)}
									aria-current={currentValue(entry.route)}
									>Overview</a
								>
								{#each entry.children as child (child.route)}
									<a
										href={resolve(child.route)}
										data-current={isCurrent(child.route)
											? 'true'
											: undefined}
										aria-current={currentValue(child.route)}
										>{child.title}</a
									>
								{/each}
							</div>
						</details>
					{:else}
						<a
							href={resolve(entry.route)}
							aria-current={currentValue(entry.route)}
						>
							<span>{entry.title}</span>
						</a>
					{/if}
				{/each}
				<a
					href={resolve('/changelog/')}
					aria-current={currentValue('/changelog/')}
				>
					Changelog
				</a>
			</nav>
		</div>

		<div class="site-rail-footer">
			<a class="site-rail-label" href={`${repositoryUrl}/issues`}
				>Report an issue ↗</a
			>
		</div>
	</aside>

	<header class="mobile-header">
		<a
			class="site-mark"
			href={resolve('/')}
			aria-label="Arknights Client home"
		>
			<img class="site-mark-icon" src={appIconUrl} alt="" />
			<span>Arknights Client</span>
		</a>
		<details bind:open={mobileMenuOpen}>
			<summary>Menu</summary>
			<div class="mobile-menu">
				<nav aria-label="Mobile primary">
					<a
						href={resolve('/')}
						onclick={closeMobileMenu}
						aria-current={currentValue('/')}>Home</a
					>
					{#each navigation as entry (entry.route)}
						<a
							href={resolve(entry.route)}
							onclick={closeMobileMenu}
							aria-current={currentValue(entry.route)}
						>
							{entry.title}
						</a>
					{/each}
					<a
						href={resolve('/changelog/')}
						onclick={closeMobileMenu}
						aria-current={currentValue('/changelog/')}
					>
						Changelog
					</a>
				</nav>
				<div class="mobile-theme">
					<SegmentedControl
						ariaLabel="Color scheme"
						options={themeOptions}
						value={themeMode}
						onchange={setTheme}
					/>
				</div>
			</div>
		</details>
	</header>

	<main class="site-main" id="main-content">
		<div class="site-main-inner">
			{@render children()}
			<footer class="site-footer">
				<span>
					Copyright © 2026
					<a href="https://github.com/LuMiSxh">LuMiSxh</a> · Community-maintained
					· unofficial Yostar/Hypergryph client companion
				</span>
				<span
					><a href={`${repositoryUrl}/blob/main/LICENSE`}>MPL-2.0</a>
					· <a href={repositoryUrl}>Source</a></span
				>
			</footer>
		</div>
	</main>
</div>
