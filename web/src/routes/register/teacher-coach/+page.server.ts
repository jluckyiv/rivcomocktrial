import { fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals }) => {
	const [districts, schools, openTournaments, contact] = await Promise.all([
		locals.pb.collection('districts').getFullList({ sort: 'name' }),
		locals.pb.collection('schools').getFullList({ sort: 'name', expand: 'district' }),
		locals.pb.collection('tournaments').getFullList({
			filter: 'status = "registration"',
			sort: '-created',
			fields: 'id,name,year'
		}),
		locals.pb.send<{ email: string; name: string }>('/api/contact', { method: 'GET' })
	]);

	const tournament = openTournaments[0] ?? null;
	return { districts, schools, tournament, contact };
};

export const actions: Actions = {
	default: async ({ locals, request }) => {
		const data = await request.formData();

		const firstName = (data.get('first_name') as string | null)?.trim() ?? '';
		const lastName = (data.get('last_name') as string | null)?.trim() ?? '';
		const email = (data.get('email') as string | null)?.trim() ?? '';
		const password = (data.get('password') as string | null) ?? '';
		const passwordConfirm = (data.get('password_confirm') as string | null) ?? '';
		const school = (data.get('school') as string | null) ?? '';
		const teamName = (data.get('team_name') as string | null)?.trim() ?? '';

		const values = { firstName, lastName, email, school, teamName };

		if (password !== passwordConfirm) {
			return fail(400, { error: 'Passwords do not match.', values });
		}

		if (password.length < 8) {
			return fail(400, { error: 'Password must be at least 8 characters.', values });
		}

		const joinTeamId = (data.get('join_team_id') as string | null)?.trim() || null;

		const createBody: Record<string, unknown> = {
			name: `${firstName} ${lastName}`,
			email,
			emailVisibility: false,
			password,
			passwordConfirm,
			role: 'coach',
			status: 'pending',
			school,
			team_name: teamName
		};
		if (joinTeamId) {
			createBody.join_team_id = joinTeamId;
		}

		try {
			await locals.pb.collection('users').create(createBody);
		} catch (e: unknown) {
			const err = e as { data?: { email?: { code?: string } }; status?: number };

			if (err.data?.email?.code === 'validation_not_unique') {
				return fail(400, {
					error: 'That email address is already registered.',
					values
				});
			}

			if (err.status === 400) {
				const msg = (e as { message?: string }).message ?? 'Registration failed.';

				if (msg.startsWith('A team with this name already exists')) {
					const collision = await locals.pb
						.send<{ existingTeamId: string | null }>('/api/teams/check-collision', {
							method: 'GET',
							query: { name: teamName, school }
						})
						.catch(() => ({ existingTeamId: null }));
					return fail(400, {
						collision: true,
						existingTeamId: collision.existingTeamId,
						error: msg,
						values
					});
				}

				return fail(400, { error: msg, values });
			}

			return fail(500, { error: 'An unexpected error occurred. Please try again.', values });
		}

		redirect(303, '/register/pending');
	}
};
