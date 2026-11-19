export interface Server {
	name: string;
	publisher: string;
}

/** Servers in the order the setup assistant lists them. */
export const servers: readonly Server[] = [
	{ name: 'Global', publisher: 'Yostar' },
	{ name: 'Japan', publisher: 'Yostar' },
	{ name: 'Korea', publisher: 'Yostar' },
	{ name: 'Taiwan', publisher: 'Gryphline' },
	{ name: 'China', publisher: 'Hypergryph' },
	{ name: 'China (Bilibili)', publisher: 'Hypergryph' }
];
