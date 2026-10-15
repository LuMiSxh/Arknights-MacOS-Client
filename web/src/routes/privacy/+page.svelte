<script lang="ts">
	import PageMetadata from '$lib/components/PageMetadata.svelte';
	import { repositoryUrl } from '$lib/site.js';
</script>

<PageMetadata
	title="Privacy notice · Arknights Client"
	description="What data this website and the Arknights Client app process, and where it goes."
	path="/privacy/"
/>

<article class="privacy-page">
	<p class="eyebrow">Last updated 2026-10-09</p>
	<h1>Privacy notice</h1>
	<p>
		This notice covers the Arknights Client website and the Arknights Client
		app. The author publishes both as an unofficial community project.
	</p>

	<h2>Controller</h2>
	<p>
		LuMiSxh, a private individual, is responsible for this website and the
		app. Contact the author through the
		<a href={`${repositoryUrl}/issues`}>GitHub issue tracker</a>.
	</p>

	<h2>Website</h2>
	<p>
		The website is a static site hosted on GitHub Pages. It does not set
		cookies. It does not use local storage, analytics, or trackers. It loads
		no external fonts, scripts, or content delivery networks.
	</p>
	<p>
		GitHub processes visitor IP addresses and request data in its server
		logs. GitHub may transfer this data to the United States. Read the
		<a
			href="https://docs.github.com/en/site-policy/privacy-policies/github-privacy-statement"
			>GitHub Privacy Statement</a
		>.
	</p>

	<h2>App</h2>
	<p>
		The app has no analytics and no telemetry. The author runs no server
		that receives app data. Settings, logs, and game files stay on your Mac.
	</p>
	<p>
		The app connects to the hosts below when you use the matching feature.
		Each host receives your IP address and request data under its own
		privacy policy.
	</p>
	<ul>
		<li>
			<code>api-launcher-en.yo-star.com</code>,
			<code>api-launcher-jp.yo-star.com</code>,
			<code>api-launcher-kr.yo-star.com</code>: game metadata for Global,
			Japan, and Korea.
		</li>
		<li>
			<code>launcher-pkg-ark-*.yo-star.com</code>: game package downloads
			for Yostar regions.
		</li>
		<li>
			<code>launcher.gryphline.com</code>: game metadata for Taiwan
			(Canary).
		</li>
		<li>
			<code>launcher.hypergryph.com</code>: game metadata for China and
			China (Bilibili).
		</li>
		<li>
			<code>webusstatic.yo-star.com</code>: launcher logos and artwork.
		</li>
		<li>
			<code>www.arknights.global</code>: wallpaper gallery for artwork
			presets.
		</li>
		<li>
			<code>cdn.jsdelivr.net</code>: character data and avatar images for
			artwork presets.
		</li>
		<li>
			<code>raw.githubusercontent.com</code>: fallback avatar images and
			the wallpaper tag list for artwork presets.
		</li>
		<li><code>api.github.com</code>: launcher announcements.</li>
		<li>
			<code>github.com</code>: update checks and the Report an issue link.
		</li>
		<li>
			<code>www.youtube.com</code>: background music in the embedded
			player. Google's privacy policy applies to YouTube.
		</li>
	</ul>
	<p>
		Links that you open, such as publisher support pages and the donation
		page, open in your browser. Those sites apply their own policies.
	</p>

	<h2>Issue reports</h2>
	<p>
		The Report an issue link opens a prefilled GitHub issue. It includes the
		app version, macOS version, chip, memory, and, where known, the region,
		operation name, and a support code. Log files are not included. You
		decide whether to submit the issue.
	</p>

	<h2>Your rights</h2>
	<ul>
		<li>
			You can request access to, correction of, or deletion of your
			personal data. You can object to its processing.
		</li>
		<li>You can complain to a data protection supervisory authority.</li>
		<li>
			The author holds no personal data about app users. For data held by
			GitHub, YouTube, or a publisher, contact that party.
		</li>
	</ul>
</article>

<style>
	.privacy-page {
		max-width: 42rem;
		margin: clamp(4rem, 12vw, 8rem) auto;
		padding-inline: var(--site-space-4);
	}

	.privacy-page h2 {
		margin-top: var(--site-space-6);
	}

	.privacy-page ul {
		padding-left: var(--site-space-5);
		list-style: disc;
	}

	.privacy-page li {
		margin-block: var(--site-space-2);
	}
</style>
