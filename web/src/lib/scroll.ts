export interface ScrollBounds {
	top: number;
	bottom: number;
}

export function scrollDeltaFor(
	list: ScrollBounds,
	target: ScrollBounds
): number {
	if (target.bottom > list.bottom) return target.bottom - list.bottom;
	if (target.top < list.top) return target.top - list.top;
	return 0;
}
