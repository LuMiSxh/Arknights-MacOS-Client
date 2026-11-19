<script lang="ts">
	import { resolve } from '$app/paths';
	import { Kbd } from 'anasthasia/keyboard';
	import { releaseUrl, repositoryUrl } from '$lib/site.js';
	import ProductMark from './ProductMark.svelte';

	type Props = {
		iconUrl: string;
		currentValue: (route: string) => 'page' | 'location' | undefined;
		onSearch: () => void;
	};

	let { iconUrl, currentValue, onSearch }: Props = $props();

	const sections = [
		{ title: 'Installation', route: '/installation/' },
		{ title: 'Help', route: '/help/' },
		{ title: 'Performance', route: '/performance/' },
		{ title: 'Changelog', route: '/changelog/' },
		{ title: 'Blog', route: '/blog/' }
	] as const;

	// On narrow screens the menu holds the sections, search, and GitHub.
	let menuOpen = $state(false);
	let menuAnchor = $state<HTMLElement>();
	let menuPanel = $state<HTMLElement>();
	let menuTrigger = $state<HTMLButtonElement>();

	function closeMenu() {
		menuOpen = false;
	}

	function closeMenuOnEscape(event: KeyboardEvent) {
		if (
			event.key !== 'Escape' ||
			!menuOpen ||
			document.querySelector('dialog[open], [aria-modal="true"]')
		)
			return;
		closeMenu();
		menuTrigger?.focus();
	}

	function closeMenuOnResize() {
		if (window.innerWidth > 760) closeMenu();
	}

	function closeMenuOnOutsideClick(event: MouseEvent) {
		if (!menuOpen || !(event.target instanceof Node)) return;
		if (
			!menuAnchor?.contains(event.target) &&
			!menuPanel?.contains(event.target)
		)
			closeMenu();
	}

	function openSearch() {
		closeMenu();
		onSearch();
	}
</script>

<svelte:window onkeydown={closeMenuOnEscape} onresize={closeMenuOnResize} />
<svelte:document onclick={closeMenuOnOutsideClick} />

