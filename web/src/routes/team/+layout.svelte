<script lang="ts">
	let { children } = $props();
</script>

<div class="min-h-screen">
	<header class="bg-background border-b px-6 py-3">
		<nav class="flex items-center gap-6">
			<span class="font-semibold">Mock Trial</span>
			<a href="/team" class="text-muted-foreground hover:text-foreground text-sm">
				My team
			</a>
		</nav>
	</header>
	<main class="px-6 py-8">
		{@render children()}
	</main>
</div>
