import { fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals, url }) => {
	if (locals.user) {
		const dest = locals.user.collectionName === '_superusers' ? '/admin' : '/team';
		redirect(303, dest);
	}
	return { next: url.searchParams.get('next') ?? '' };
};

function redirectAfterAuth(collectionName: string, next: string) {
	const dest = collectionName === '_superusers' ? '/admin' : '/team';
	redirect(303, next || dest);
}

export const actions: Actions = {
	password: async ({ locals, request }) => {
		const data = await request.formData();
		const email = (data.get('email') as string).trim();
		const password = data.get('password') as string;
		const next = data.get('next') as string;

		// Try superuser first, then coach.
		let authedCollection: '_superusers' | 'users' | null = null;

		for (const collection of ['_superusers', 'users'] as const) {
			try {
				await locals.pb.collection(collection).authWithPassword(email, password);
				authedCollection = collection;
				break;
			} catch (e: unknown) {
				const err = e as { status?: number; message?: string };
				if (err.status === 403) {
					return fail(403, { error: err.message ?? 'Account not active.' });
				}
			}
		}

		if (!authedCollection) return fail(400, { error: 'Invalid email or password.' });
		redirectAfterAuth(authedCollection, next);
	},

	requestOtp: async ({ locals, request }) => {
		const data = await request.formData();
		const email = (data.get('email') as string).trim();
		const next = data.get('next') as string;

		for (const collection of ['_superusers', 'users'] as const) {
			try {
				const { otpId } = await locals.pb.collection(collection).requestOTP(email);
				return { step: 'verify', otpId, collection, email, next };
			} catch {
				// Not in this collection — try next.
			}
		}

		return fail(400, { error: 'No account found for that email address.' });
	},

	verifyOtp: async ({ locals, request }) => {
		const data = await request.formData();
		const otpId = data.get('otpId') as string;
		const otp = (data.get('otp') as string).trim();
		const collection = data.get('collection') as '_superusers' | 'users';
		const email = data.get('email') as string;
		const next = data.get('next') as string;

		try {
			await locals.pb.collection(collection).authWithOTP(otpId, otp);
		} catch (e: unknown) {
			const err = e as { status?: number; message?: string };
			if (err.status === 403) {
				return fail(403, { error: err.message ?? 'Account not active.', step: 'verify', otpId, collection, email, next });
			}
			return fail(400, { error: 'Invalid or expired code.', step: 'verify', otpId, collection, email, next });
		}
		redirectAfterAuth(collection, next);
	},
};
