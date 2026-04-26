import PocketBase from 'pocketbase';
import type { Handle } from '@sveltejs/kit';
import type { TypedPocketBase } from '$lib/pocketbase-types';

export const handle: Handle = async ({ event, resolve }) => {
	event.locals.pb = new PocketBase('http://localhost:8090') as TypedPocketBase;
	event.locals.pb.authStore.loadFromCookie(event.request.headers.get('cookie') ?? '');

	try {
		if (event.locals.pb.authStore.isValid) {
			const collection = event.locals.pb.authStore.record?.collectionName ?? '_superusers';
			if (collection === '_superusers') {
				await event.locals.pb.collection('_superusers').authRefresh();
			} else {
				await event.locals.pb.collection('users').authRefresh();
			}
		}
	} catch {
		event.locals.pb.authStore.clear();
	}

	event.locals.user = event.locals.pb.authStore.record;

	const response = await resolve(event);

	response.headers.append(
		'set-cookie',
		event.locals.pb.authStore.exportToCookie({ httpOnly: true, secure: false, sameSite: 'lax' })
	);

	return response;
};
