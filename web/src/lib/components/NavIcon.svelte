<script lang="ts">
	type Props = {
		route: string;
	};

	let { route }: Props = $props();

	// SF Symbols–like outlines for each top-level documentation section.
	const paths: Record<string, string> = {
		'/': 'M3.5 11 12 4l8.5 7M6 9v11h12V9M10 20v-5.5h4V20',
		'/installation/': 'M12 3.5v11M7.5 10.5 12 15l4.5-4.5M4.5 15.5v4h15v-4',
		'/help/':
			'M12 20.5a8.5 8.5 0 1 0 0-17 8.5 8.5 0 0 0 0 17ZM9.6 9.4a2.5 2.5 0 1 1 3.4 2.3c-.6.3-1 .8-1 1.5v.5M12 16.6v.2',
		'/development/': 'M8.5 7 3.5 12l5 5M15.5 7l5 5-5 5M13.5 5l-3 14',
		'/legal/':
			'M6.5 3.5h7.5l4 4v13h-11.5ZM14 3.5V8h4M9.5 12h5.5M9.5 15.5h5.5',
		'/changelog/':
			'M12 20.5a8.5 8.5 0 1 0 0-17 8.5 8.5 0 0 0 0 17ZM12 7.5V12l3 2'
	};
	const fallback = 'M6.5 3.5h7.5l4 4v13h-11.5ZM14 3.5V8h4';
</script>

<svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true">
	<path
		d={paths[route] ?? fallback}
		fill="none"
		stroke="currentColor"
		stroke-width="1.6"
		stroke-linecap="round"
		stroke-linejoin="round"
	/>
</svg>

<style>
	svg {
		flex: none;
	}
</style>
