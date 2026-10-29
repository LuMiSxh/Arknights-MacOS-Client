<script lang="ts">
	import { resolve } from '$app/paths';
	import PageMetadata from '$lib/components/PageMetadata.svelte';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();
</script>

<PageMetadata
	title="Blog · Arknights Client"
	description="Project updates, survey results, and development notes for the Arknights Client."
	path="/blog/"
/>

<header class="content-header">
	<nav class="breadcrumbs" aria-label="Breadcrumb">
		<a href={resolve('/')}>Home</a>
		<span aria-hidden="true">/</span>
		<span aria-current="page">Blog</span>
	</nav>
	<div class="page-heading">
		<h1>Blog</h1>
		<p>Project updates, survey results, and development notes.</p>
	</div>
</header>

<section class="panel" aria-labelledby="blog-posts">
	<h2 class="panel-title" id="blog-posts">Posts</h2>
	{#if data.posts.length}
		<nav class="row-list" aria-label="Blog posts">
			{#each data.posts as post (post.route)}
				<a href={resolve(post.route)}>
					<span>
						<small
							><time datetime={post.date}>{post.date}</time
							>{#if post.draft}
								· Draft{/if}</small
						>
						<strong>{post.title}</strong>
						<small>{post.summary}</small>
					</span>
					<span class="chevron" aria-hidden="true">›</span>
				</a>
			{/each}
		</nav>
	{:else}
		<p>No posts yet.</p>
	{/if}
</section>
