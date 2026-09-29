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
			const closeButton = event.target.closest<HTMLButtonElement>(
				'.diagram-dialog-close'
			);
			if (closeButton) {
				closeButton
					.closest<HTMLDialogElement>('.diagram-dialog')
					?.close();
				return;
			}
			const clickedDialog =
				event.target.closest<HTMLDialogElement>('.diagram-dialog');
			if (clickedDialog) {
				if (event.target === clickedDialog) clickedDialog.close();
				return;
			}
			const button =
				event.target.closest<HTMLButtonElement>('.diagram-rendered');
			const shell = button?.closest<HTMLElement>('.mermaid-shell');
			const dialog =
				shell?.querySelector<HTMLDialogElement>('.diagram-dialog');
			const content = dialog?.querySelector<HTMLElement>(
				'.diagram-dialog-content'
			);
			const svg = button?.querySelector('svg');
			if (!button || !shell || !dialog || !content || !svg) return;
			content.append(svg);
			button.setAttribute('aria-expanded', 'true');
			button.setAttribute('aria-label', 'Close diagram');
			dialog.showModal();
		}

		function restoreDiagram(event: Event) {
			const dialog = event.currentTarget;
			if (!(dialog instanceof HTMLDialogElement)) return;
			const shell = dialog.closest<HTMLElement>('.mermaid-shell');
			const button =
				shell?.querySelector<HTMLButtonElement>('.diagram-rendered');
			if (!button) return;
			const svg = dialog.querySelector('svg');
			const hint = button.querySelector('.diagram-hint');
			if (svg) button.insertBefore(svg, hint);
			button?.setAttribute('aria-expanded', 'false');
			button?.setAttribute('aria-label', 'Expand diagram');
			if (hint) hint.textContent = 'Expand';
			if (button.isConnected) button.focus();
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
					block.innerHTML = `<button class="diagram-rendered" type="button" aria-expanded="false" aria-label="Expand diagram">${result.svg}<span class="diagram-hint" aria-hidden="true">Expand</span></button><dialog class="diagram-dialog" aria-label="Expanded diagram"><button class="diagram-dialog-close" type="button" autofocus>Close diagram</button><div class="diagram-dialog-content"></div></dialog>`;
					block
						.querySelector<HTMLDialogElement>('.diagram-dialog')
						?.addEventListener('close', restoreDiagram);
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
		requestRender();

		return () => {
			cancelled = true;
			observer.disconnect();
			document.removeEventListener('click', toggleDiagram);
		};
	});
</script>
