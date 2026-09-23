<script lang="ts">
	import ReleaseHud from './ReleaseHud.svelte';

	type Props = {
		title: string;
		detail: string;
		iconUrl: string;
		installationHref: string;
		releaseHref: string;
	};

	let { title, detail, iconUrl, installationHref, releaseHref }: Props =
		$props();
</script>

<section class="artwork-stage" aria-labelledby="stage-title">
	<div class="stage-bottom">
		<p class="stage-pill glass-surface">Apple Silicon · macOS 15+</p>
		<ReleaseHud
			{title}
			{detail}
			{iconUrl}
			secondary={{
				label: 'Installation guide',
				href: installationHref
			}}
			primary={{ label: 'Download ↗', href: releaseHref }}
		/>
	</div>
</section>

<style>
	/* The artwork itself is the fixed site backdrop; the stage reserves its visible area. */
	.artwork-stage {
		display: flex;
		height: min(56.25vw, 100vh);
		min-height: 22rem;
		flex-direction: column;
		justify-content: flex-end;
		padding: var(--site-space-6) var(--site-gutter);
	}

	.stage-bottom {
		display: grid;
		justify-items: end;
		gap: var(--site-space-2);
	}

	.stage-pill {
		animation: pill-in 600ms cubic-bezier(0.2, 0.7, 0.2, 1) 450ms both;
		margin: 0;
		border: 1px solid var(--site-border);
		border-radius: var(--site-radius-capsule);
		padding: 0.4rem 0.85rem;
		color: var(--site-muted);
		font-family: var(--site-font-mono);
		font-size: 0.72rem;
	}

	@keyframes pill-in {
		from {
			opacity: 0;
			transform: translateY(8px);
		}
	}

	@media (prefers-reduced-motion: reduce) {
		.stage-pill {
			animation: none;
		}
	}

	/* On narrow screens the HUD would cover most of the artwork, so it follows below it. */
	@media (max-width: 760px) {
		.artwork-stage {
			height: auto;
			min-height: 0;
			padding-top: calc(56.25vw + var(--site-space-3));
		}
	}
</style>
