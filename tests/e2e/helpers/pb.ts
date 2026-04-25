/**
 * PocketBase admin API helpers for test setup and teardown.
 * All created records use the "playwright-" prefix so they're easy to
 * identify and clean up if a test run is interrupted.
 */

const PB_URL = "http://localhost:8090";

async function adminToken(): Promise<string> {
  const email = process.env.PB_ADMIN_EMAIL;
  const password = process.env.PB_ADMIN_PASSWORD;
  if (!email || !password) {
    throw new Error(
      "Set PB_ADMIN_EMAIL and PB_ADMIN_PASSWORD env vars before running e2e tests."
    );
  }
  const res = await fetch(
    `${PB_URL}/api/collections/_superusers/auth-with-password`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ identity: email, password }),
    }
  );
  const data = await res.json();
  return data.token as string;
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
  return res.json();
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
  return res.json();
}

export async function pbDelete(
  collection: string,
  id: string
): Promise<void> {
  const token = await adminToken();
  await fetch(`${PB_URL}/api/collections/${collection}/records/${id}`, {
    method: "DELETE",
    headers: { Authorization: token },
  });
}

export async function pbList(
  collection: string,
  filter: string
): Promise<Record<string, unknown>[]> {
  const token = await adminToken();
  const params = new URLSearchParams({ filter, perPage: "100" });
  const res = await fetch(
    `${PB_URL}/api/collections/${collection}/records?${params}`,
    { headers: { Authorization: token } }
  );
  const data = await res.json();
  return data.items ?? [];
}
