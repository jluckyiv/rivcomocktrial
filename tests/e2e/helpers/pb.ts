/**
 * PocketBase admin API helpers for e2e test setup and teardown.
 * All helpers throw on non-2xx so failures surface at the bad call,
 * not two assertions later.
 */

// Credentials must match web/src/lib/test-helpers/test-admin.ts and pb:seed-test-admin.
const TEST_ADMIN_EMAIL = "test-admin@test.invalid";
const TEST_ADMIN_PASSWORD = "testpass1234";

const PB_URL = "http://localhost:8090";

async function adminToken(): Promise<string> {
  const email = process.env.PB_ADMIN_EMAIL ?? TEST_ADMIN_EMAIL;
  const password = process.env.PB_ADMIN_PASSWORD ?? TEST_ADMIN_PASSWORD;
  const res = await fetch(
    `${PB_URL}/api/collections/_superusers/auth-with-password`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ identity: email, password }),
    }
  );
  if (!res.ok) throw new Error(`Admin auth failed: ${res.status}`);
  const data = (await res.json()) as { token: string };
  return data.token;
}

export async function pbCreate(
  collection: string,
  body: Record<string, unknown>
): Promise<Record<string, unknown>> {
  const token = await adminToken();
  const res = await fetch(`${PB_URL}/api/collections/${collection}/records`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: token,
    },
    body: JSON.stringify(body),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(`pbCreate ${collection} failed ${res.status}: ${JSON.stringify(data)}`);
  return data as Record<string, unknown>;
}

export async function pbPatch(
  collection: string,
  id: string,
  body: Record<string, unknown>
): Promise<Record<string, unknown>> {
  const token = await adminToken();
  const res = await fetch(
    `${PB_URL}/api/collections/${collection}/records/${id}`,
    {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        Authorization: token,
      },
      body: JSON.stringify(body),
    }
  );
  const data = await res.json();
  if (!res.ok) throw new Error(`pbPatch ${collection}/${id} failed ${res.status}: ${JSON.stringify(data)}`);
  return data as Record<string, unknown>;
}

export async function pbDelete(
  collection: string,
  id: string
): Promise<void> {
  const token = await adminToken();
  const res = await fetch(`${PB_URL}/api/collections/${collection}/records/${id}`, {
    method: "DELETE",
    headers: { Authorization: token },
  });
  if (!res.ok) {
    const body = res.headers.get("content-type")?.includes("application/json")
      ? JSON.stringify(await res.json())
      : "";
    throw new Error(`pbDelete ${collection}/${id} failed ${res.status}: ${body}`);
  }
}

export async function pbList(
  collection: string,
  filter: string
): Promise<Record<string, unknown>[]> {
  const token = await adminToken();
  const params = new URLSearchParams({ perPage: "100" });
  if (filter) params.set("filter", filter);
  const res = await fetch(
    `${PB_URL}/api/collections/${collection}/records?${params}`,
    { headers: { Authorization: token } }
  );
  const data = await res.json();
  if (!res.ok) throw new Error(`pbList ${collection} failed ${res.status}: ${JSON.stringify(data)}`);
  return (data as { items: Record<string, unknown>[] }).items ?? [];
}
