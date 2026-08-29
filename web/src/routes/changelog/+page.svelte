<script lang="ts">
	import type { PageProps } from './$types';
	import ChangelogView from '$lib/components/ChangelogView.svelte';

	let { data }: PageProps = $props();
</script>

<ChangelogView content={data.content} />
