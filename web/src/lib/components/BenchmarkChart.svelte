<script lang="ts">
	import { onMount } from 'svelte';
	import uPlot from 'uplot';
	import 'uplot/dist/uPlot.min.css';
	import {
		CHART_METRIC_LABELS,
		CHART_METRIC_UNITS,
		SUMMARY_METRICS,
		SUMMARY_METRIC_LABELS,
		formatMetricDelta,
		formatMetricValue,
		isChartMetric,
		type BenchmarkDataset,
		type BenchmarkRun,
		type ChartMetric,
		type ChartSpec
	} from '$lib/content/chart.js';

	let { spec, dataset }: { spec: ChartSpec; dataset: BenchmarkDataset } =
		$props();

	let chartHost = $state<HTMLDivElement>();
	let chart: uPlot | undefined;
	let resizeObserver: ResizeObserver | undefined;

	const mode = $derived(
		spec.mode === 'summary'
			? 'summary'
			: spec.mode === 'stats'
				? 'stats'
				: 'timeseries'
	);
	const metric = $derived(
		isChartMetric(spec.metric)
			? spec.metric
			: ('cpu_percent' as ChartMetric)
	);
	const title = $derived(spec.title ?? CHART_METRIC_LABELS[metric]);
	const unit = $derived(spec.unit ?? CHART_METRIC_UNITS[metric]);
	const runs = $derived(
		dataset.runs.filter((run) => (run.samples?.length ?? 0) > 0)
	);
	// uPlot draws a canvas, so the accessible name must describe the series in words.
	const description = $derived(
		`${title}. ${unit}. ${runs.length} series: ${runs
			.map((run) => run.label)
			.join(', ')}.`
	);

	// The harness samples once per second, so the sample index is the second. Using the index
	// instead of elapsed_seconds keeps both runs on one shared x axis: their elapsed values
	// differ by a few hundred milliseconds and would otherwise produce two disjoint series.
	function buildChartData(
		chartRuns: BenchmarkRun[],
		chartMetric: ChartMetric
	): uPlot.AlignedData {
		const length = Math.max(
			...chartRuns.map((run) => run.samples?.length ?? 0)
		);
		const x = Array.from({ length }, (_, index) => index);
		const series = chartRuns.map((run) => {
			const values = (run.samples ?? []).map((sample) => {
				const value = sample[chartMetric];
				return typeof value === 'number' ? value : null;
			});
			return x.map((index) => values[index] ?? null);
		});
		return [x, ...series];
	}

	// Below this width the axis titles and the roomy tick spacing cost more plot area than they give.
	const COMPACT_WIDTH = 520;

	function chartOptions(
		width: number,
		height: number,
		chartRuns: BenchmarkRun[],
		chartUnit: string
	): uPlot.Options {
		const compact = width < COMPACT_WIDTH;
		const font = `${compact ? 10 : 12}px system-ui, sans-serif`;
		const styles = getComputedStyle(document.documentElement);
		const palette = [1, 2, 3, 4]
			.map((index) =>
				styles.getPropertyValue(`--site-chart-${index}`).trim()
			)
			.filter(Boolean);
		const colors = palette.length
			? palette
			: ['#7ea2db', '#eab064', '#a88cdb', '#7d838c'];
		return {
			width,
			height,
			padding: [12, compact ? 8 : 12, 0, 0],
			// One cursor across every chart on the page, so a hover reads all metrics at once.
			// Drag-zoom and live values would capture touch gestures and reflow the legend while the
			// page scrolls, so compact charts keep a static legend and leave vertical swipes to the page.
			cursor: {
				drag: { x: !compact, y: false },
				sync: { key: 'benchmark' }
			},
			legend: { show: true, live: !compact },
			scales: { x: { time: false } },
			series: [
				{ label: 'Seconds' },
				...chartRuns.map((run, index) => ({
					label: run.label,
					stroke: colors[(run.slot ?? index) % colors.length],
					width: 2,
					points: { show: false },
					value: (_self: uPlot, value: number | null) =>
						value == null ? '—' : value.toFixed(1)
				}))
			],
			axes: [
				{
					label: compact ? undefined : 'Seconds',
					font,
					size: compact ? 28 : undefined,
					space: compact ? 56 : 80,
					stroke: '#7d838c',
					grid: { stroke: 'rgba(255, 255, 255, 0.06)' },
					ticks: { stroke: 'rgba(255, 255, 255, 0.12)' }
				},
				{
					// The unit is already in the chart header, so the compact axis drops its title.
					label: compact ? undefined : chartUnit,
					font,
					size: compact ? 36 : undefined,
					stroke: '#7d838c',
					grid: { stroke: 'rgba(255, 255, 255, 0.06)' },
					ticks: { stroke: 'rgba(255, 255, 255, 0.12)' }
				}
			]
		};
	}

	function meanOf(
		run: BenchmarkRun,
		key: (typeof SUMMARY_METRICS)[number]
	): number | null {
		const value = run.summary?.metrics?.[key]?.mean;
		return typeof value === 'number' ? value : null;
	}

	function formatMetric(run: BenchmarkRun, key: ChartMetric): string {
		const value = run.summary?.metrics?.[key];
		if (!value || typeof value.mean !== 'number') return '—';
		const p95 =
			typeof value.p95 === 'number' ? ` (${value.p95.toFixed(1)})` : '';
		return `${value.mean.toFixed(1)}${p95}`;
	}

	onMount(() => {
		if (mode !== 'timeseries' || !chartHost) return;
		const height =
			typeof spec.height === 'number' && spec.height > 0
				? spec.height
				: 320;
		const data = buildChartData(runs, metric);
		let compact = chartHost.clientWidth < COMPACT_WIDTH;
		const create = (width: number) => {
			chart?.destroy();
			chart = new uPlot(
				chartOptions(width, height, runs, unit),
				data,
				chartHost
			);
		};
		create(chartHost.clientWidth || 640);
		resizeObserver = new ResizeObserver((entries) => {
			const width = entries[0]?.contentRect.width;
			if (!width || !chart) return;
			// Crossing the breakpoint changes axis options, which uPlot only reads at construction.
			if (width < COMPACT_WIDTH !== compact) {
				compact = width < COMPACT_WIDTH;
				create(width);
			} else {
				chart.setSize({ width, height });
			}
		});
		resizeObserver.observe(chartHost);
		return () => {
			resizeObserver?.disconnect();
			chart?.destroy();
		};
	});
