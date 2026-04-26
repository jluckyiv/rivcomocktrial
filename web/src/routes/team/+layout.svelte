<script lang="ts">
	import NavBar from '$lib/components/NavBar.svelte';

	let { data, children } = $props();

	const links = [{ href: '/team', label: 'My team' }];
</script>

<div class="min-h-screen">
	<NavBar title="Mock Trial" {links} userEmail={data.user?.email} />
	<main class="px-6 py-8">
		{@render children()}
	</main>
</div>
