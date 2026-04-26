import { fail } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';

type SuperuserRow = {
	id: string;
	email: string;
	name: string;
	is_primary_contact: boolean;
	created: string;
};

function requireAdmin(locals: App.Locals) {
	if (locals.user?.collectionName !== '_superusers') {
		return fail(401, { error: 'Not authorized.' });
	}
	return null;
}

export const load: PageServerLoad = async ({ locals }) => {
	const records = await locals.pb.collection('_superusers').getFullList({
		sort: 'created',
		fields: 'id,email,name,is_primary_contact,created'
	});
	const superusers = records as unknown as SuperuserRow[];
	return { superusers, currentUserId: locals.user?.id ?? '' };
};

export const actions: Actions = {
	create: async ({ locals, request }) => {
		const guard = requireAdmin(locals);
		if (guard) return guard;

		const data = await request.formData();
		const email = (data.get('email') as string | null)?.trim() ?? '';
		const name = (data.get('name') as string | null)?.trim() ?? '';
		const password = (data.get('password') as string | null) ?? '';

		if (!email) return fail(400, { error: 'Email is required.' });
		if (password.length < 10) {
			return fail(400, { error: 'Password must be at least 10 characters.' });
		}

		try {
			await locals.pb.collection('_superusers').create({
				email,
				name,
				password,
				passwordConfirm: password
			});
		} catch (e: unknown) {
			const err = e as { data?: { email?: { code?: string } }; message?: string };
			if (err.data?.email?.code === 'validation_not_unique') {
				return fail(400, { error: 'A superuser with that email already exists.' });
			}
			return fail(400, { error: err.message ?? 'Failed to create superuser.' });
		}
	},

	delete: async ({ locals, request }) => {
		const guard = requireAdmin(locals);
		if (guard) return guard;

		const data = await request.formData();
		const id = (data.get('id') as string | null) ?? '';

		if (id === locals.user?.id) {
			return fail(400, { error: 'You cannot delete yourself.' });
		}

		try {
			await locals.pb.collection('_superusers').delete(id);
		} catch (e: unknown) {
			const err = e as { message?: string };
			return fail(400, { error: err.message ?? 'Failed to delete superuser.' });
		}
	},

	setPrimary: async ({ locals, request }) => {
		const guard = requireAdmin(locals);
		if (guard) return guard;

		const data = await request.formData();
		const id = (data.get('id') as string | null) ?? '';
		if (!id) return fail(400, { error: 'Missing id.' });

		const all = await locals.pb.collection('_superusers').getFullList({
			fields: 'id,is_primary_contact'
		});

		try {
			for (const record of all) {
				const shouldBe = record.id === id;
				if (Boolean(record.is_primary_contact) === shouldBe) continue;
				await locals.pb
					.collection('_superusers')
					.update(record.id, { is_primary_contact: shouldBe });
			}
		} catch (e: unknown) {
			const err = e as { message?: string };
			return fail(400, { error: err.message ?? 'Failed to update primary contact.' });
		}
	}
};
