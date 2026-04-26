<script lang="ts">
	import { enhance } from '$app/forms';
	import { Button } from '$lib/components/ui/button';
	import { Input } from '$lib/components/ui/input';
	import * as Table from '$lib/components/ui/table';
	import * as Select from '$lib/components/ui/select';
	import type { ActionData, PageData } from './$types';

	let { data, form }: { data: PageData; form: ActionData } = $props();

	let editingId = $state<string | null>(null);
	let editName = $state('');
	let editNickname = $state('');
	let editDistrictId = $state('');
	let confirmDeleteId = $state<string | null>(null);
	let filter = $state('');

	const visibleSchools = $derived(
		filter.trim() === ''
			? data.schools
			: data.schools.filter(
					(s) =>
						s.name.toLowerCase().includes(filter.toLowerCase()) ||
						(s.nickname ?? '').toLowerCase().includes(filter.toLowerCase()) ||
						(s.expand?.district?.name ?? '').toLowerCase().includes(filter.toLowerCase())
				)
	);

	const editingDistrict = $derived(data.districts.find((d) => d.id === editDistrictId));

	function startEdit(id: string, name: string, nickname: string, districtId: string) {
		editingId = id;
		editName = name;
		editNickname = nickname;
		editDistrictId = districtId;
		confirmDeleteId = null;
	}

	function cancelEdit() {
		editingId = null;
	}

	// New school form state
	let newDistrictId = $state('');
	const newDistrict = $derived(data.districts.find((d) => d.id === newDistrictId));
</script>

<div class="max-w-4xl">
	<div class="mb-6 flex items-center justify-between">
		<h1 class="text-xl font-semibold">Schools</h1>
		<Input
			bind:value={filter}
			placeholder="Filter by name, nickname, or district…"
			class="h-8 w-72"
		/>
	</div>

	{#if form?.error}
		<p class="mb-4 text-sm text-destructive">{form.error}</p>
	{/if}

	<Table.Root>
		<Table.Header>
			<Table.Row>
				<Table.Head>Name</Table.Head>
				<Table.Head class="w-40">Nickname</Table.Head>
				<Table.Head class="w-56">District</Table.Head>
				<Table.Head class="w-36"></Table.Head>
			</Table.Row>
		</Table.Header>
		<Table.Body>
			{#each visibleSchools as school (school.id)}
				{@const districtName = school.expand?.district?.name ?? '—'}
				<Table.Row>
					{#if editingId === school.id}
						<Table.Cell colspan={4}>
							<form
								method="POST"
								action="?/update"
								class="flex flex-wrap items-center gap-2"
								use:enhance={() => () => {
									editingId = null;
								}}
							>
								<input type="hidden" name="id" value={school.id} />
								<Input
									name="name"
									bind:value={editName}
									class="h-8 w-56"
									placeholder="School name"
									autofocus
								/>
								<Input
									name="nickname"
									bind:value={editNickname}
									class="h-8 w-32"
									placeholder="Nickname"
								/>
								<Select.Root type="single" name="district" bind:value={editDistrictId}>
									<Select.Trigger class="h-8 w-52">
										<span
											data-slot="select-value"
											class={editingDistrict ? '' : 'text-muted-foreground'}
										>
											{editingDistrict?.name ?? 'Select district'}
										</span>
									</Select.Trigger>
									<Select.Content>
										{#each data.districts as d (d.id)}
											<Select.Item value={d.id}>{d.name}</Select.Item>
										{/each}
									</Select.Content>
								</Select.Root>
								<Button type="submit" size="sm">Save</Button>
								<Button type="button" variant="ghost" size="sm" onclick={cancelEdit}>Cancel</Button>
							</form>
						</Table.Cell>
					{:else if confirmDeleteId === school.id}
						<Table.Cell class="text-muted-foreground" colspan={3}>
							Delete <span class="font-medium text-foreground">{school.name}</span>?
						</Table.Cell>
						<Table.Cell class="text-right">
							<form method="POST" action="?/delete" class="inline" use:enhance>
								<input type="hidden" name="id" value={school.id} />
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
						<Table.Cell>{school.name}</Table.Cell>
						<Table.Cell class="text-muted-foreground">{school.nickname || '—'}</Table.Cell>
						<Table.Cell class="text-muted-foreground">{districtName}</Table.Cell>
						<Table.Cell class="text-right">
							<Button
								variant="ghost"
								size="sm"
								onclick={() =>
									startEdit(school.id, school.name, school.nickname ?? '', school.district ?? '')}
							>
								Edit
							</Button>
							<Button
								variant="ghost"
								size="sm"
								onclick={() => {
									confirmDeleteId = school.id;
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
				<Table.Cell colspan={4} class="pt-4">
					<form
						method="POST"
						action="?/create"
						class="flex flex-wrap items-center gap-2"
						use:enhance
					>
						<Input name="name" placeholder="School name" class="h-8 w-56" />
						<Input name="nickname" placeholder="Nickname" class="h-8 w-32" />
						<Select.Root type="single" name="district" bind:value={newDistrictId}>
							<Select.Trigger class="h-8 w-52">
								<span data-slot="select-value" class={newDistrict ? '' : 'text-muted-foreground'}>
									{newDistrict?.name ?? 'Select district'}
								</span>
							</Select.Trigger>
							<Select.Content>
								{#each data.districts as d (d.id)}
									<Select.Item value={d.id}>{d.name}</Select.Item>
								{/each}
							</Select.Content>
						</Select.Root>
						<Button type="submit" size="sm" variant="outline">Add school</Button>
					</form>
				</Table.Cell>
			</Table.Row>
		</Table.Body>
	</Table.Root>
</div>
