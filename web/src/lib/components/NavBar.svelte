<script lang="ts">
	import { Menu, X } from '@lucide/svelte';

	interface Link {
		href: string;
		label: string;
	}

	let { title, links, userEmail }: { title: string; links: Link[]; userEmail?: string } = $props();

	let mobileOpen = $state(false);
</script>

<header class="border-b bg-background">
	<div class="px-6 py-3">
		<div class="flex items-center justify-between">
			<span class="font-semibold">{title}</span>

			<nav class="hidden items-center gap-6 md:flex">
				{#each links as link (link.href)}
					<a href={link.href} class="text-sm text-muted-foreground hover:text-foreground">
						{link.label}
					</a>
				{/each}
				{#if userEmail}
					<form method="POST" action="/logout">
						<button
							type="submit"
							class="cursor-pointer text-sm text-muted-foreground hover:text-foreground"
						>
							Log out
						</button>
					</form>
				{/if}
			</nav>

			<button
				class="md:hidden"
				onclick={() => (mobileOpen = !mobileOpen)}
				aria-label="Toggle menu"
				aria-expanded={mobileOpen}
			>
				{#if mobileOpen}
					<X size={20} />
				{:else}
					<Menu size={20} />
				{/if}
			</button>
		</div>

		{#if mobileOpen}
			<nav class="mt-3 flex flex-col gap-3 pb-2 md:hidden">
				{#each links as link (link.href)}
					<a
						href={link.href}
						class="text-sm text-muted-foreground hover:text-foreground"
						onclick={() => (mobileOpen = false)}
					>
						{link.label}
					</a>
				{/each}
				{#if userEmail}
					<form method="POST" action="/logout">
						<button
							type="submit"
							class="cursor-pointer text-left text-sm text-muted-foreground hover:text-foreground"
						>
							Log out
						</button>
					</form>
				{/if}
			</nav>
		{/if}
	</div>
</header>
