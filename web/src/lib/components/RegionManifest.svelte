<script lang="ts">
	type RegionStatus = 'Supported' | 'Canary';
	type Region = {
		name: string;
		publisher: string;
		status: RegionStatus;
	};
	type Props = {
		regions: readonly Region[];
	};

	let { regions }: Props = $props();
</script>

<table class="region-manifest">
	<caption class="panel-title">Supported regions</caption>
	<thead class="sr-only">
		<tr>
			<th scope="col">Client</th>
			<th scope="col">Publisher</th>
			<th scope="col">Status</th>
		</tr>
	</thead>
	<tbody>
		{#each regions as region (region.name)}
			<tr>
				<th scope="row">{region.name}</th>
				<td class="publisher">{region.publisher}</td>
				<td>
					<span class="status" data-status={region.status}
						>{region.status}</span
					>
				</td>
			</tr>
		{/each}
	</tbody>
</table>

<style>
	.region-manifest {
		width: 100%;
		border-collapse: collapse;
	}

	tbody tr + tr {
		border-top: 1px solid var(--site-line);
	}

	tbody th,
	tbody td {
		padding: var(--site-space-3) 0;
		text-align: left;
		vertical-align: middle;
	}

	tbody th {
		font-size: 0.95rem;
		font-weight: 500;
	}

	.publisher {
		padding-inline: var(--site-space-3);
		color: var(--site-faint);
		font-size: 0.8rem;
	}

	td:last-child {
		text-align: right;
	}

	.status {
		display: inline-flex;
		border: 1px solid var(--site-border);
		border-radius: var(--site-radius-capsule);
		padding: 0.2rem 0.7rem;
		font-size: 0.75rem;
		font-weight: 650;
	}

	.status[data-status='Supported'] {
		background: var(--color-anasthasia-success-surface);
		color: var(--site-success);
	}

	.status[data-status='Canary'] {
		background: var(--color-anasthasia-warning-surface);
		color: var(--site-warning);
	}
</style>
