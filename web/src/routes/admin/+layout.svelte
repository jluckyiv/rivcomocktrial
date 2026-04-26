<script lang="ts">
	import NavBar from '$lib/components/NavBar.svelte';

	let { data, children } = $props();

	const links = [
		{ href: '/admin/tournaments', label: 'Tournaments' },
		{ href: '/admin/teams', label: 'Teams' },
		{ href: '/admin/districts', label: 'Districts' },
		{ href: '/admin/schools', label: 'Schools' },
		{ href: '/admin/registrations', label: 'Registrations' },
		{ href: '/admin/superusers', label: 'Superusers' }
	];
</script>

<div class="min-h-screen">
	<NavBar title="Mock Trial Admin" {links} userEmail={data.userEmail} />
	<main class="px-6 py-8">
		{@render children()}
	</main>
</div>
