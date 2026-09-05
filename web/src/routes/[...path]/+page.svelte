<script lang="ts">
	import type { PageProps } from './$types';
	import ContentView from '$lib/components/ContentView.svelte';

	let { data }: PageProps = $props();
</script>

<ContentView
	content={data.content}
	neighbors={data.neighbors}
	breadcrumbs={data.breadcrumbs}
/>
