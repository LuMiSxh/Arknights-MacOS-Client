<script lang="ts">
	import { base } from '$app/paths';
	import { absoluteSiteUrl, normalizeBasePath } from '$lib/site.js';

	interface Props {
		title: string;
		description: string;
		path: string;
		robots?: string;
	}

	let { title, description, path, robots }: Props = $props();
	const configuredBasePath = normalizeBasePath(
		typeof process !== 'undefined' && process.env.BASE_PATH
			? process.env.BASE_PATH
			: base
	);

	const canonicalUrl = $derived(absoluteSiteUrl(path, configuredBasePath));
	const socialImageUrl = $derived(
		absoluteSiteUrl('/AppIcon-128.png', configuredBasePath)
	);
</script>

<svelte:head>
	<title>{title}</title>
	<meta name="description" content={description} />
	{#if robots}<meta name="robots" content={robots} />{/if}
	<link rel="canonical" href={canonicalUrl} />
	<meta property="og:type" content="website" />
	<meta property="og:title" content={title} />
	<meta property="og:description" content={description} />
	<meta property="og:url" content={canonicalUrl} />
	<meta property="og:image" content={socialImageUrl} />
	<meta name="twitter:card" content="summary" />
	<meta name="twitter:title" content={title} />
	<meta name="twitter:description" content={description} />
	<meta name="twitter:image" content={socialImageUrl} />
</svelte:head>
