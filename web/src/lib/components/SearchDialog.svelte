<script lang="ts">
	import { resolve } from '$app/paths';
	import { tick, untrack } from 'svelte';
	import {
		Button,
		Dialog,
		EmptyState,
		Input,
		LinkCard,
		SectionLabel
	} from 'anasthasia';
	import {
		highlightSearchText,
		searchContent,
		type SearchEntry,
		type SearchResult
	} from '$lib/content/search.js';
	import { scrollDeltaFor } from '$lib/scroll.js';

	interface Props {
		open?: boolean;
	}

	let { open = $bindable(false) }: Props = $props();
	let entries = $state.raw<SearchEntry[]>([]);
	let loaded = $state(false);
	let loading = $state(false);
	let failed = $state(false);
	let request: Promise<void> | undefined;
	let query = $state('');
	let selectedIndex = $state(0);
	let focusFrame: number | undefined;
	let scrollFrame: number | undefined;
	let resultsList = $state<HTMLUListElement>();
	const results = $derived(searchContent(entries, query));

	function resultId(result: SearchResult, index: number): string {
		const suffix = result.heading?.id ?? result.route;
		return `search-result-${index}-${suffix.replace(/[^a-z\d]+/gi, '-')}`;
	}

	function resetSearch() {
		query = '';
		selectedIndex = 0;
	}

	function dismiss() {
		open = false;
		resetSearch();
	}

	async function fetchSearchIndex() {
		loading = true;
		failed = false;
		try {
			const response = await fetch(resolve('/search-index.json'));
			if (!response.ok)
				throw new Error(`Search index: ${response.status}`);
			const value: unknown = await response.json();
			if (!Array.isArray(value))
				throw new Error('Search index is invalid');
			entries = value as SearchEntry[];
			loaded = true;
		} catch {
			failed = true;
		} finally {
			loading = false;
			request = undefined;
		}
	}

	function ensureSearchIndex() {
		if (loaded || request) return;
		request = fetchSearchIndex();
	}

	function retrySearch() {
		ensureSearchIndex();
	}

	function focusSearchInput() {
		if (typeof window === 'undefined') return;
		if (focusFrame !== undefined) cancelAnimationFrame(focusFrame);
		focusFrame = requestAnimationFrame(() => {
			focusFrame = undefined;
			if (!open) return;
			document.getElementById('search-dialog-input')?.focus();
		});
	}

	$effect(() => {
		if (!open) return;
		untrack(ensureSearchIndex);
		let cancelled = false;
		void tick().then(() => {
			if (!cancelled) focusSearchInput();
		});
		return () => {
			cancelled = true;
			if (focusFrame !== undefined) {
				cancelAnimationFrame(focusFrame);
				focusFrame = undefined;
			}
			if (scrollFrame !== undefined) {
				cancelAnimationFrame(scrollFrame);
				scrollFrame = undefined;
			}
		};
	});

	function activateSelected() {
		const result = results[selectedIndex];
		if (!result) return;
		document.getElementById(resultId(result, selectedIndex))?.click();
	}

	function moveSelection(direction: 1 | -1) {
		if (!results.length) return;
		selectedIndex =
			(selectedIndex + direction + results.length) % results.length;
		if (typeof window === 'undefined') return;
		if (scrollFrame !== undefined) cancelAnimationFrame(scrollFrame);
		scrollFrame = requestAnimationFrame(() => {
			scrollFrame = undefined;
			if (!open) return;
			const result = results[selectedIndex];
			if (!result) return;
			const selectedElement = document.getElementById(
				resultId(result, selectedIndex)
			);
			if (!selectedElement || !resultsList) return;
			const delta = scrollDeltaFor(
				resultsList.getBoundingClientRect(),
				selectedElement.getBoundingClientRect()
			);
			if (delta)
				resultsList.scrollBy({
					top: delta,
					behavior: 'auto'
				});
		});
	}

	function handleKeydown(event: KeyboardEvent) {
		const key = event.key.toLowerCase();
		if ((event.metaKey || event.ctrlKey) && key === 'k') {
			event.preventDefault();
			open = !open;
			return;
		}
		if (!open) return;
		const interactiveTarget =
			event.target instanceof Element
				? event.target.closest('button, a')
				: null;
		if (interactiveTarget) return;
		if (key === 'arrowdown') {
			event.preventDefault();
			moveSelection(1);
		} else if (key === 'arrowup') {
			event.preventDefault();
			moveSelection(-1);
		} else if (key === 'enter') {
			event.preventDefault();
			activateSelected();
		}
	}
