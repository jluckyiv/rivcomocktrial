const PB_URL = "http://localhost:8090";

export type CollectionRules = {
	listRule: string | null;
	viewRule: string | null;
	createRule: string | null;
	updateRule: string | null;
	deleteRule: string | null;
};

async function adminToken(): Promise<string> {
	const email = process.env.PB_ADMIN_EMAIL;
	const password = process.env.PB_ADMIN_PASSWORD;
	if (!email || !password) {
		throw new Error(
			"PB_ADMIN_EMAIL and PB_ADMIN_PASSWORD are required for schema tests.\n" +
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
