<script lang="ts">
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import { onMount } from 'svelte';
	import { SegmentedControl, theme, type ThemeMode } from 'anasthasia';
	import '../app.css';
	import type { LayoutProps } from './$types';
	import { repositoryUrl } from '$lib/site.js';
	import appIconUrl from '../../../Resources/AppIcon.png?url';

	let { data, children }: LayoutProps = $props();

	const navigation = $derived(data.navigation);
	let themeMode = $state<ThemeMode>('system');
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
		const current = page.url.pathname;
		const routePath = current.endsWith('/') ? current : `${current}/`;
		return route === '/'
			? routePath === resolve('/')
			: routePath.startsWith(resolve(route as `/${string}`));
	}

	function isExact(route: string): boolean {
		const current = page.url.pathname.replace(/\/$/, '');
		return current === resolve(route as `/${string}`).replace(/\/$/, '');
	}
</script>

<svelte:head>
	<meta
		name="description"
		content="Run the official Global, Japan, and Korea Arknights PC clients on Apple Silicon Macs."
	/>
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
	<link rel="icon" type="image/png" sizes="512x512" href={appIconUrl} />
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

		<div>
			<p class="site-rail-label">Navigation</p>
			<nav class="site-nav" aria-label="Primary">
				<a
					href={resolve('/')}
					aria-current={isCurrent('/') ? 'page' : undefined}>Home</a
				>
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
									href={resolve(entry.route as `/${string}`)}
									aria-current={isExact(entry.route)
										? 'page'
										: undefined}>Overview</a
								>
								{#each entry.children as child (child.route)}
									<a
										href={resolve(
											child.route as `/${string}`
										)}
										aria-current={isExact(child.route)
											? 'page'
											: undefined}>{child.title}</a
									>
								{/each}
							</div>
						</details>
					{:else}
						<a
							href={resolve(entry.route as `/${string}`)}
							aria-current={isCurrent(entry.route)
								? 'page'
								: undefined}
						>
							<span>{entry.title}</span>
						</a>
					{/if}
				{/each}
				<a
					href={resolve('/changelog/')}
					aria-current={isCurrent('/changelog/') ? 'page' : undefined}
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
		<details>
			<summary>Menu</summary>
			<div class="mobile-menu">
				<nav aria-label="Mobile primary">
					<a
						href={resolve('/')}
						aria-current={isCurrent('/') ? 'page' : undefined}
						>Home</a
					>
					{#each navigation as entry (entry.route)}
						<a
							href={resolve(entry.route as `/${string}`)}
							aria-current={isCurrent(entry.route)
								? 'page'
								: undefined}
						>
							{entry.title}
						</a>
					{/each}
					<a
						href={resolve('/changelog/')}
						aria-current={isCurrent('/changelog/')
							? 'page'
							: undefined}
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
					· unofficial Yostar client companion
				</span>
				<span
					><a href={`${repositoryUrl}/blob/main/LICENSE`}>MPL-2.0</a>
					· <a href={repositoryUrl}>Source</a></span
				>
			</footer>
		</div>
	</main>
</div>
