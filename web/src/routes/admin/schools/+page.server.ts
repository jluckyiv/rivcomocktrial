import { fail } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import type { DistrictsResponse, SchoolsResponse } from '$lib/pocketbase-types';

type SchoolWithDistrict = SchoolsResponse<{ district?: DistrictsResponse }>;

export const load: PageServerLoad = async ({ locals }) => {
	const [districts, schools] = await Promise.all([
		locals.pb.collection('districts').getFullList<DistrictsResponse>({ sort: 'name' }),
		locals.pb
			.collection('schools')
			.getFullList<SchoolWithDistrict>({ sort: 'name', expand: 'district' })
	]);
	return { districts, schools };
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
		const nickname = (data.get('nickname') as string | null)?.trim() ?? '';
		const district = (data.get('district') as string | null) ?? '';

		if (!name) return fail(400, { error: 'Name is required.' });

		try {
			await locals.pb
				.collection('schools')
				.create({ name, nickname: nickname || null, district: district || null });
		} catch {
			return fail(500, { error: 'Failed to create school.' });
		}
	},

	update: async ({ locals, request }) => {
		const guard = requireAdmin(locals);
		if (guard) return guard;

		const data = await request.formData();
		const id = data.get('id') as string;
		const name = (data.get('name') as string | null)?.trim() ?? '';
		const nickname = (data.get('nickname') as string | null)?.trim() ?? '';
		const district = (data.get('district') as string | null) ?? '';

		if (!name) return fail(400, { error: 'Name is required.' });

		try {
			await locals.pb.collection('schools').update(id, {
				name,
				nickname: nickname || null,
				district: district || null
			});
		} catch {
			return fail(500, { error: 'Failed to update school.' });
		}
	},

	delete: async ({ locals, request }) => {
		const guard = requireAdmin(locals);
		if (guard) return guard;

		const data = await request.formData();
		const id = data.get('id') as string;

		try {
			await locals.pb.collection('schools').delete(id);
		} catch {
			return fail(500, { error: 'Failed to delete school.' });
		}
	}
};