</script>

{#snippet highlighted(value: string)}
	{#each highlightSearchText(value, query) as fragment, index (index)}
		{#if fragment.matched}
			<mark class="bg-anasthasia-accent/30 text-inherit"
				>{fragment.text}</mark
			>
		{:else}{fragment.text}{/if}
	{/each}
{/snippet}

<svelte:window onkeydown={handleKeydown} />

<Dialog
	bind:open
	title="Documentation search"
	description="Search titles, sections, descriptions, and page text."
	closeOnBackdrop
	closeOnEscape
	onclose={resetSearch}
	class="w-[min(42rem,calc(100vw-2rem))]"
>
	<div class="grid gap-4" aria-busy={loading}>
		<Input
			id="search-dialog-input"
			type="search"
			bind:value={query}
			label="Search documentation"
			placeholder="Try “Wine prefix” or “VIRGA”"
			autocomplete="off"
			autofocus
			oninput={() => (selectedIndex = 0)}
		/>

		{#if failed}
			<div role="alert">
				<EmptyState
					title="Search unavailable"
					description="The documentation index could not be loaded. Try again."
				>
					{#snippet actions()}
						<Button type="button" size="sm" onclick={retrySearch}
							>Retry</Button
						>
					{/snippet}
				</EmptyState>
			</div>
		{:else if !loaded}
			<div role="status" aria-live="polite">
				<EmptyState
					title="Loading search"
					description="Preparing the documentation index…"
				/>
			</div>
		{:else if !query.trim()}
			<div role="status">
				<EmptyState
					title="Start with a few words"
					description="Search page titles, sections, descriptions, and body text."
				/>
			</div>
		{:else if results.length === 0}
			<div role="status">
				<EmptyState
					title="No matching pages"
					description="Try a shorter phrase or a related term."
				/>
			</div>
		{:else}
			<div
				class="flex items-baseline justify-between gap-4"
				aria-live="polite"
			>
				<SectionLabel>Matches</SectionLabel>
				<span
					class="text-xs font-bold tracking-wider text-anasthasia-muted uppercase"
					>{results.length} result{results.length === 1
						? ''
						: 's'}</span
				>
			</div>
			<ul
				bind:this={resultsList}
				class="m-0 grid max-h-[min(50dvh,28rem)] list-none gap-1 overflow-y-auto p-0"
				aria-label="Documentation search results"
			>
				{#each results as result, index (result.route + (result.heading?.id ?? ''))}
					<li class="min-w-0">
						<LinkCard
							id={resultId(result, index)}
							href={resolve(
								`${result.route}${result.heading ? `#${result.heading.id}` : ''}`
							)}
							class={`grid gap-1 ${
								selectedIndex === index
									? '!border-anasthasia-accent !bg-anasthasia-panel'
									: ''
							}`}
							data-selected={selectedIndex === index
								? 'true'
								: undefined}
							onclick={dismiss}
							onmouseenter={() => (selectedIndex = index)}
						>
							<strong class="text-[0.88rem]"
								>{@render highlighted(result.title)}</strong
							>
							{#if result.heading}
								<small
									class="text-[0.7rem] leading-[1.45] text-anasthasia-muted"
									>Section · {@render highlighted(
										result.heading.text
									)}</small
								>
							{:else}
								<small
									class="text-[0.7rem] leading-[1.45] text-anasthasia-muted"
									>{@render highlighted(
										result.description
									)}</small
								>
							{/if}
							{#if result.excerpt}
								<span
									class="line-clamp-2 text-[0.7rem] leading-[1.45] text-anasthasia-muted"
									>{@render highlighted(result.excerpt)}</span
								>
							{/if}
						</LinkCard>
					</li>
				{/each}
			</ul>
			<p class="sr-only" aria-live="polite">
				Selected {selectedIndex + 1} of {results.length}:
				{results[selectedIndex]?.title}
			</p>
		{/if}
	</div>
</Dialog>
