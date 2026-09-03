import { basename, resolve } from 'node:path';

// SvelteKit bundles server modules into `.svelte-kit/output`; the working directory
// remains anchored at either the repository or its web package during builds.
export const repositoryRoot =
	basename(process.cwd()) === 'web'
		? resolve(process.cwd(), '..')
		: process.cwd();
export const docsRoot = resolve(repositoryRoot, 'docs');
export const changelogPath = resolve(repositoryRoot, 'CHANGELOG.md');
export const supportCodeRegistryPath = resolve(
	docsRoot,
	'help/errors/registry.json'
);
