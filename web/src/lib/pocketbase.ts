import PocketBase from 'pocketbase';
import { browser, dev } from '$app/environment';
import type { TypedPocketBase } from './pocketbase-types';

const url = browser
	? dev
		? 'http://localhost:8090'
		: '/'
	: (process.env.PB_INTERNAL_URL ?? 'http://localhost:8090');

export const pb = new PocketBase(url) as TypedPocketBase;