{#snippet sectionLinks()}
	{#each sections as section (section.route)}
		<a
			class="section-link"
			href={resolve(section.route)}
			aria-current={currentValue(section.route)}
			onclick={closeMenu}>{section.title}</a
		>
	{/each}
{/snippet}

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

{#snippet githubIcon()}
	<svg viewBox="0 0 16 16" width="17" height="17" aria-hidden="true">
		<path
			fill="currentColor"
			d="M8 0a8 8 0 0 0-2.53 15.59c.4.07.55-.17.55-.38v-1.34c-2.23.48-2.7-1.07-2.7-1.07-.36-.92-.89-1.17-.89-1.17-.73-.5.05-.49.05-.49.81.06 1.23.83 1.23.83.72 1.23 1.88.87 2.34.67.07-.52.28-.87.51-1.07-1.78-.2-3.65-.89-3.65-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82a7.6 7.6 0 0 1 4 0c1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.28.82 2.15 0 3.07-1.87 3.75-3.66 3.95.29.25.54.73.54 1.48v2.2c0 .21.15.46.55.38A8 8 0 0 0 8 0Z"
		/>
	</svg>
{/snippet}

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

<header class="top-bar glass-surface">
	<ProductMark href={resolve('/')} {iconUrl} compact />
	<nav class="top-nav" aria-label="Primary">
		<div class="top-links">{@render sectionLinks()}</div>
		<div class="top-tools">
			<button
				class="top-search"
				type="button"
				aria-haspopup="dialog"
				aria-keyshortcuts="Control+K Meta+K"
				onclick={onSearch}
			>
				{@render searchIcon()}
				<span>Search</span>
				<Kbd>⌘K</Kbd>
			</button>
			<a
				class="top-icon"
				href={repositoryUrl}
				aria-label="Source on GitHub">{@render githubIcon()}</a
			>
		</div>
		<a class="download-link" href={releaseUrl}>
			Download
			{@render externalIcon()}
			<span class="sr-only"> (opens GitHub Releases)</span>
		</a>
		<div class="menu-anchor" bind:this={menuAnchor}>
			<button
				class="menu-trigger"
				type="button"
				bind:this={menuTrigger}
				aria-expanded={menuOpen}
				aria-controls="site-menu"
				onclick={() => (menuOpen = !menuOpen)}>Menu</button
			>
		</div>
	</nav>
</header>

{#if menuOpen}
	<!-- Outside the header: its backdrop-filter must sample the page, not the bar's own glass. -->
	<div
		class="menu-panel glass-surface glass-float"
		id="site-menu"
		bind:this={menuPanel}
	>
		{@render sectionLinks()}
		<button type="button" aria-haspopup="dialog" onclick={openSearch}>
			{@render searchIcon()}
			<span>Search</span>
			<Kbd>⌘K</Kbd>
		</button>
		<a href={repositoryUrl}>
			{@render githubIcon()}
			<span>Source on GitHub</span>
		</a>
	</div>
{/if}

<style>
	.top-bar {
		position: sticky;
		top: 0;
		z-index: 20;
		display: flex;
		height: var(--top-bar-height);
		align-items: center;
		gap: var(--site-space-4);
		--glass-tint: rgb(19 20 23 / 0.8);
		border: 0;
		border-bottom: 1px solid var(--site-hairline);
		padding-inline: var(--site-gutter);
	}

	.top-nav {
		display: flex;
		min-width: 0;
		flex: 1;
		align-items: center;
		justify-content: flex-end;
		gap: var(--site-space-3);
	}

	.top-links,
	.top-tools {
		display: flex;
		align-items: center;
	}

	.top-links {
		gap: var(--site-space-2);
		margin-inline-end: var(--site-space-2);
	}

	.top-tools {
		gap: var(--site-space-3);
	}

	.section-link {
		position: relative;
		display: inline-flex;
		min-height: var(--site-touch-target);
		align-items: center;
		padding: 0 var(--site-space-3);
		color: var(--site-text-secondary);
		font-size: 0.9rem;
		text-decoration: none;
	}

	.section-link:hover {
		color: var(--site-text-primary);
	}

	.section-link[aria-current] {
		color: var(--site-accent-ink);
	}

	/* The accent tick marks the current section; the weight stays the same. */
	.section-link[aria-current]::after {
		position: absolute;
		right: 0;
		bottom: 0.1rem;
		left: 0;
		height: 2px;
		border-radius: var(--site-radius-capsule);
		background: var(--site-accent-fill);
		content: '';
	}

	.top-search,
	.top-icon {
		display: inline-flex;
		min-height: var(--site-touch-target);
		align-items: center;
		gap: var(--site-space-2);
		border: 1px solid var(--site-hairline);
		border-radius: var(--site-radius-capsule);
		background: var(--site-group-fill);
		color: var(--site-text-secondary);
		font: inherit;
		font-size: 0.85rem;
		cursor: pointer;
	}

	.top-search {
		padding: 0 var(--site-space-3);
	}

	.top-icon {
		justify-content: center;
		min-width: var(--site-touch-target);
		text-decoration: none;
	}

	.top-search:hover,
	.top-icon:hover {
		color: var(--site-text-primary);
	}

	.download-link {
		display: inline-flex;
		min-height: var(--site-touch-target);
		align-items: center;
		gap: var(--site-space-2);
		border: 1px solid var(--site-accent-glass-stroke);
		border-radius: var(--site-radius-capsule);
		background: var(--site-accent-glass-tint);
		padding: 0 var(--site-space-4);
		color: var(--site-accent-ink);
		font-size: 0.9rem;
		text-decoration: none;
	}

	.download-link:hover {
		border-color: var(--site-accent-ink);
	}

	.menu-trigger {
		display: none;
		min-height: var(--site-touch-target);
		align-items: center;
		border: 1px solid var(--site-hairline);
		border-radius: var(--site-radius-capsule);
		background: var(--site-group-fill);
		padding: 0 var(--site-space-4);
		color: var(--site-text-primary);
		font: inherit;
		font-size: 0.85rem;
		cursor: pointer;
	}

	/* Near-opaque so hero content behind the panel cannot read through its edge. */
	.menu-panel {
		--glass-tint: rgb(19 20 23 / 0.94);
		position: fixed;
		top: calc(var(--top-bar-height) + var(--site-space-2));
		right: var(--site-gutter);
		z-index: 21;
		display: grid;
		width: min(17rem, calc(100vw - 2rem));
		gap: 0.15rem;
		border-radius: var(--site-radius-panel);
		padding: var(--site-space-2);
		transform-origin: top right;
		animation: present-in var(--site-dur-present) var(--site-ease-state)
			both;
	}

	.menu-panel > * {
		display: flex;
		align-items: center;
		gap: var(--site-space-2);
		width: 100%;
		min-height: var(--site-touch-target);
		border: 0;
		border-radius: var(--site-radius-control);
		background: none;
		padding: 0 var(--site-space-3);
		color: var(--site-text-secondary);
		font: inherit;
		font-size: 0.9rem;
		text-align: left;
		text-decoration: none;
		cursor: pointer;
	}

	.menu-panel > *:hover {
		background: var(--site-group-fill);
		color: var(--site-text-primary);
	}

	.menu-panel > [aria-current] {
		background: var(--site-accent-glass-tint);
		color: var(--site-accent-ink);
	}

	.menu-panel > [aria-current]::after {
		display: none;
	}

	@media (max-width: 760px) {
		.top-links,
		.top-tools {
			display: none;
		}

		.menu-trigger {
			display: inline-flex;
		}
	}

	@media (prefers-reduced-motion: reduce) {
		.menu-panel {
			animation: site-fade-in var(--site-dur-reduced) linear both;
		}
	}
</style>
