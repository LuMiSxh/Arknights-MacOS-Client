<script lang="ts">
	type Props = {
		href: string;
		iconUrl: string;
		compact?: boolean;
	};

	let { href, iconUrl, compact = false }: Props = $props();
</script>

<a class="product-mark" class:compact {href} aria-label="Arknights Client home">
	<img src={iconUrl} alt="" width="32" height="32" />
	<span
		>{#if compact}Arknights Client{:else}Arknights<br />Client{/if}</span
	>
</a>

<style>
	.product-mark {
		display: inline-flex;
		min-height: var(--site-touch-target);
		align-items: center;
		gap: var(--site-space-3);
		color: var(--site-text);
		font-family: var(--site-font-mono);
		font-size: 0.75rem;
		font-weight: 700;
		letter-spacing: 0.08em;
		line-height: 1.2;
		text-decoration: none;
		text-transform: uppercase;
	}

	img {
		width: 2rem;
		height: 2rem;
		border-radius: 8px;
	}

	.compact {
		gap: var(--site-space-2);
		font-size: 0.7rem;
	}

	.compact img {
		width: 1.75rem;
		height: 1.75rem;
	}
</style>
