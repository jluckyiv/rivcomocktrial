import { fail } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import type { SchoolsResponse, UsersResponse } from '$lib/pocketbase-types';

type CoachWithSchool = UsersResponse<{ school?: SchoolsResponse }>;

const STATUSES = ['pending', 'approved', 'rejected'] as const;
type Status = (typeof STATUSES)[number];

function requireAdmin(locals: App.Locals) {
	if (locals.user?.collectionName !== '_superusers') {
		return fail(401, { error: 'Not authorized.' });
	}
	return null;
}

export const load: PageServerLoad = async ({ locals, url }) => {
	const filter = (url.searchParams.get('status') ?? 'pending') as Status;
	const status = STATUSES.includes(filter) ? filter : 'pending';

	const coaches = await locals.pb.collection('users').getFullList<CoachWithSchool>({
		filter: `role = "coach" && status = "${status}"`,
		sort: '-created',
		expand: 'school'
	});

	return { coaches, status };
};

export const actions: Actions = {
	setStatus: async ({ locals, request }) => {
		const guard = requireAdmin(locals);
		if (guard) return guard;

		const data = await request.formData();
		const id = (data.get('id') as string | null) ?? '';
		const status = (data.get('status') as string | null) ?? '';

		if (!id) return fail(400, { error: 'Missing id.' });
		if (!STATUSES.includes(status as Status)) {
			return fail(400, { error: 'Invalid status.' });
		}

		try {
			await locals.pb.collection('users').update(id, { status });
		} catch (e: unknown) {
			const err = e as { message?: string };
			return fail(400, { error: err.message ?? 'Failed to update status.' });
		}
	}
};
