<script lang="ts">
	import * as Card from '$lib/components/ui/card';
	import type { PageData } from './$types';

	let { data }: { data: PageData } = $props();

	const TEAM_STATUS_LABEL: Record<string, string> = {
		pending: 'Pending approval',
		active: 'Active',
		withdrawn: 'Withdrawn',
		rejected: 'Rejected'
	};
</script>

<div class="mx-auto max-w-2xl">
	<h1 class="mb-6 text-2xl font-bold">My Team</h1>

	{#if !data.team}
		<Card.Root>
			<Card.Header>
				<Card.Title>No team yet</Card.Title>
				<Card.Description>
					Your registration is on file but no team record exists. This shouldn't happen —
					please contact RCOE.
				</Card.Description>
			</Card.Header>
		</Card.Root>
	{:else}
		<Card.Root>
			<Card.Header>
				<Card.Title>{data.team.name || 'Unnamed team'}</Card.Title>
				<Card.Description>
					{data.team.expand?.school?.name ?? '—'}
					{#if data.team.expand?.tournament}
						· {data.team.expand.tournament.name}
					{/if}
				</Card.Description>
			</Card.Header>
			<Card.Content class="grid gap-3 text-sm">
				<div class="flex items-center justify-between">
					<span class="text-muted-foreground">Status</span>
					<span class="font-medium">
						{TEAM_STATUS_LABEL[data.team.status] ?? data.team.status}
					</span>
				</div>
				{#if data.team.expand?.school?.nickname}
					<div class="flex items-center justify-between">
						<span class="text-muted-foreground">School nickname</span>
						<span>{data.team.expand.school.nickname}</span>
					</div>
				{/if}
				{#if data.team.team_number != null && data.team.team_number !== 0}
					<div class="flex items-center justify-between">
						<span class="text-muted-foreground">Team number</span>
						<span>{data.team.team_number}</span>
					</div>
				{/if}
			</Card.Content>
		</Card.Root>
	{/if}
</div>
