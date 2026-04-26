import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals }) => {
	const schools = await locals.pb.collection('schools').getFullList({ sort: 'name' });
	return { schools };
};
