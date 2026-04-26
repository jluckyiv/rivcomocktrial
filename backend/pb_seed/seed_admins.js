// Seed PocketBase superusers from admins.json.
// Each admin receives a random password; they log in via magic link.
// Safe to re-run — existing accounts are skipped.
//
// Usage (local):
//   npm run pb:seed-admins
//
// Usage (staging):
//   PB_URL=https://rivcomocktrial-staging.fly.dev \
//   PB_ADMIN_EMAIL=you@example.com \
//   PB_ADMIN_PASSWORD=yourpassword \
//   node backend/pb_seed/seed_admins.js

import { readFileSync } from 'node:fs';
import { randomBytes } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const PB_URL = process.env.PB_URL ?? 'http://localhost:8090';
const { PB_ADMIN_EMAIL, PB_ADMIN_PASSWORD } = process.env;

if (!PB_ADMIN_EMAIL || !PB_ADMIN_PASSWORD) {
  console.error('PB_ADMIN_EMAIL and PB_ADMIN_PASSWORD are required');
  process.exit(1);
}

const authRes = await fetch(
  `${PB_URL}/api/collections/_superusers/auth-with-password`,
  {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ identity: PB_ADMIN_EMAIL, password: PB_ADMIN_PASSWORD }),
  }
);
if (!authRes.ok) {
  console.error('Auth failed:', await authRes.text());
  process.exit(1);
}
const { token } = await authRes.json();

const admins = JSON.parse(
  readFileSync(join(__dirname, 'admins.json'), 'utf8')
);

for (const { email } of admins) {
  const password = randomBytes(24).toString('base64url');
  const res = await fetch(`${PB_URL}/api/collections/_superusers/records`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({ email, password, passwordConfirm: password }),
  });

  if (res.status === 400) {
    const body = await res.json();
    if (body.data?.email) {
      console.log(`skip    ${email} (already exists)`);
      continue;
    }
    console.error(`error   ${email}:`, JSON.stringify(body));
    process.exit(1);
  }
  if (!res.ok) {
    console.error(`error   ${email}:`, await res.text());
    process.exit(1);
  }
  console.log(`created ${email}`);
}
