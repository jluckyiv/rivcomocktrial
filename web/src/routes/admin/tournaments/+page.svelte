<script lang="ts">
	import { enhance } from '$app/forms';
	import { Button } from '$lib/components/ui/button';
	import { Input } from '$lib/components/ui/input';
	import * as Table from '$lib/components/ui/table';
	import type { ActionData, PageData } from './$types';

	let { data, form }: { data: PageData; form: ActionData } = $props();

	let confirmDeleteId = $state<string | null>(null);

	const STATUSES = ['draft', 'registration', 'active', 'completed'] as const;

	const STATUS_DOT: Record<string, string> = {
		draft: 'bg-zinc-400',
		registration: 'bg-emerald-500',
		active: 'bg-sky-500',
		completed: 'bg-zinc-500'
	};
</script>

<div class="max-w-5xl">
	<div class="mb-6 flex items-center justify-between">
		<h1 class="text-xl font-semibold">Tournaments</h1>
	</div>

	<p class="mb-4 text-sm text-muted-foreground">
		Set a tournament to <code>registration</code> to open coach signup. Only one tournament should be
		in registration status at a time.
	</p>

	{#if form?.error}
		<p class="mb-4 text-sm text-destructive">{form.error}</p>
	{/if}

	<Table.Root>
		<Table.Header>
			<Table.Row>
				<Table.Head>Name</Table.Head>
				<Table.Head class="w-20">Year</Table.Head>
				<Table.Head class="w-20 text-center">Prelim</Table.Head>
				<Table.Head class="w-20 text-center">Elim</Table.Head>
				<Table.Head class="w-44">Status</Table.Head>
				<Table.Head class="w-24"></Table.Head>
			</Table.Row>
		</Table.Header>
		<Table.Body>
			{#each data.tournaments as t (t.id)}
				<Table.Row>
					{#if confirmDeleteId === t.id}
						<Table.Cell class="text-muted-foreground" colspan={5}>
							Delete <span class="font-medium text-foreground">{t.name}</span>? This removes all
							related teams, rounds, and trials.
						</Table.Cell>
						<Table.Cell class="text-right">
							<form method="POST" action="?/delete" class="inline" use:enhance>
								<input type="hidden" name="id" value={t.id} />
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
						<Table.Cell class="font-medium">{t.name}</Table.Cell>
						<Table.Cell class="text-muted-foreground">{t.year}</Table.Cell>
						<Table.Cell class="text-center text-muted-foreground">
							{t.num_preliminary_rounds}
						</Table.Cell>
						<Table.Cell class="text-center text-muted-foreground">
							{t.num_elimination_rounds}
						</Table.Cell>
						<Table.Cell>
							<form method="POST" action="?/setStatus" class="flex items-center gap-2" use:enhance>
								<input type="hidden" name="id" value={t.id} />
								<span
									class="inline-block h-2 w-2 shrink-0 rounded-full {STATUS_DOT[t.status] ??
										'bg-zinc-400'}"
									aria-hidden="true"
								></span>
								<select
									name="status"
									value={t.status}
									onchange={(e) =>
										(e.currentTarget.form as HTMLFormElement | null)?.requestSubmit()}
									class="h-8 rounded-md border border-input bg-background px-2 text-sm capitalize"
								>
									{#each STATUSES as s (s)}
										<option value={s}>{s}</option>
									{/each}
								</select>
							</form>
						</Table.Cell>
						<Table.Cell class="text-right">
							<Button variant="ghost" size="sm" onclick={() => (confirmDeleteId = t.id)}>
								Delete
							</Button>
						</Table.Cell>
					{/if}
				</Table.Row>
			{/each}

			<Table.Row>
				<Table.Cell colspan={6} class="pt-6 pb-0 text-sm font-medium">Add tournament</Table.Cell>
			</Table.Row>
			<Table.Row>
				<Table.Cell>
					<form id="create-tournament" method="POST" action="?/create" use:enhance></form>
					<Input
						name="name"
						form="create-tournament"
						placeholder="Tournament name"
						class="h-8"
						required
					/>
				</Table.Cell>
				<Table.Cell>
					<Input
						name="year"
						form="create-tournament"
						type="number"
						class="h-8 w-28"
						value={new Date().getFullYear()}
						required
					/>
				</Table.Cell>
				<Table.Cell>
					<Input
						name="num_preliminary_rounds"
						form="create-tournament"
						type="number"
						min={0}
						class="h-8"
						value="4"
						required
					/>
				</Table.Cell>
				<Table.Cell>
					<Input
						name="num_elimination_rounds"
						form="create-tournament"
						type="number"
						min={0}
						class="h-8"
						value="3"
						required
					/>
				</Table.Cell>
				<Table.Cell></Table.Cell>
				<Table.Cell class="text-right">
					<Button type="submit" form="create-tournament" size="sm" variant="outline">Add</Button>
				</Table.Cell>
			</Table.Row>
		</Table.Body>
	</Table.Root>
</div>
