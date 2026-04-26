<script lang="ts">
	import { enhance } from '$app/forms';
	import { Button } from '$lib/components/ui/button';
	import { Input } from '$lib/components/ui/input';
	import * as Table from '$lib/components/ui/table';
	import type { ActionData, PageData } from './$types';

	let { data, form }: { data: PageData; form: ActionData } = $props();

	let editingId = $state<string | null>(null);
	let editName = $state('');
	let confirmDeleteId = $state<string | null>(null);

	function startEdit(id: string, name: string) {
		editingId = id;
		editName = name;
		confirmDeleteId = null;
	}

	function cancelEdit() {
		editingId = null;
	}
</script>

<div class="max-w-2xl">
	<div class="mb-6 flex items-center justify-between">
		<h1 class="text-xl font-semibold">Districts</h1>
	</div>

	{#if form?.error}
		<p class="text-destructive mb-4 text-sm">{form.error}</p>
	{/if}

	<Table.Root>
		<Table.Header>
			<Table.Row>
				<Table.Head>Name</Table.Head>
				<Table.Head class="w-24 text-right">Schools</Table.Head>
				<Table.Head class="w-40"></Table.Head>
			</Table.Row>
		</Table.Header>
		<Table.Body>
			{#each data.districts as district (district.id)}
				<Table.Row>
					{#if editingId === district.id}
						<Table.Cell colspan={3}>
							<form
								method="POST"
								action="?/update"
								class="flex items-center gap-2"
								use:enhance={() => () => { editingId = null; }}
							>
								<input type="hidden" name="id" value={district.id} />
								<Input
									name="name"
									bind:value={editName}
									class="h-8 max-w-sm"
									autofocus
								/>
								<Button type="submit" size="sm">Save</Button>
								<Button type="button" variant="ghost" size="sm" onclick={cancelEdit}>
									Cancel
								</Button>
							</form>
						</Table.Cell>
					{:else if confirmDeleteId === district.id}
						<Table.Cell class="text-muted-foreground" colspan={2}>
							Delete <span class="text-foreground font-medium">{district.name}</span>
							and all its schools?
						</Table.Cell>
						<Table.Cell class="text-right">
							<form method="POST" action="?/delete" class="inline" use:enhance>
								<input type="hidden" name="id" value={district.id} />
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
						<Table.Cell>{district.name}</Table.Cell>
						<Table.Cell class="text-muted-foreground text-right">
							{data.schoolCountByDistrict[district.id] ?? 0}
						</Table.Cell>
						<Table.Cell class="text-right">
							<Button
								variant="ghost"
								size="sm"
								onclick={() => startEdit(district.id, district.name)}
							>
								Edit
							</Button>
							<Button
								variant="ghost"
								size="sm"
								onclick={() => {
									confirmDeleteId = district.id;
									editingId = null;
								}}
							>
								Delete
							</Button>
						</Table.Cell>
					{/if}
				</Table.Row>
			{/each}

			<Table.Row>
				<Table.Cell colspan={3} class="pt-4">
					<form method="POST" action="?/create" class="flex items-center gap-2" use:enhance>
						<Input name="name" placeholder="New district name" class="h-8 max-w-sm" />
						<Button type="submit" size="sm" variant="outline">Add district</Button>
					</form>
				</Table.Cell>
			</Table.Row>
		</Table.Body>
	</Table.Root>
</div>
