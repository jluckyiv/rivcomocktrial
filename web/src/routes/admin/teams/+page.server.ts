import type { PageServerLoad } from './$types';
import type {
	SchoolsResponse,
	TeamsResponse,
	TournamentsResponse,
	UsersResponse
} from '$lib/pocketbase-types';

type TeamWithRelations = TeamsResponse<{
	school?: SchoolsResponse;
	tournament?: TournamentsResponse;
	coach?: UsersResponse;
}>;

export const load: PageServerLoad = async ({ locals, url }) => {
	const tournamentId = url.searchParams.get('tournament') ?? '';

	const tournaments = await locals.pb.collection('tournaments').getFullList<TournamentsResponse>({
		sort: '-created',
		filter: 'status != "completed"'
	});

	const selected = tournaments.find((t) => t.id === tournamentId) ?? tournaments[0] ?? null;

	const teams = selected
		? await locals.pb.collection('teams').getFullList<TeamWithRelations>({
				filter: `tournament = "${selected.id}"`,
				expand: 'school,tournament,coach',
				sort: 'name'
			})
		: [];

	return { tournaments, selected, teams };
};
