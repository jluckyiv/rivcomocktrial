const PB_URL = "http://localhost:8090";

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
		this.name = "PbError";
	}
}

async function adminToken(): Promise<string> {
	const email = process.env.PB_ADMIN_EMAIL;
	const password = process.env.PB_ADMIN_PASSWORD;
	if (!email || !password) {
		throw new Error(
			"PB_ADMIN_EMAIL and PB_ADMIN_PASSWORD are required for hook/schema tests.\n" +
				"Run: npm run pb:credentials (from repo root)"
		);
	}
	const res = await fetch(`${PB_URL}/api/collections/_superusers/auth-with-password`, {
		method: "POST",
		headers: { "Content-Type": "application/json" },
		body: JSON.stringify({ identity: email, password })
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
		method: "POST",
		headers: { "Content-Type": "application/json", Authorization: token },
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
		method: "PATCH",
		headers: { "Content-Type": "application/json", Authorization: token },
		body: JSON.stringify(body)
	});
	const data = await res.json();
	if (!res.ok) throw new PbError(res.status, data);
	return data as Record<string, unknown>;
}

export async function pbDelete(collection: string, id: string): Promise<void> {
	const token = await adminToken();
	const res = await fetch(`${PB_URL}/api/collections/${collection}/records/${id}`, {
		method: "DELETE",
		headers: { Authorization: token }
	});
	if (!res.ok) {
		const data = res.headers.get("content-type")?.includes("application/json")
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
	const params = new URLSearchParams({ filter, perPage: "100" });
	const res = await fetch(`${PB_URL}/api/collections/${collection}/records?${params}`, {
		headers: { Authorization: token }
	});
	if (!res.ok) throw new PbError(res.status, await res.json());
	const data = (await res.json()) as { items: Record<string, unknown>[] };
	return data.items ?? [];
}
