import { redirect } from '@sveltejs/kit';
import type { LayoutServerLoad } from './$types';

export const load: LayoutServerLoad = async ({ locals, url }) => {
	const isSuperuser = locals.user?.collectionName === '_superusers';
	if (!isSuperuser) {
		redirect(303, `/login?next=${encodeURIComponent(url.pathname)}`);
	}
	return { userEmail: locals.user!.email as string };
};