</script>

<section class="benchmark-chart" aria-label={title}>
	<header class="benchmark-chart-header">
		<h3>{title}</h3>
		{#if mode === 'summary'}
			<p>Mean (p95)</p>
		{:else if mode === 'timeseries'}
			<p>{unit}</p>
		{/if}
	</header>

	{#if runs.length === 0}
		<p class="benchmark-chart-empty">No samples in this dataset.</p>
	{:else if mode === 'stats'}
		<div class="benchmark-stats">
			{#each runs as run, index (run.label)}
				<section class="stat-card">
					<h4>{run.label}</h4>
					<dl>
						{#each SUMMARY_METRICS as key (key)}
							{@const value = meanOf(run, key)}
							{@const reference =
								index > 0 ? meanOf(runs[0], key) : null}
							<div>
								<dt>{SUMMARY_METRIC_LABELS[key]}</dt>
								<dd>
									{value == null
										? '—'
										: formatMetricValue(key, value)}
								</dd>
								{#if reference != null && value != null}
									<dd class="stat-delta">
										{formatMetricDelta(value, reference)}
									</dd>
								{/if}
							</div>
						{/each}
					</dl>
				</section>
			{/each}
		</div>
	{:else if mode === 'summary'}
		<div class="benchmark-table-scroll">
			<table class="benchmark-table">
				<thead>
					<tr>
						<th>Metric</th>
						{#each runs as run (run.label)}
							<th>{run.label}</th>
						{/each}
					</tr>
				</thead>
				<tbody>
					{#each SUMMARY_METRICS as key (key)}
						<tr>
							<th>{CHART_METRIC_LABELS[key]}</th>
							{#each runs as run (run.label)}
								<td>{formatMetric(run, key)}</td>
							{/each}
						</tr>
					{/each}
				</tbody>
			</table>
		</div>
	{:else}
		<div
			class="benchmark-chart-host"
			bind:this={chartHost}
			role="img"
			aria-label={description}
		></div>
	{/if}

	{#if spec.caption}
		<p class="benchmark-chart-caption">{spec.caption}</p>
	{/if}
</section>

<style>
	/* minmax(0, 1fr) lets the track shrink below the canvas width; an auto track would
	   pin the chart at its first measured width and the shell would clip the rest. */
	.benchmark-chart {
		display: grid;
		grid-template-columns: minmax(0, 1fr);
		gap: var(--site-space-3);
		min-width: 0;
	}

	.benchmark-chart-header {
		display: flex;
		flex-wrap: wrap;
		align-items: baseline;
		justify-content: space-between;
		gap: var(--site-space-4);
	}

	.benchmark-chart-header h3 {
		margin: 0;
		font-size: 0.95rem;
		font-weight: 600;
	}

	.benchmark-chart-header p {
		margin: 0;
		color: var(--site-faint);
		font-family: var(--site-font-mono);
		font-size: 0.65rem;
		text-transform: uppercase;
	}

	.benchmark-chart-caption {
		margin: 0;
		color: var(--site-muted);
		font-size: 0.8rem;
	}

	.benchmark-chart-host {
		min-width: 0;
		min-height: 12rem;
	}

	/* uPlot sizes its root to min-content, which lets a long legend overflow the shell. */
	.benchmark-chart-host :global(.uplot) {
		width: 100%;
		max-width: 100%;
	}

	.benchmark-chart-host :global(.u-over) {
		touch-action: pan-y;
	}

	.benchmark-chart-host :global(.u-legend) {
		color: var(--site-muted);
		font-family: var(--site-font-ui);
		font-size: 0.75rem;
		text-align: left;
	}

	/* Each entry wraps as one unit, so a name never splits from its marker or value. */
	.benchmark-chart-host :global(.u-legend .u-series) {
		margin-right: var(--site-space-3);
		white-space: nowrap;
	}

	/* The x value is on the axis, so its legend entry only costs a line. */
	.benchmark-chart-host :global(.u-legend tr:first-child) {
		display: none;
	}

	/* A fixed value width keeps the row from reflowing as the cursor moves. */
	.benchmark-chart-host :global(.u-legend .u-value) {
		min-width: 5ch;
		text-align: right;
	}

	.benchmark-chart-host :global(.u-legend .u-marker) {
		border-radius: 999px;
	}

	.benchmark-chart-empty {
		margin: 0;
		color: var(--site-muted);
		font-size: 0.85rem;
	}

	.benchmark-stats {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(15rem, 1fr));
		gap: var(--site-space-4);
	}

	.stat-card {
		border: 1px solid var(--site-border);
		border-radius: var(--site-radius-panel);
		background: var(--site-panel);
		padding: var(--site-space-4);
	}

	.stat-card h4 {
		margin: 0 0 var(--site-space-3);
		color: var(--site-text);
		font-size: 0.85rem;
		font-weight: 600;
	}

	.stat-card dl {
		display: grid;
		gap: 0.35rem;
		margin: 0;
	}

	.stat-card dl > div {
		display: grid;
		grid-template-columns: 1fr auto auto;
		align-items: baseline;
		gap: var(--site-space-3);
	}

	.stat-card dt {
		color: var(--site-muted);
		font-size: 0.8rem;
	}

	.stat-card dd {
		margin: 0;
		font-variant-numeric: tabular-nums;
		font-weight: 600;
	}

	.stat-card .stat-delta {
		min-width: 3.5rem;
		color: var(--site-faint);
		font-family: var(--site-font-mono);
		font-size: 0.75rem;
		font-weight: 500;
		text-align: right;
	}

	.benchmark-table-scroll {
		overflow-x: auto;
	}

	.benchmark-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.85rem;
	}

	.benchmark-table th,
	.benchmark-table td {
		border-bottom: 1px solid var(--site-border);
		padding: 0.45rem 0.6rem;
		text-align: right;
		white-space: nowrap;
	}

	.benchmark-table th:first-child,
	.benchmark-table td:first-child {
		text-align: left;
	}

	.benchmark-table thead th {
		color: var(--site-muted);
		font-family: var(--site-font-mono);
		font-size: 0.65rem;
		font-weight: 500;
		text-transform: uppercase;
	}

	/* Narrow screens: stack the header and let the legend wrap instead of clipping. */
	@media (max-width: 640px) {
		.benchmark-chart-header {
			flex-direction: column;
			align-items: flex-start;
			gap: var(--site-space-2);
		}
	}
</style>
