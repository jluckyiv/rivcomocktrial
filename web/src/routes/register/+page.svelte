<script lang="ts">
	import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '$lib/components/ui/card';
</script>

<div class="mx-auto max-w-md px-4 py-16">
	<h1 class="mb-8 text-center text-2xl font-semibold">Register for Mock Trial</h1>

	<div class="grid gap-4">
		<a href="/register/teacher-coach">
			<Card class="cursor-pointer transition-colors hover:bg-accent">
				<CardHeader>
					<CardTitle>Teacher Coach</CardTitle>
					<CardDescription>
						Register your school's team and manage students throughout the season.
					</CardDescription>
				</CardHeader>
				<CardContent>
					<p class="text-muted-foreground text-sm">
						Your registration will be reviewed by RCOE before you can log in.
					</p>
				</CardContent>
			</Card>
		</a>
	</div>
</div>
