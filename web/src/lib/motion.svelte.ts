import { cubicOut } from 'svelte/easing';
import { prefersReducedMotion, Tween } from 'svelte/motion';
import type { Attachment } from 'svelte/attachments';
import type { TransitionConfig } from 'svelte/transition';

/** Matches the launcher's structural motion: a short rise with a soft settle. */
export const structureDuration = 380;

export function rise(
	_node: Element,
	{ delay = 0, duration = structureDuration, y = 12, scale = 1 } = {}
): TransitionConfig {
	if (prefersReducedMotion.current) return { duration: 0 };
	return {
		delay,
		duration,
		easing: cubicOut,
		css: (t, u) =>
			`opacity: ${t}; transform: translateY(${u * y}px) scale(${scale + (1 - scale) * t});`
	};
}

/**
 * Fades an element in the first time it scrolls into view. Elements already visible on load
 * stay untouched, so server-rendered content never flashes out and back in.
 */
export function reveal(delay = 0): Attachment<HTMLElement> {
	return (node) => {
		if (prefersReducedMotion.current) return;
		const bounds = node.getBoundingClientRect();
		if (bounds.top < window.innerHeight) return;
		node.dataset.reveal = 'pending';
		node.style.setProperty('--reveal-delay', `${delay}ms`);
		const observer = new IntersectionObserver(
			([entry]) => {
				if (!entry.isIntersecting) return;
				node.dataset.reveal = 'shown';
				observer.disconnect();
			},
			{ rootMargin: '0px 0px -10% 0px' }
		);
		observer.observe(node);
		return () => observer.disconnect();
	};
}

/** A selection highlight that glides between items instead of jumping, like the launcher's. */
export class SlideIndicator {
	#top = new Tween(0, { duration: structureDuration, easing: cubicOut });
	#height = new Tween(0, { duration: structureDuration, easing: cubicOut });
	visible = $state(false);

	get top() {
		return this.#top.current;
	}

	get height() {
		return this.#height.current;
	}

	move(target: HTMLElement | null | undefined) {
		if (!target) {
			this.visible = false;
			return;
		}
		const instant = !this.visible || prefersReducedMotion.current;
		const options = instant ? { duration: 0 } : undefined;
		void this.#top.set(target.offsetTop, options);
		void this.#height.set(target.offsetHeight, options);
		this.visible = true;
	}
}
