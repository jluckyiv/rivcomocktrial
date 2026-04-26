import { error } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';
import type { SchoolsResponse, TeamsResponse, TournamentsResponse } from '$lib/pocketbase-types';

type TeamWithRelations = TeamsResponse<{
	school?: SchoolsResponse;
	tournament?: TournamentsResponse;
}>;

export const load: PageServerLoad = async ({ locals }) => {
	const userId = locals.user?.id;
	if (!userId) {
		// Layout guard should have redirected already; defensive.
		error(401, 'Not authenticated.');
	}

	const teams = await locals.pb.collection('teams').getFullList<TeamWithRelations>({
		filter: `coach = "${userId}"`,
		expand: 'school,tournament',
		sort: '-created'
	});

	return { team: teams[0] ?? null };
};
