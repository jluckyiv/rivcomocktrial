<script lang="ts">
	import * as Card from '$lib/components/ui/card';
	import type { PageData } from './$types';

	let { data }: { data: PageData } = $props();
</script>

<div class="mx-auto max-w-md px-4 py-16">
	<Card.Root>
		<Card.Header>
			<Card.Title>Registration submitted</Card.Title>
		</Card.Header>
		<Card.Content class="grid gap-3">
			<p>
				Your registration is pending review by RCOE. You will receive an email when your account is
				approved.
			</p>
			<p class="text-sm text-muted-foreground">
				Questions? Contact RCOE at
				<a href="mailto:{data.contact.email}" class="underline">{data.contact.email}</a>.
			</p>
		</Card.Content>
	</Card.Root>
</div>
