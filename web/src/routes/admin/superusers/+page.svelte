<script lang="ts">
	import { enhance } from '$app/forms';
	import { Button } from '$lib/components/ui/button';
	import { Input } from '$lib/components/ui/input';
	import * as Table from '$lib/components/ui/table';
	import type { ActionData, PageData } from './$types';

	let { data, form }: { data: PageData; form: ActionData } = $props();

	let confirmDeleteId = $state<string | null>(null);
</script>

<div class="max-w-4xl">
	<div class="mb-6 flex items-center justify-between">
		<h1 class="text-xl font-semibold">Superusers</h1>
	</div>

	<p class="mb-4 text-sm text-muted-foreground">
		Superusers are RCOE administrators with full access. The primary contact's email is shown on
		public registration pages.
	</p>

	{#if form?.error}
		<p class="mb-4 text-sm text-destructive">{form.error}</p>
	{/if}

	<Table.Root>
		<Table.Header>
			<Table.Row>
				<Table.Head>Email</Table.Head>
				<Table.Head class="w-48">Name</Table.Head>
				<Table.Head class="w-40 text-center">Primary contact</Table.Head>
				<Table.Head class="w-28"></Table.Head>
			</Table.Row>
		</Table.Header>
		<Table.Body>
			{#each data.superusers as su (su.id)}
				<Table.Row>
					{#if confirmDeleteId === su.id}
						<Table.Cell class="text-muted-foreground" colspan={3}>
							Delete <span class="font-medium text-foreground">{su.email}</span>?
						</Table.Cell>
						<Table.Cell class="text-right">
							<form method="POST" action="?/delete" class="inline" use:enhance>
								<input type="hidden" name="id" value={su.id} />
								<Button type="submit" variant="destructive" size="sm">Delete</Button>
							</form>
							<Button
								type="button"
								variant="ghost"
								size="sm"
								onclick={() => (confirmDeleteId = null)}
							>
								Cancel
							</Button>
						</Table.Cell>
					{:else}
						<Table.Cell>{su.email}</Table.Cell>
						<Table.Cell class="text-muted-foreground">{su.name || '—'}</Table.Cell>
						<Table.Cell class="text-center">
							<form method="POST" action="?/setPrimary" class="inline" use:enhance>
								<input type="hidden" name="id" value={su.id} />
								<input
									type="radio"
									name="primary"
									checked={su.is_primary_contact}
									onchange={(e) =>
										(e.currentTarget.form as HTMLFormElement | null)?.requestSubmit()}
								/>
							</form>
						</Table.Cell>
						<Table.Cell class="text-right">
							{#if su.id === data.currentUserId}
								<span class="text-xs text-muted-foreground">you</span>
							{:else}
								<Button variant="ghost" size="sm" onclick={() => (confirmDeleteId = su.id)}>
									Delete
								</Button>
							{/if}
						</Table.Cell>
					{/if}
				</Table.Row>
			{/each}

			<Table.Row>
				<Table.Cell colspan={4} class="pt-4">
					<form
						method="POST"
						action="?/create"
						class="flex flex-wrap items-center gap-2"
						use:enhance
					>
						<Input
							name="email"
							type="email"
							placeholder="email@example.com"
							class="h-8 w-64"
							required
						/>
						<Input name="name" placeholder="Name (optional)" class="h-8 w-48" />
						<Input
							name="password"
							type="password"
							placeholder="Initial password"
							class="h-8 w-44"
							minlength={10}
							required
						/>
						<Button type="submit" size="sm" variant="outline">Add superuser</Button>
					</form>
				</Table.Cell>
			</Table.Row>
		</Table.Body>
	</Table.Root>
</div>
