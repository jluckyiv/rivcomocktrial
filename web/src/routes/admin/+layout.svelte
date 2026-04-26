<script lang="ts">
	let { children } = $props();
</script>

<div class="min-h-screen">
	<header class="bg-background border-b px-6 py-3">
		<nav class="flex items-center gap-6">
			<span class="font-semibold">Mock Trial Admin</span>
			<a href="/admin/tournaments" class="text-muted-foreground hover:text-foreground text-sm">
				Tournaments
			</a>
			<a href="/admin/teams" class="text-muted-foreground hover:text-foreground text-sm">
				Teams
			</a>
			<a href="/admin/districts" class="text-muted-foreground hover:text-foreground text-sm">
				Districts
			</a>
			<a href="/admin/schools" class="text-muted-foreground hover:text-foreground text-sm">
				Schools
			</a>
			<a href="/admin/registrations" class="text-muted-foreground hover:text-foreground text-sm">
				Registrations
			</a>
			<a href="/admin/superusers" class="text-muted-foreground hover:text-foreground text-sm">
				Superusers
			</a>
		</nav>
	</header>
	<main class="px-6 py-8">
		{@render children()}
	</main>
</div>
