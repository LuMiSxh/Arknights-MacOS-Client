<script lang="ts">
	import { onMount } from 'svelte';
	import { mount, unmount } from 'svelte';
	import { base } from '$app/paths';
	import BenchmarkChart from './BenchmarkChart.svelte';
	import type { BenchmarkDataset, ChartSpec } from '$lib/content/chart.js';

	let { route }: { route: string } = $props();

	function hasSrc(value: unknown): value is { src: string } {
		return (
			typeof value === 'object' &&
			value !== null &&
			'src' in value &&
			typeof value.src === 'string'
		);
	}

	onMount(() => {
		let cancelled = false;
		const instances: Array<{
			instance: ReturnType<typeof mount>;
			element: HTMLElement;
		}> = [];
		const cache = new Map<string, Promise<BenchmarkDataset>>();

		function escapeHtml(value: string): string {
			return value
				.replaceAll('&', '&amp;')
				.replaceAll('<', '&lt;')
				.replaceAll('>', '&gt;')
				.replaceAll('"', '&quot;')
				.replaceAll("'", '&#39;');
		}

		function showError(block: HTMLElement, message: string): void {
			block.innerHTML = `<p class="chart-status chart-error">${escapeHtml(message)}</p>`;
		}

		function parseSpec(source: string): ChartSpec {
			const value: unknown = JSON.parse(source);
			if (!hasSrc(value)) {
				throw new Error('Chart spec needs a src string');
			}
			if (!value.src.startsWith('/') || value.src.startsWith('//')) {
				throw new Error('Chart src must be a site path');
			}
			return value;
		}

		async function load(src: string): Promise<BenchmarkDataset> {
			const url = new URL(`${base}${src}`, window.location.origin).href;
			let promise = cache.get(url);
			if (!promise) {
				promise = fetch(url).then(async (response) => {
					if (!response.ok) {
						throw new Error(
							`Unable to load ${src} (HTTP ${response.status})`
						);
					}
					return (await response.json()) as BenchmarkDataset;
				});
				cache.set(url, promise);
			}
			return promise;
		}

		async function renderCharts(): Promise<void> {
			const blocks = [
				...document.querySelectorAll<HTMLElement>(
					'.chart-shell[data-chart]'
				)
			];
			for (const block of blocks) {
				if (block.dataset.chartMounted === 'true') continue;
				const source = block.querySelector('code')?.textContent?.trim();
				if (!source) continue;
				block.dataset.chartMounted = 'true';
				let spec: ChartSpec;
				try {
					spec = parseSpec(source);
				} catch (error) {
					showError(
						block,
						error instanceof Error
							? error.message
							: 'Invalid chart spec'
					);
					continue;
				}
				block.innerHTML = '<p class="chart-status">Loading chart…</p>';
				try {
					const dataset = await load(spec.src);
					if (cancelled) return;
					const target = document.createElement('div');
					target.className = 'benchmark-chart-mount';
					block.replaceChildren(target);
					const instance = mount(BenchmarkChart, {
						target,
						props: { spec, dataset }
					});
					instances.push({ instance, element: block });
				} catch (error) {
					if (cancelled) return;
					showError(
						block,
						error instanceof Error
							? error.message
							: 'Unable to load chart'
					);
				}
			}
		}

		void route;
		void renderCharts();

		return () => {
			cancelled = true;
			for (const { instance } of instances) unmount(instance);
		};
	});
</script>
