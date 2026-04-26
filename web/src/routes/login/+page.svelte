<script lang="ts">
	import { enhance } from '$app/forms';
	import { Button } from '$lib/components/ui/button';
	import { Input } from '$lib/components/ui/input';
	import { Label } from '$lib/components/ui/label';
	import * as Card from '$lib/components/ui/card';
	import type { ActionData, PageData } from './$types';

	let { data, form }: { data: PageData; form: ActionData } = $props();

	let submitting = $state(false);
</script>

<div class="mx-auto max-w-sm px-4 py-16">
	<Card.Root>
		<Card.Header>
			<Card.Title>Sign in</Card.Title>
		</Card.Header>
		<Card.Content>
			{#if form?.error}
				<p class="text-destructive mb-4 text-sm">{form.error}</p>
			{/if}

			<form
				method="POST"
				action="?/password"
				use:enhance={() => {
					submitting = true;
					return async ({ update }) => {
						submitting = false;
						update();
					};
				}}
				class="grid gap-4"
			>
				<input type="hidden" name="next" value={data.next} />
				<div class="grid gap-1.5">
					<Label for="email">Email</Label>
					<Input
						id="email"
						name="email"
						type="email"
						autocomplete="email"
						autofocus
						required
					/>
				</div>
				<div class="grid gap-1.5">
					<Label for="password">Password</Label>
					<Input
						id="password"
						name="password"
						type="password"
						autocomplete="current-password"
						required
					/>
				</div>
				<Button type="submit" class="w-full" disabled={submitting}>
					{submitting ? 'Signing in…' : 'Sign in'}
				</Button>
			</form>
		</Card.Content>
	</Card.Root>

	<p class="text-muted-foreground mt-4 text-center text-sm">
		Registering a team? <a href="/register" class="underline">Register here</a>
	</p>
</div>
