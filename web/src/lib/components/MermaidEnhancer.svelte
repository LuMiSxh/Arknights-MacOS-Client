<script lang="ts">
	import { onMount } from 'svelte';
	import type { SiteRoute } from '$lib/content/types.js';

	let { route }: { route: SiteRoute } = $props();

	onMount(() => {
		let cancelled = false;
		let sequence = 0;
		let requestedGeneration = 0;
		let renderQueue = Promise.resolve();
		const sources = new Map<
			HTMLElement,
			{ source: string; fallback: string }
		>();

		function toggleDiagram(event: MouseEvent) {
			if (!(event.target instanceof Element)) return;
			const button =
				event.target.closest<HTMLButtonElement>('.diagram-rendered');
			const shell = button?.closest<HTMLElement>('.mermaid-shell');
			if (!button || !shell) return;
			const expanded = shell.classList.toggle('diagram-expanded');
			button.setAttribute('aria-expanded', String(expanded));
			button.setAttribute(
				'aria-label',
				expanded ? 'Close diagram' : 'Expand diagram'
			);
			const hint = button.querySelector('.diagram-hint');
			if (hint) hint.textContent = expanded ? 'Close' : 'Expand';
		}

		function closeDiagram(event: KeyboardEvent) {
			if (event.key !== 'Escape') return;
			const shell = document.querySelector<HTMLElement>(
				'.mermaid-shell.diagram-expanded'
			);
			if (!shell) return;
			shell.classList.remove('diagram-expanded');
			const button =
				shell.querySelector<HTMLButtonElement>('.diagram-rendered');
			button?.setAttribute('aria-expanded', 'false');
			button?.setAttribute('aria-label', 'Expand diagram');
			const hint = button?.querySelector('.diagram-hint');
			if (hint) hint.textContent = 'Expand';
			button?.focus();
		}

		async function renderDiagrams(generation: number) {
			const blocks = [
				...document.querySelectorAll<HTMLElement>(
					'.mermaid-shell[data-mermaid]'
				)
			];
			if (!blocks.length) return;

			const { default: mermaid } = await import('mermaid');
			if (cancelled || generation !== requestedGeneration) return;
			const dark = document.documentElement.classList.contains('dark');
			for (const block of blocks)
				block.classList.remove('diagram-expanded');
			mermaid.initialize({
				startOnLoad: false,
				securityLevel: 'strict',
				theme: 'base',
				themeVariables: dark
					? {
							background: '#11151a',
							primaryColor: '#1b252c',
							primaryTextColor: '#ffffff',
							primaryBorderColor: '#6f8492',
							secondaryColor: '#202830',
							tertiaryColor: '#090b0d',
							lineColor: '#aab2ba',
							edgeLabelBackground: '#11151a',
							clusterBkg: '#11151a',
							clusterBorder: '#3d4650'
						}
					: {
							background: '#fbfbfc',
							primaryColor: '#e7ecef',
							primaryTextColor: '#15171a',
							primaryBorderColor: '#657783',
							secondaryColor: '#f2f3f5',
							tertiaryColor: '#e7e9ec',
							lineColor: '#5d636c',
							edgeLabelBackground: '#fbfbfc',
							clusterBkg: '#f2f3f5',
							clusterBorder: '#b8bdc5'
						}
			});

			for (const [index, block] of blocks.entries()) {
				let saved = sources.get(block);
				if (!saved) {
					const source = block
						.querySelector('code')
						?.textContent?.trim();
					if (!source) continue;
					saved = { source, fallback: block.innerHTML };
					sources.set(block, saved);
				}
				try {
					const id = `diagram-${sequence++}-${index}-${route.replace(/[^a-z0-9]/gi, '-')}`;
					const result = await mermaid.render(id, saved.source);
					if (cancelled || generation !== requestedGeneration) return;
					block.innerHTML = `<button class="diagram-rendered" type="button" aria-expanded="false" aria-label="Expand diagram">${result.svg}<span class="diagram-hint" aria-hidden="true">Expand</span></button>`;
					result.bindFunctions?.(block);
					delete block.dataset.diagramError;
				} catch {
					block.innerHTML = saved.fallback;
					block.dataset.diagramError = 'true';
				}
			}
		}

		function requestRender() {
			const generation = ++requestedGeneration;
			renderQueue = renderQueue
				.then(() => renderDiagrams(generation))
				.catch(() => undefined);
		}

		const observer = new MutationObserver(requestRender);
		observer.observe(document.documentElement, {
			attributes: true,
			attributeFilter: ['class']
		});
		document.addEventListener('click', toggleDiagram);
		document.addEventListener('keydown', closeDiagram);
		requestRender();

		return () => {
			cancelled = true;
			observer.disconnect();
			document.removeEventListener('click', toggleDiagram);
			document.removeEventListener('keydown', closeDiagram);
		};
	});
</script>
