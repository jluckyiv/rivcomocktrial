import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals }) => {
	const contact = await locals.pb.send<{ email: string; name: string }>('/api/contact', {
		method: 'GET'
	});
	return { contact };
};
