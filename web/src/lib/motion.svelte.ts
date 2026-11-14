import { cubicOut } from 'svelte/easing';
import { prefersReducedMotion, Tween } from 'svelte/motion';

/** Matches the launcher's structural motion: a short rise with a soft settle. */
export const structureDuration = 380;

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
