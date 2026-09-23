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
			for (const block of blocks)
				block.classList.remove('diagram-expanded');
			mermaid.initialize({
				startOnLoad: false,
				securityLevel: 'strict',
				theme: 'base',
				themeVariables: {
					background: '#151619',
					primaryColor: '#1b1c20',
					primaryTextColor: '#f2f3f5',
					primaryBorderColor: '#477acc',
					secondaryColor: '#1b1c20',
					tertiaryColor: '#0b0c0e',
					lineColor: '#a1a6ae',
					edgeLabelBackground: '#151619',
					clusterBkg: '#151619',
					clusterBorder: '#2a2c31'
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
