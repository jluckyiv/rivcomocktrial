<script lang="ts">
	import * as Card from '$lib/components/ui/card';
</script>

<h1 class="mb-6 text-2xl font-bold">Admin Dashboard</h1>

<div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
	<a href="/admin/tournaments">
		<Card.Root class="transition-colors hover:bg-muted/50">
			<Card.Header>
				<Card.Title>Tournaments</Card.Title>
				<Card.Description>Create tournaments and open registration</Card.Description>
			</Card.Header>
		</Card.Root>
	</a>

	<a href="/admin/teams">
		<Card.Root class="transition-colors hover:bg-muted/50">
			<Card.Header>
				<Card.Title>Teams</Card.Title>
				<Card.Description>Approved teams per tournament</Card.Description>
			</Card.Header>
		</Card.Root>
	</a>

	<a href="/admin/districts">
		<Card.Root class="transition-colors hover:bg-muted/50">
			<Card.Header>
				<Card.Title>Districts</Card.Title>
				<Card.Description>Manage Riverside County school districts</Card.Description>
			</Card.Header>
		</Card.Root>
	</a>

	<a href="/admin/schools">
		<Card.Root class="transition-colors hover:bg-muted/50">
			<Card.Header>
				<Card.Title>Schools</Card.Title>
				<Card.Description>Manage participating schools</Card.Description>
			</Card.Header>
		</Card.Root>
	</a>

	<a href="/admin/registrations">
		<Card.Root class="transition-colors hover:bg-muted/50">
			<Card.Header>
				<Card.Title>Registrations</Card.Title>
				<Card.Description>Review and approve coach registrations</Card.Description>
			</Card.Header>
		</Card.Root>
	</a>

	<a href="/admin/superusers">
		<Card.Root class="transition-colors hover:bg-muted/50">
			<Card.Header>
				<Card.Title>Superusers</Card.Title>
				<Card.Description>Manage RCOE admins and primary contact</Card.Description>
			</Card.Header>
		</Card.Root>
	</a>
</div>
