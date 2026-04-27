// PocketBase admin API helpers for hook + schema tests.
// Configuration comes from environment variables sourced from .env.test
// at the repo root (see package.json test:hooks / test:schema scripts).

const PB_URL = requireEnv('PB_URL');
const PB_ADMIN_EMAIL = requireEnv('PB_ADMIN_EMAIL');
const PB_ADMIN_PASSWORD = requireEnv('PB_ADMIN_PASSWORD');

function requireEnv(name: string): string {
	const value = process.env[name];
	if (!value) {
		throw new Error(
			`${name} is not set. Source .env.test before running tests ` +
				`(npm scripts at the repo root do this automatically).`
		);
	}
	return value;
}

export type CollectionRules = {
	listRule: string | null;
	viewRule: string | null;
	createRule: string | null;
	updateRule: string | null;
	deleteRule: string | null;
};

export class PbError extends Error {
	constructor(
		public readonly status: number,
		public readonly data: unknown
	) {
		super(`PocketBase error ${status}`);
		this.name = 'PbError';
	}
}

async function adminToken(): Promise<string> {
	const res = await fetch(`${PB_URL}/api/collections/_superusers/auth-with-password`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({ identity: PB_ADMIN_EMAIL, password: PB_ADMIN_PASSWORD })
	});
	if (!res.ok) throw new Error(`Admin auth failed: ${res.status}`);
	const data = (await res.json()) as { token: string };
	return data.token;
}

export async function getCollection(name: string): Promise<CollectionRules | null> {
	const token = await adminToken();
	const res = await fetch(`${PB_URL}/api/collections/${name}`, {
		headers: { Authorization: token }
	});
	if (res.status === 404) return null;
	if (!res.ok) throw new Error(`Failed to fetch collection "${name}": ${res.status}`);
	return res.json() as Promise<CollectionRules>;
}

export async function pbCreate(
	collection: string,
	body: Record<string, unknown>
): Promise<Record<string, unknown>> {
	const token = await adminToken();
	const res = await fetch(`${PB_URL}/api/collections/${collection}/records`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json', Authorization: token },
		body: JSON.stringify(body)
	});
	const data = await res.json();
	if (!res.ok) throw new PbError(res.status, data);
	return data as Record<string, unknown>;
}

export async function pbPatch(
	collection: string,
	id: string,
	body: Record<string, unknown>
): Promise<Record<string, unknown>> {
	const token = await adminToken();
	const res = await fetch(`${PB_URL}/api/collections/${collection}/records/${id}`, {
		method: 'PATCH',
		headers: { 'Content-Type': 'application/json', Authorization: token },
		body: JSON.stringify(body)
	});
	const data = await res.json();
	if (!res.ok) throw new PbError(res.status, data);
	return data as Record<string, unknown>;
}

export async function pbDelete(collection: string, id: string): Promise<void> {
	const token = await adminToken();
	const res = await fetch(`${PB_URL}/api/collections/${collection}/records/${id}`, {
		method: 'DELETE',
		headers: { Authorization: token }
	});
	if (!res.ok) {
		const data = res.headers.get('content-type')?.includes('application/json')
			? await res.json()
			: null;
		throw new PbError(res.status, data);
	}
}

export async function pbList(
	collection: string,
	filter: string
): Promise<Record<string, unknown>[]> {
	const token = await adminToken();
	const params = new URLSearchParams({ perPage: '100' });
	if (filter) params.set('filter', filter);
	const res = await fetch(`${PB_URL}/api/collections/${collection}/records?${params}`, {
		headers: { Authorization: token }
	});
	if (!res.ok) throw new PbError(res.status, await res.json());
	const data = (await res.json()) as { items: Record<string, unknown>[] };
	return data.items ?? [];
}
