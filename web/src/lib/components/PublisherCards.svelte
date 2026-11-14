<script lang="ts">
	import type { Server } from '$lib/servers.js';

	type Props = {
		servers: readonly Server[];
	};

	let { servers }: Props = $props();

	// Groups the flat server list by publisher, keeping the setup assistant's order.
	const publishers = $derived.by(() => {
		const groups = new Map<string, Server[]>();
		for (const server of servers) {
			groups.set(server.publisher, [
				...(groups.get(server.publisher) ?? []),
				server
			]);
		}
		return [...groups];
	});
</script>

<ul class="publishers">
	{#each publishers as [publisher, list] (publisher)}
		<li class="publisher">
			<h3>{publisher}</h3>
			<ul>
				{#each list as server (server.name)}
					<li>{server.name}</li>
				{/each}
			</ul>
		</li>
	{/each}
</ul>

<style>
	.publishers {
		display: grid;
		grid-template-columns: repeat(3, minmax(0, 1fr));
		gap: var(--site-space-4);
		margin: 0;
		padding: 0;
		list-style: none;
	}

	.publisher {
		border: 1px solid var(--site-hairline);
		border-radius: var(--site-radius-group);
		background: var(--site-group-fill);
		padding: var(--site-space-5) var(--site-space-6);
	}

	.publisher h3 {
		margin: 0 0 var(--site-space-3);
		color: var(--site-text-primary);
		font-size: 1rem;
		font-weight: 500;
	}

	.publisher ul {
		margin: 0;
		padding: 0;
		list-style: none;
	}

	.publisher li {
		padding: var(--site-space-2) 0;
		color: var(--site-text-secondary);
		font-size: 0.9rem;
	}

	.publisher li + li {
		border-top: 1px solid var(--site-hairline);
	}

	@media (max-width: 760px) {
		.publishers {
			grid-template-columns: minmax(0, 1fr);
		}
	}
</style>
