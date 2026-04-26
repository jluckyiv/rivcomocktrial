import PocketBase from 'pocketbase';
import type { Handle } from '@sveltejs/kit';
import { dev } from '$app/environment';
import type { TypedPocketBase } from '$lib/pocketbase-types';

const PB_INTERNAL_URL = process.env.PB_INTERNAL_URL ?? 'http://localhost:8090';

export const handle: Handle = async ({ event, resolve }) => {
	event.locals.pb = new PocketBase(PB_INTERNAL_URL) as TypedPocketBase;
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
		event.locals.pb.authStore.exportToCookie({ httpOnly: true, secure: !dev, sameSite: 'lax' })
	);

	return response;
};
