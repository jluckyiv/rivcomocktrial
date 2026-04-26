<script lang="ts">
	import { enhance } from '$app/forms';
	import { Button } from '$lib/components/ui/button';
	import { Input } from '$lib/components/ui/input';
	import { Label } from '$lib/components/ui/label';
	import * as Card from '$lib/components/ui/card';
	import * as Select from '$lib/components/ui/select';
	import type { ActionData, PageData } from './$types';

	let { data, form }: { data: PageData; form: ActionData } = $props();

	let submitting = $state(false);
	let schoolId = $state('');
	let schoolSearch = $state('');
	let teamName = $state('');
	let prevAutoName = $state('');

	const selectedSchool = $derived(data.schools.find((s) => s.id === schoolId));

	const filteredDistricts = $derived(
		schoolSearch.trim() === ''
			? data.districts
			: data.districts
					.map((d) => ({
						...d,
						_schools: data.schools.filter(
							(s) =>
								s.district === d.id && s.name.toLowerCase().includes(schoolSearch.toLowerCase())
						)
					}))
					.filter((d) => d._schools.length > 0)
	);

	const schoolsFor = (districtId: string): typeof data.schools =>
		schoolSearch.trim() === ''
			? data.schools.filter((s) => s.district === districtId)
			: data.schools.filter(
					(s) =>
						s.district === districtId && s.name.toLowerCase().includes(schoolSearch.toLowerCase())
				);

	$effect(() => {
		schoolId = form?.values?.school ?? '';
	});

	$effect(() => {
		const restored = form?.values?.teamName ?? '';
		if (restored) {
			teamName = restored;
			prevAutoName = restored;
		}
	});

	$effect(() => {
		const school = data.schools.find((s) => s.id === schoolId);
		if (school && (teamName === '' || teamName === prevAutoName)) {
			teamName = school.name;
			prevAutoName = school.name;
		}
	});
</script>

{#if !data.tournament}
	<div class="mx-auto max-w-lg px-4 py-16">
		<Card.Root>
			<Card.Header>
				<Card.Title>Registration is closed</Card.Title>
				<Card.Description>
					There is no tournament currently accepting registrations. Please check back later or
					contact RCOE at
					<a href="mailto:{data.contact.email}" class="underline">{data.contact.email}</a>.
				</Card.Description>
			</Card.Header>
		</Card.Root>
	</div>
{:else}
	<div class="mx-auto max-w-lg px-4 py-16">
		<Card.Root>
			<Card.Header>
				<Card.Title>Teacher Coach Registration</Card.Title>
				<Card.Description>
					Register your team for {data.tournament.name}. RCOE will review your registration before
					you can log in.
				</Card.Description>
			</Card.Header>
			<Card.Content>
				<form
					method="POST"
					use:enhance={() => {
						submitting = true;
						return async ({ update }) => {
							submitting = false;
							update();
						};
					}}
					class="grid gap-5"
				>
					{#if form?.error}
						<p class="rounded-md bg-destructive/10 px-3 py-2 text-sm text-destructive">
							{form.error}
						</p>
					{/if}

					<div class="grid grid-cols-2 gap-3">
						<div class="grid gap-1.5">
							<Label for="first_name">First name</Label>
							<Input
								id="first_name"
								name="first_name"
								required
								value={form?.values?.firstName ?? ''}
							/>
						</div>
						<div class="grid gap-1.5">
							<Label for="last_name">Last name</Label>
							<Input
								id="last_name"
								name="last_name"
								required
								value={form?.values?.lastName ?? ''}
							/>
						</div>
					</div>

					<div class="grid gap-1.5">
						<Label for="email">Email address</Label>
						<Input
							id="email"
							name="email"
							type="email"
							required
							value={form?.values?.email ?? ''}
						/>
					</div>

					<div class="grid gap-1.5">
						<Label for="school">School</Label>
						<Select.Root type="single" name="school" bind:value={schoolId}>
							<Select.Trigger id="school">
								<span
									data-slot="select-value"
									class={selectedSchool ? '' : 'text-muted-foreground'}
								>
									{selectedSchool?.name ?? 'Select your school'}
								</span>
							</Select.Trigger>
							<Select.Content class="max-h-72">
								<div class="px-2 pt-1 pb-1">
									<input
										bind:value={schoolSearch}
										onkeydown={(e) => e.stopPropagation()}
										placeholder="Search schools…"
										class="w-full rounded border border-input bg-background px-2 py-1 text-sm placeholder:text-muted-foreground"
									/>
								</div>
								{#each filteredDistricts as district (district.id)}
									{@const districtSchools = schoolsFor(district.id)}
									{#if districtSchools.length > 0}
										<Select.Group>
											<Select.GroupHeading>{district.name}</Select.GroupHeading>
											{#each districtSchools as school (school.id)}
												<Select.Item value={school.id}>{school.name}</Select.Item>
											{/each}
										</Select.Group>
									{/if}
								{/each}
							</Select.Content>
						</Select.Root>
					</div>

					<div class="grid gap-1.5">
						<Label for="team_name">Team name</Label>
						<Input id="team_name" name="team_name" required bind:value={teamName} />
						<p class="text-xs text-muted-foreground">
							Usually your school name, e.g. "Roosevelt High School"
						</p>
					</div>

					<div class="grid gap-1.5">
						<Label for="password">Password</Label>
						<Input id="password" name="password" type="password" required minlength={8} />
					</div>

					<div class="grid gap-1.5">
						<Label for="password_confirm">Confirm password</Label>
						<Input
							id="password_confirm"
							name="password_confirm"
							type="password"
							required
							minlength={8}
						/>
					</div>

					<Button type="submit" disabled={submitting} class="w-full">
						{submitting ? 'Submitting…' : 'Submit registration'}
					</Button>
				</form>
			</Card.Content>
		</Card.Root>

		<p class="mt-4 text-center text-sm text-muted-foreground">
			Already registered? <a href="/login" class="underline">Log in</a>
		</p>
	</div>
{/if}
