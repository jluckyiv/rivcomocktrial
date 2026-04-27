<script lang="ts">
	import * as Table from '$lib/components/ui/table';
	import { canRunTournament } from '$lib/domain/registration';
	import type { PageData } from './$types';

	let { data }: { data: PageData } = $props();

	const readiness = $derived(canRunTournament(data.teams));

	const TEAM_STATUS_LABEL: Record<string, string> = {
		pending: 'Pending',
		active: 'Active',
		withdrawn: 'Withdrawn',
		rejected: 'Rejected'
	};

	const STATUS_DOT: Record<string, string> = {
		pending: 'bg-amber-500',
		active: 'bg-emerald-500',
		withdrawn: 'bg-zinc-400',
		rejected: 'bg-rose-500'
	};
</script>

<div class="max-w-5xl">
	<div class="mb-6 flex items-center justify-between">
		<h1 class="text-xl font-semibold">Teams</h1>
		{#if data.tournaments.length > 1}
			<form>
				<select
					name="tournament"
					value={data.selected?.id ?? ''}
					onchange={(e) =>
						(window.location.search = `?tournament=${(e.currentTarget as HTMLSelectElement).value}`)}
					class="h-8 rounded-md border border-input bg-background px-2 text-sm"
				>
					{#each data.tournaments as t (t.id)}
						<option value={t.id}>{t.name} ({t.status})</option>
					{/each}
				</select>
			</form>
		{/if}
	</div>

	{#if !data.selected}
		<p class="py-8 text-center text-sm text-muted-foreground">
			No tournaments yet. Create one in <a href="/admin/tournaments" class="underline"
				>Tournaments</a
			>.
		</p>
	{:else}
		<p class="mb-4 text-sm text-muted-foreground">
			{data.selected.name} ({data.selected.year}) — {data.selected.status}
		</p>

		{#if !readiness.ok}
			<div
				class="mb-4 rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-900 dark:border-amber-900 dark:bg-amber-950 dark:text-amber-200"
				role="status"
			>
				⚠️ {readiness.reason}
			</div>
		{:else}
			<div
				class="mb-4 rounded-md border border-emerald-200 bg-emerald-50 px-3 py-2 text-sm text-emerald-900 dark:border-emerald-900 dark:bg-emerald-950 dark:text-emerald-200"
				role="status"
			>
				✓ {readiness.activeCount} active teams — ready to run.
			</div>
		{/if}

		{#if data.teams.length === 0}
			<p class="py-8 text-center text-sm text-muted-foreground">No teams in this tournament yet.</p>
		{:else}
			<Table.Root>
				<Table.Header>
					<Table.Row>
						<Table.Head>Team</Table.Head>
						<Table.Head>School</Table.Head>
						<Table.Head>Coach</Table.Head>
						<Table.Head class="w-32">Status</Table.Head>
					</Table.Row>
				</Table.Header>
				<Table.Body>
					{#each data.teams as team (team.id)}
						<Table.Row>
							<Table.Cell class="font-medium">{team.name || '—'}</Table.Cell>
							<Table.Cell class="text-muted-foreground">
								{team.expand?.school?.name ?? '—'}
							</Table.Cell>
							<Table.Cell class="text-muted-foreground">
								{team.expand?.coaches?.map((c) => c.name || c.email).join(', ') || '—'}
							</Table.Cell>
							<Table.Cell>
								<span class="inline-flex items-center gap-2">
									<span
										class="inline-block h-2 w-2 shrink-0 rounded-full {STATUS_DOT[team.status] ??
											'bg-zinc-400'}"
										aria-hidden="true"
									></span>
									{TEAM_STATUS_LABEL[team.status] ?? team.status}
								</span>
							</Table.Cell>
						</Table.Row>
					{/each}
				</Table.Body>
			</Table.Root>
		{/if}
	{/if}
</div>
