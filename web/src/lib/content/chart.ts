export const CHART_METRICS = [
	'cpu_percent',
	'system_cpu_percent',
	'background_cpu_percent',
	'background_process_count',
	'resident_mib',
	'gpu_device_percent',
	'gpu_renderer_percent',
	'gpu_tiler_percent',
	'free_mib',
	'wired_mib',
	'compressed_mib'
] as const;

export type ChartMetric = (typeof CHART_METRICS)[number];

/** The subset the summary table shows. The rest is diagnostic detail for developers. */
export const SUMMARY_METRICS = [
	'cpu_percent',
	'gpu_device_percent',
	'resident_mib'
] as const;

export const CHART_METRIC_LABELS: Record<ChartMetric, string> = {
	cpu_percent: 'CPU (% of one core)',
	system_cpu_percent: 'System CPU (% of one core)',
	background_cpu_percent: 'Background CPU (% of one core)',
	background_process_count: 'Background process count',
	resident_mib: 'Resident memory (MiB)',
	gpu_device_percent: 'GPU device (%)',
	gpu_renderer_percent: 'GPU renderer (%)',
	gpu_tiler_percent: 'GPU tiler (%)',
	free_mib: 'Free memory (MiB)',
	wired_mib: 'Wired memory (MiB)',
	compressed_mib: 'Compressed memory (MiB)'
};

export const CHART_METRIC_UNITS: Record<ChartMetric, string> = {
	cpu_percent: '% of one core',
	system_cpu_percent: '% of one core',
	background_cpu_percent: '% of one core',
	background_process_count: 'processes',
	resident_mib: 'MiB',
	gpu_device_percent: '%',
	gpu_renderer_percent: '%',
	gpu_tiler_percent: '%',
	free_mib: 'MiB',
	wired_mib: 'MiB',
	compressed_mib: 'MiB'
};

export interface ChartSpec {
	src: string;
	metric?: ChartMetric;
	mode?: 'timeseries' | 'summary';
	title?: string;
	unit?: string;
	height?: number;
}

export interface BenchmarkSample {
	elapsed_seconds?: number | null;
	[key: string]: number | string | null | undefined;
}

export interface BenchmarkSummaryMetric {
	mean?: number;
	p95?: number;
}

export interface BenchmarkRun {
	label: string;
	target?: string;
	case?: string;
	note?: string;
	summary?: { metrics?: Record<string, BenchmarkSummaryMetric> };
	samples?: BenchmarkSample[];
}

export interface BenchmarkDataset {
	schemaVersion: number;
	title?: string;
	generatedAt?: string;
	machine?: Record<string, unknown>;
	runs: BenchmarkRun[];
}

export function isChartMetric(value: unknown): value is ChartMetric {
	return (
		typeof value === 'string' &&
		(CHART_METRICS as readonly string[]).includes(value)
	);
}
