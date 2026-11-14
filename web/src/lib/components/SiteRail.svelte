<script lang="ts">
	import { resolve } from '$app/paths';
	import { slide } from 'svelte/transition';
	import { prefersReducedMotion } from 'svelte/motion';
	import { tick } from 'svelte';
	import type { SiteRoute } from '$lib/content/types.js';
	import { SlideIndicator, structureDuration } from '$lib/motion.svelte.js';
	import NavIcon from './NavIcon.svelte';

	type Entry = {
		title: string;
		route: SiteRoute;
		children: readonly { title: string; route: SiteRoute }[];
	};
	type Props = {
		entries: readonly Entry[];
		currentPath: string;
		isCurrent: (route: string) => boolean;
		currentValue: (route: string) => 'page' | 'location' | undefined;
	};

	let { entries, currentPath, isCurrent, currentValue }: Props = $props();

	const indicator = new SlideIndicator();

	// Re-measures whenever the route changes, so the highlight glides to the new section.
	function trackSelection(node: HTMLElement) {
		void currentPath;
		void tick().then(() =>
			indicator.move(node.querySelector<HTMLElement>('[data-active]'))
		);
	}
</script>

<svelte:window
	onresize={() =>
		indicator.move(
			document.querySelector<HTMLElement>('.site-nav [data-active]')
		)}
/>

<aside class="site-rail" aria-label="Documentation">
	<div class="rail-navigation">
		<nav
			class="site-nav"
			aria-label="Documentation sections"
			{@attach trackSelection}
		>
			<span
				class="nav-indicator"
				class:visible={indicator.visible}
				style:transform={`translateY(${indicator.top}px)`}
				style:height={`${indicator.height}px`}
				aria-hidden="true"
			></span>
			{#each entries as entry (entry.route)}
				{@const active = isCurrent(entry.route)}
				<a
					class="nav-item"
					href={resolve(entry.route)}
					data-active={active ? 'true' : undefined}
					aria-current={currentValue(entry.route)}
				>
					<NavIcon route={entry.route} />
					<span>{entry.title}</span>
				</a>
				{#if active && entry.children.length}
					<div
						class="nav-children"
						in:slide={{
							duration: prefersReducedMotion.current
								? 0
								: structureDuration
						}}
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
				{/if}
			{/each}
		</nav>
	</div>
</aside>

<style>
	.site-rail {
		position: sticky;
		view-transition-name: site-rail;
		top: var(--top-bar-height);
		display: flex;
		height: calc(100dvh - var(--top-bar-height));
		flex-direction: column;
		gap: var(--site-space-5);
		border-right: 1px solid var(--site-hairline);
		/* Glass over the blurred artwork, like the launcher's Settings sidebar. */
		background: rgb(0 0 0 / 0.35);
		padding: var(--site-space-6) var(--site-space-3);
	}

	.rail-navigation {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
		overscroll-behavior: contain;
	}

	.site-nav {
		position: relative;
		display: grid;
		gap: 0.2rem;
	}

	.nav-indicator {
		position: absolute;
		top: 0;
		right: 0;
		left: 0;
		border-radius: var(--site-radius-rail-row);
		background: var(--site-accent-glass-tint);
		opacity: 0;
		pointer-events: none;
	}

	.nav-indicator.visible {
		opacity: 1;
	}

	.nav-indicator::before {
		position: absolute;
		top: 0.7rem;
		bottom: 0.7rem;
		left: 0;
		width: 3px;
		border-radius: var(--site-radius-capsule);
		background: var(--site-accent-fill);
		content: '';
	}

	.nav-item {
		position: relative;
		display: flex;
		min-height: var(--site-touch-target);
		align-items: center;
		gap: var(--site-space-3);
		border-radius: var(--site-radius-rail-row);
		padding: 0 var(--site-space-3);
		color: var(--site-text-secondary);
		font-size: 0.95rem;
		font-weight: 500;
		text-decoration: none;
		transition:
			background-color var(--site-dur-state) var(--site-ease-state),
			color var(--site-dur-state) var(--site-ease-state);
	}

	.nav-item:hover:not([data-active]) {
		background: var(--site-group-fill);
		color: var(--site-text-primary);
	}

	.nav-item[data-active] {
		color: var(--site-accent-ink);
	}

	.nav-children {
		display: grid;
		gap: 0.1rem;
		margin: 0.1rem 0 var(--site-space-2) 1.3rem;
		border-left: 1px solid var(--site-hairline);
		padding-left: var(--site-space-2);
	}

	.nav-children a {
		position: relative;
		display: flex;
		min-height: var(--site-touch-target);
		align-items: center;
		border-radius: var(--site-radius-rail-row);
		padding: 0.3rem var(--site-space-3);
		color: var(--site-text-secondary);
		font-size: 0.86rem;
		text-decoration: none;
		transition: color var(--site-dur-state) var(--site-ease-state);
	}

	.nav-children a:hover {
		color: var(--site-text-primary);
	}

	.nav-children a[aria-current='page'] {
		color: var(--site-text-primary);
	}

	.nav-children a[aria-current='page']::before {
		position: absolute;
		top: 0.75rem;
		bottom: 0.75rem;
		left: calc(-1 * var(--site-space-2) - 1px);
		width: 2px;
		border-radius: var(--site-radius-capsule);
		background: var(--site-accent-fill);
		content: '';
	}

	@media (max-width: 760px) {
		.site-rail {
			display: none;
		}
	}

	@media (forced-colors: active) {
		.nav-indicator {
			border: 1px solid Highlight;
		}
	}
</style>
