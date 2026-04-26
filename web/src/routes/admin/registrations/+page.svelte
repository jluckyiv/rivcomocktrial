<script lang="ts">
	import { enhance } from '$app/forms';
	import { Button } from '$lib/components/ui/button';
	import * as Table from '$lib/components/ui/table';
	import type { ActionData, PageData } from './$types';

	let { data, form }: { data: PageData; form: ActionData } = $props();

	const TABS = [
		{ key: 'pending', label: 'Pending' },
		{ key: 'approved', label: 'Approved' },
		{ key: 'rejected', label: 'Rejected' }
	] as const;

	function formatDate(iso: string) {
		if (!iso) return '';
		return new Date(iso).toLocaleDateString(undefined, {
			year: 'numeric',
			month: 'short',
			day: 'numeric'
		});
	}
</script>

<div class="max-w-5xl">
	<div class="mb-6 flex items-center justify-between">
		<h1 class="text-xl font-semibold">Registrations</h1>
	</div>

	<div class="mb-4 flex gap-1 border-b border-border">
		{#each TABS as tab (tab.key)}
			<a
				href="?status={tab.key}"
				class="-mb-px border-b-2 px-3 py-2 text-sm {data.status === tab.key
					? 'border-foreground text-foreground'
					: 'border-transparent text-muted-foreground hover:text-foreground'}"
			>
				{tab.label}
			</a>
		{/each}
	</div>

	{#if form?.error}
		<p class="mb-4 text-sm text-destructive">{form.error}</p>
	{/if}

	{#if data.coaches.length === 0}
		<p class="py-8 text-center text-sm text-muted-foreground">
			No {data.status} registrations.
		</p>
	{:else}
		<Table.Root>
			<Table.Header>
				<Table.Row>
					<Table.Head>Coach</Table.Head>
					<Table.Head>Email</Table.Head>
					<Table.Head>Team</Table.Head>
					<Table.Head>School</Table.Head>
					<Table.Head class="w-28">Submitted</Table.Head>
					<Table.Head class="w-44 text-right">Actions</Table.Head>
				</Table.Row>
			</Table.Header>
			<Table.Body>
				{#each data.coaches as coach (coach.id)}
					<Table.Row>
						<Table.Cell class="font-medium">{coach.name || '—'}</Table.Cell>
						<Table.Cell class="text-muted-foreground">{coach.email}</Table.Cell>
						<Table.Cell>{coach.team_name || '—'}</Table.Cell>
						<Table.Cell class="text-muted-foreground">
							{coach.expand?.school?.name ?? '—'}
						</Table.Cell>
						<Table.Cell class="text-xs text-muted-foreground">
							{formatDate(coach.created)}
						</Table.Cell>
						<Table.Cell class="text-right">
							<div class="inline-flex justify-end gap-2">
								{#if data.status !== 'approved'}
									<form method="POST" action="?/setStatus" use:enhance>
										<input type="hidden" name="id" value={coach.id} />
										<input type="hidden" name="status" value="approved" />
										<Button
											type="submit"
											size="sm"
											class="bg-emerald-600 text-white hover:bg-emerald-700 dark:bg-emerald-700 dark:hover:bg-emerald-600"
										>
											Approve
										</Button>
									</form>
								{/if}
								{#if data.status !== 'rejected'}
									<form method="POST" action="?/setStatus" use:enhance>
										<input type="hidden" name="id" value={coach.id} />
										<input type="hidden" name="status" value="rejected" />
										<Button type="submit" size="sm" variant="destructive">Reject</Button>
									</form>
								{/if}
							</div>
						</Table.Cell>
					</Table.Row>
				{/each}
			</Table.Body>
		</Table.Root>
	{/if}
</div>
