<script lang="ts">
	import { asset } from '$app/paths';

	type Props = {
		/** Documentation pages draw the artwork's tones as CSS gradients and load no image. */
		blurred?: boolean;
	};

	let { blurred = false }: Props = $props();

	// Official Arknights Global wallpaper; the repository's only bundled artwork (see CLAUDE.md).
	const widths = [960, 1600, 2400];
	const file = (width: number, format: string) =>
		asset(`/artwork/dissociative-recombination-${width}.${format}`);
	const srcset = (format: string) =>
		widths.map((width) => `${file(width, format)} ${width}w`).join(', ');
	// The sharp copy always spans the full window width and is never cropped at the sides.
	const sizes = '100vw';
</script>

<div class="site-backdrop" class:blurred aria-hidden="true">
	{#if !blurred}
		<img class="backdrop-fill" src={file(960, 'webp')} alt="" />
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

	/* Starts below the top bar so the artwork's own logo stays in view. */
	.backdrop-art {
		position: absolute;
		top: var(--top-bar-height);
		left: 0;
		width: 100%;
		height: auto;
		mask-image: linear-gradient(
			to bottom,
			#000 calc(100% - 4rem),
			transparent
		);
	}

	/* Parallax runs as a scroll-linked animation where supported. Elsewhere the artwork stays still. */
	@supports (animation-timeline: scroll()) {
		@media (prefers-reduced-motion: no-preference) {
			.backdrop-art {
				animation: backdrop-drift linear both;
				animation-timeline: scroll();
			}
		}
	}

	@keyframes backdrop-drift {
		to {
			translate: 0 -20vh;
		}
	}

	/* Docs pages skip the image: accent and chart tones over the page background. */
	.blurred {
		background:
			radial-gradient(
				60% 50% at 18% 12%,
				color-mix(in srgb, var(--site-accent-fill) 20%, transparent),
				transparent 70%
			),
			radial-gradient(
				55% 60% at 88% 88%,
				color-mix(in srgb, var(--site-chart-3) 14%, transparent),
				transparent 72%
			),
			var(--site-bg);
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
