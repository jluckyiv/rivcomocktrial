import { fail } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import type { DistrictsResponse, SchoolsResponse } from '$lib/pocketbase-types';

export const load: PageServerLoad = async ({ locals }) => {
	const [districts, schools] = await Promise.all([
		locals.pb.collection('districts').getFullList<DistrictsResponse>({ sort: 'name' }),
		locals.pb.collection('schools').getFullList<SchoolsResponse>({ fields: 'district' })
	]);

	const schoolCountByDistrict = new Map<string, number>();
	for (const s of schools) {
		if (s.district) {
			schoolCountByDistrict.set(s.district, (schoolCountByDistrict.get(s.district) ?? 0) + 1);
		}
	}

	return { districts, schoolCountByDistrict: Object.fromEntries(schoolCountByDistrict) };
};

function requireAdmin(locals: App.Locals) {
	if (!locals.user) return fail(401, { error: 'Unauthorized' });
}

export const actions: Actions = {
	create: async ({ locals, request }) => {
		const guard = requireAdmin(locals);
		if (guard) return guard;

		const data = await request.formData();
		const name = (data.get('name') as string | null)?.trim() ?? '';

		if (!name) return fail(400, { error: 'Name is required.' });

		try {
			await locals.pb.collection('districts').create({ name });
		} catch {
			return fail(500, { error: 'Failed to create district.' });
		}
	},

	update: async ({ locals, request }) => {
		const guard = requireAdmin(locals);
		if (guard) return guard;

		const data = await request.formData();
		const id = data.get('id') as string;
		const name = (data.get('name') as string | null)?.trim() ?? '';

		if (!name) return fail(400, { error: 'Name is required.' });

		try {
			await locals.pb.collection('districts').update(id, { name });
		} catch {
			return fail(500, { error: 'Failed to update district.' });
		}
	},

	delete: async ({ locals, request }) => {
		const guard = requireAdmin(locals);
		if (guard) return guard;

		const data = await request.formData();
		const id = data.get('id') as string;

		try {
			await locals.pb.collection('districts').delete(id);
		} catch {
			return fail(500, { error: 'Failed to delete district.' });
		}
	}
};
