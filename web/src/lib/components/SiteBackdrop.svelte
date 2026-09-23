<script lang="ts">
	import { asset } from '$app/paths';
	import { prefersReducedMotion } from 'svelte/motion';

	type Props = {
		/** Documentation pages keep only the blurred artwork, behind the sidebar. */
		blurred?: boolean;
	};

	let { blurred = false }: Props = $props();
	let scrollY = $state(0);
	// Slow parallax: the artwork drifts up at a fraction of the scroll speed.
	const drift = $derived(prefersReducedMotion.current ? 0 : scrollY * -0.12);

	// Official Arknights Global wallpaper; the repository's only bundled artwork (see CLAUDE.md).
	const widths = [960, 1600, 2400];
	const file = (width: number, format: string) =>
		asset(`/artwork/dissociative-recombination-${width}.${format}`);
	const srcset = (format: string) =>
		widths.map((width) => `${file(width, format)} ${width}w`).join(', ');
	// The sharp copy always spans the full window width and is never cropped at the sides.
	const sizes = '100vw';
</script>

<svelte:window bind:scrollY />

<div class="site-backdrop" class:blurred aria-hidden="true">
	<img class="backdrop-fill" src={file(960, 'webp')} alt="" />
	{#if !blurred}
		<picture>
			<source type="image/avif" srcset={srcset('avif')} {sizes} />
			<source type="image/webp" srcset={srcset('webp')} {sizes} />
			<img
				class="backdrop-art"
				src={file(1600, 'webp')}
				alt=""
				width="1600"
				height="900"
				fetchpriority="high"
				style:translate={`0 ${drift}px`}
			/>
		</picture>
	{/if}
</div>

<style>
	.site-backdrop {
		position: fixed;
		inset: 0;
		z-index: -1;
		overflow: hidden;
		background: var(--site-bg);
		pointer-events: none;
	}

	/* Blurred copy fills whatever the uncropped artwork leaves uncovered. */
	.backdrop-fill {
		position: absolute;
		inset: -5%;
		width: 110%;
		height: 110%;
		object-fit: cover;
		filter: blur(48px) brightness(0.45) saturate(1.2);
	}

	.backdrop-art {
		position: absolute;
		top: 0;
		left: 0;
		width: 100%;
		height: auto;
	}

	/* Fades the sharp artwork's lower edge into the blurred fill. */
	.site-backdrop::after {
		position: absolute;
		inset: 0;
		background:
			linear-gradient(
				180deg,
				transparent calc(min(56.25vw, 100vh) - 30vh),
				rgb(11 12 14 / 0.55) min(56.25vw, 100vh)
			),
			linear-gradient(200deg, rgb(0 0 0 / 0.35), transparent 25%);
		content: '';
	}

	.blurred .backdrop-fill {
		filter: blur(56px) brightness(0.35) saturate(1.2);
	}

	.blurred::after {
		background: none;
	}

	@media (prefers-reduced-transparency: reduce) {
		.backdrop-fill {
			display: none;
		}
	}

	@media (forced-colors: active) {
		.site-backdrop {
			display: none;
		}
	}
</style>
