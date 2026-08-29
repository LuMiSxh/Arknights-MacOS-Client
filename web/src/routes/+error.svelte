<script lang="ts">
	import { resolve } from '$app/paths';
	import { page } from '$app/state';

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

<svelte:head>
	<title>{status} · {errorTitle} · Arknights Client</title>
</svelte:head>

<section class="error-page" aria-labelledby="error-title">
	<div class="eyebrow">Error {status}</div>
	<h1 id="error-title">{errorTitle}</h1>
	<p>{errorMessage}</p>
	<a href={resolve('/')}>Return home <span aria-hidden="true">↗</span></a>
</section>

<style>
	.error-page {
		max-width: 42rem;
		margin: clamp(4rem, 14vw, 10rem) auto;
	}

	.error-page h1 {
		margin: 0.8rem 0;
		font-size: clamp(2rem, 4vw, 3.2rem);
		letter-spacing: -0.045em;
		line-height: 1;
	}

	.error-page p {
		max-width: 48ch;
	}

	.error-page a {
		display: inline-flex;
		gap: 0.7rem;
		margin-top: 1rem;
		color: var(--color-anasthasia-text);
		font-weight: 700;
		text-decoration: none;
	}
</style>
