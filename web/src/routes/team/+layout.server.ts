import { redirect } from '@sveltejs/kit';
import type { LayoutServerLoad } from './$types';

export const load: LayoutServerLoad = async ({ locals, url }) => {
	const user = locals.user;
	if (!user) {
		redirect(303, `/login?next=${encodeURIComponent(url.pathname)}`);
	}

	// Superusers should be in /admin, not /team.
	if (user.collectionName === '_superusers') {
		redirect(303, '/admin');
	}

	// At this point: locals.user is a coach with status=approved
	// (auth_guard hook blocks pending/rejected from authenticating).
	return { user };
};
