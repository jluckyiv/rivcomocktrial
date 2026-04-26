<script lang="ts">
	import type { PageData } from './$types';
	let { data }: { data: PageData } = $props();
</script>

<h1>Riverside County Mock Trial</h1>

<h2>Schools</h2>
{#if data.schools.length === 0}
	<p>No schools found.</p>
{:else}
	<ul>
		{#each data.schools as school}
			<li>{school.name}</li>
		{/each}
	</ul>
{/if}
