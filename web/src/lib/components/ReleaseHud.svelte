<script lang="ts">
	type Action = { label: string; href: string };
	type Props = {
		title: string;
		detail: string;
		iconUrl: string;
		secondary: Action;
		primary: Action;
	};

	let { title, detail, iconUrl, secondary, primary }: Props = $props();
</script>

<div class="release-hud glass-surface">
	<img src={iconUrl} alt="" width="36" height="36" />
	<div class="hud-copy">
		<h1 id="stage-title">{title}</h1>
		<p>{detail}</p>
	</div>
	<div class="hud-actions">
		<a class="hud-action quiet" href={secondary.href}>{secondary.label}</a>
		<a class="hud-action tinted" href={primary.href}>
			{primary.label}<span class="sr-only"> (opens GitHub Releases)</span>
		</a>
	</div>
</div>

<style>
	.release-hud {
		display: flex;
		width: 100%;
		box-sizing: border-box;
		align-items: center;
		gap: var(--site-space-4);
		border: 1px solid var(--site-border);
		border-radius: var(--site-radius-capsule);
		padding: var(--site-space-3) var(--site-space-3) var(--site-space-3)
			var(--site-space-5);
		box-shadow: 0 18px 40px rgb(0 0 0 / 0.35);
		animation: hud-rise 700ms cubic-bezier(0.2, 0.7, 0.2, 1) 150ms both;
	}

	/* Plays on first paint too, since the HUD is server-rendered. */
	@keyframes hud-rise {
		from {
			opacity: 0;
			transform: translateY(24px) scale(0.98);
		}
	}

	img {
		flex: none;
		width: 2.25rem;
		height: 2.25rem;
		border-radius: 9px;
	}

	.hud-copy {
		flex: 1;
		min-width: 0;
	}

	h1 {
		margin: 0;
		font-size: 1rem;
		font-weight: 700;
		letter-spacing: -0.01em;
	}

	p {
		margin: 0.1rem 0 0;
		color: var(--site-muted);
		font-size: 0.8rem;
	}

	.hud-actions {
		display: flex;
		flex-wrap: wrap;
		justify-content: flex-end;
		gap: var(--site-space-2);
	}

	.hud-action {
		display: inline-flex;
		min-height: var(--site-touch-target);
		align-items: center;
		justify-content: center;
		border: 1px solid var(--site-border);
		border-radius: var(--site-radius-capsule);
		padding: 0 var(--site-space-5);
		font-size: 0.9rem;
		font-weight: 650;
		text-decoration: none;
		transition:
			background-color var(--site-motion-fast) ease,
			border-color var(--site-motion-fast) ease;
	}

	.quiet {
		background: var(--site-hover);
		color: var(--site-text);
	}

	.quiet:hover {
		background: rgb(255 255 255 / 0.1);
	}

	.tinted {
		border-color: var(--site-signal-border);
		background: var(--site-signal-fill);
		color: var(--site-signal-text);
	}

	.tinted:hover {
		background: color-mix(in srgb, var(--site-signal) 32%, var(--site-bg));
	}

	@media (max-width: 640px) {
		.release-hud {
			flex-wrap: wrap;
			border-radius: var(--site-radius-panel);
			padding: var(--site-space-4);
		}

		.hud-actions {
			display: grid;
			width: 100%;
			grid-template-columns: 1fr 1fr;
		}

		.hud-action {
			padding-inline: var(--site-space-3);
			white-space: nowrap;
		}
	}

	@media (prefers-reduced-motion: reduce) {
		.release-hud {
			animation: none;
		}

		.hud-action {
			transition: none;
		}
	}

	@media (forced-colors: active) {
		.release-hud,
		.hud-action {
			border-color: CanvasText;
		}
	}
</style>
