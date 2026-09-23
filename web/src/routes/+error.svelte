<script lang="ts">
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import PageMetadata from '$lib/components/PageMetadata.svelte';

	const status = $derived(page.status);
	const error = $derived(page.error);

	const errorTitle = $derived(
		status === 404
			? 'Page not found'
			: status >= 500
				? 'Something went wrong'
				: 'Request failed'
	);
	const fallbackMessage = $derived(
		status === 404
			? 'The page may have moved, or the link may be stale.'
			: 'The request could not be completed. Try again or return to the home page.'
	);
	const errorMessage = $derived(
		error?.message &&
			!['Not Found', 'Internal Error'].includes(error.message)
			? error.message
			: fallbackMessage
	);
</script>

<PageMetadata
	title={`${status} · ${errorTitle} · Arknights Client`}
	description={fallbackMessage}
	path={page.url.pathname}
	robots="noindex"
/>

<section class="error-page" aria-labelledby="error-title">
	<p class="eyebrow">Error {status}</p>
	<div class="page-heading">
		<h1 id="error-title">{errorTitle}</h1>
		<p>{errorMessage}</p>
	</div>
	<a class="round-action" href={resolve('/')}>Return home</a>
</section>

<style>
	.error-page {
		max-width: 42rem;
		margin: clamp(4rem, 14vw, 10rem) auto;
		padding-inline: var(--site-space-4);
	}

	.error-page a {
		margin-top: var(--site-space-6);
		padding-inline: var(--site-space-5);
	}
</style>
