// Seed schools from schools.json into PocketBase.
// Districts must already be seeded (npm run pb:seed-districts).
// Skips any school whose name already exists.
// Safe to re-run.
//
// Usage (local):
//   npm run pb:seed-schools
//
// Usage (staging):
//   PB_URL=https://rivcomocktrial-staging.fly.dev \
//   PB_ADMIN_EMAIL=you@example.com \
//   PB_ADMIN_PASSWORD=yourpassword \
//   node backend/pb_seed/seed_schools.js

import { readFileSync } from 'node:fs';
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

// Load district name → id map
const districtsRes = await fetch(
  `${PB_URL}/api/collections/districts/records?perPage=500&fields=id,name`,
  { headers: { Authorization: `Bearer ${token}` } }
);
if (!districtsRes.ok) {
  console.error('Failed to fetch districts:', await districtsRes.text());
  process.exit(1);
}
const { items: districtItems } = await districtsRes.json();
const districtIdByName = new Map(districtItems.map((d) => [d.name, d.id]));

if (districtIdByName.size === 0) {
  console.error('No districts found. Run pb:seed-districts first.');
  process.exit(1);
}

// Load existing school names
const existingRes = await fetch(
  `${PB_URL}/api/collections/schools/records?perPage=500&fields=name`,
  { headers: { Authorization: `Bearer ${token}` } }
);
if (!existingRes.ok) {
  console.error('Failed to fetch existing schools:', await existingRes.text());
  process.exit(1);
}
const { items: existingItems } = await existingRes.json();
const existingNames = new Set(existingItems.map((s) => s.name));

const schools = JSON.parse(
  readFileSync(join(__dirname, 'schools.json'), 'utf8')
);

let created = 0;
let skipped = 0;

for (const { name, district: districtName } of schools) {
  if (existingNames.has(name)) {
    console.log(`skip    ${name}`);
    skipped++;
    continue;
  }

  const districtId = districtIdByName.get(districtName);
  if (!districtId) {
    console.error(`error   ${name}: unknown district "${districtName}"`);
    process.exit(1);
  }

  const res = await fetch(`${PB_URL}/api/collections/schools/records`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({ name, district: districtId }),
  });

  if (!res.ok) {
    console.error(`error   ${name}:`, await res.text());
    process.exit(1);
  }

  console.log(`created ${name}`);
  created++;
}

console.log(`\nDone. ${created} created, ${skipped} skipped.`);
