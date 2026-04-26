import { fail } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import type { TournamentsResponse } from '$lib/pocketbase-types';

const STATUSES = ['draft', 'registration', 'active', 'completed'] as const;
type Status = (typeof STATUSES)[number];

function requireAdmin(locals: App.Locals) {
	if (locals.user?.collectionName !== '_superusers') {
		return fail(401, { error: 'Not authorized.' });
	}
	return null;
}

export const load: PageServerLoad = async ({ locals }) => {
	const tournaments = await locals.pb.collection('tournaments').getFullList<TournamentsResponse>({
		sort: '-created'
	});
	return { tournaments };
};

export const actions: Actions = {
	create: async ({ locals, request }) => {
		const guard = requireAdmin(locals);
		if (guard) return guard;

		const data = await request.formData();
		const name = (data.get('name') as string | null)?.trim() ?? '';
		const year = parseInt((data.get('year') as string | null) ?? '', 10);
		const prelim = parseInt((data.get('num_preliminary_rounds') as string | null) ?? '', 10);
		const elim = parseInt((data.get('num_elimination_rounds') as string | null) ?? '', 10);

		if (!name) return fail(400, { error: 'Name is required.' });
		if (!Number.isFinite(year)) return fail(400, { error: 'Year is required.' });
		if (!Number.isFinite(prelim) || prelim < 0) {
			return fail(400, { error: 'Preliminary rounds must be a non-negative number.' });
		}
		if (!Number.isFinite(elim) || elim < 0) {
			return fail(400, { error: 'Elimination rounds must be a non-negative number.' });
		}

		try {
			await locals.pb.collection('tournaments').create({
				name,
				year,
				num_preliminary_rounds: prelim,
				num_elimination_rounds: elim,
				status: 'draft'
			});
		} catch (e: unknown) {
			const err = e as { message?: string };
			return fail(400, { error: err.message ?? 'Failed to create tournament.' });
		}
	},

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
			await locals.pb.collection('tournaments').update(id, { status });
		} catch (e: unknown) {
			const err = e as { message?: string };
			return fail(400, { error: err.message ?? 'Failed to update status.' });
		}
	},

	delete: async ({ locals, request }) => {
		const guard = requireAdmin(locals);
		if (guard) return guard;

		const data = await request.formData();
		const id = (data.get('id') as string | null) ?? '';

		try {
			await locals.pb.collection('tournaments').delete(id);
		} catch (e: unknown) {
			const err = e as { message?: string };
			return fail(400, { error: err.message ?? 'Failed to delete tournament.' });
		}
	}
};
