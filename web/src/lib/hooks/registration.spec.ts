/**
 * Hook integration tests for registration.pb.js.
 *
 * Covers all four callbacks:
 *   onRecordCreateRequest  — pre-commit validation + join-intent stash
 *   onRecordAfterCreateSuccess — new-team vs join-existing post-commit
 *   onRecordDeleteRequest  — sole-coach guard
 *   onRecordAfterUpdateSuccess — status sync (approved → active, rejected → rejected)
 *
 * Pre-conditions (same as schema tests):
 *   npm run pb:start        # PocketBase via docker compose
 *   npm run pb:seed-admins  # provision superuser
 *   npm run pb:credentials  # save 1Password creds (if .pocketbase/ missing)
 *
 * Run: npm run test:hooks  (from repo root)
 */

import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { pbCreate, pbDelete, pbList, pbPatch, PbError } from "../test-helpers/pb-admin";

type Tracked = { collection: string; id: string };

let schoolId: string;
const tracked: Tracked[] = [];

function track(collection: string, id: string) {
	tracked.push({ collection, id });
}

async function cleanup() {
	for (const { collection, id } of [...tracked].reverse()) {
		try {
			await pbDelete(collection, id);
		} catch {
			// best-effort; record may already be gone
		}
	}
	tracked.length = 0;
}

beforeAll(async () => {
	const tournaments = await pbList("tournaments", "status = 'registration'");
	if (tournaments.length === 0) {
		throw new Error("No registration-status tournament — seed the dev DB first.");
	}

	const districts = await pbList("districts", "");
	if (districts.length === 0) {
		throw new Error("No districts found — seed the dev DB first.");
	}
	const district = districts[0] as { id: string };

	const school = await pbCreate("schools", {
		name: "hooks-reg-school",
		district: district.id
	});
	schoolId = (school as { id: string }).id;
	track("schools", schoolId);
});

afterAll(cleanup);

function coachBody(suffix: string, teamName: string, extra?: Record<string, unknown>) {
	return {
		email: `hooks-reg-${suffix}@test.invalid`,
		password: "testpass123",
		passwordConfirm: "testpass123",
		name: `hooks-reg-${suffix}`,
		role: "coach",
		status: "pending",
		school: schoolId,
		team_name: teamName,
		...extra
	};
}

describe("new-team path", () => {
	it("creates a pending team linked to the coach", async () => {
		const coach = await pbCreate("users", coachBody("new-team", "hooks-reg-new-team"));
		const coachId = (coach as { id: string }).id;
		track("users", coachId);

		const teams = await pbList("teams", `coaches ~ '${coachId}'`);
		expect(teams).toHaveLength(1);
		const team = teams[0] as { id: string; coaches: string[]; status: string };
		track("teams", team.id);

		expect(team.coaches).toContain(coachId);
		expect(team.status).toBe("pending");
	});
});

describe("join-existing path", () => {
	it("creates a join_requests row and no duplicate team", async () => {
		const coachA = await pbCreate("users", coachBody("join-a", "hooks-reg-join-team"));
		const coachAId = (coachA as { id: string }).id;
		track("users", coachAId);

		const teams = await pbList("teams", `coaches ~ '${coachAId}'`);
		expect(teams).toHaveLength(1);
		const teamA = teams[0] as { id: string; name: string };
		track("teams", teamA.id);

		const coachB = await pbCreate(
			"users",
			coachBody("join-b", teamA.name, { join_team_id: teamA.id })
		);
		const coachBId = (coachB as { id: string }).id;
		track("users", coachBId);

		const joinRequests = await pbList(
			"join_requests",
			`user = '${coachBId}' && team = '${teamA.id}'`
		);
		expect(joinRequests).toHaveLength(1);
		const jr = joinRequests[0] as { id: string; status: string };
		track("join_requests", jr.id);
		expect(jr.status).toBe("pending");

		const allTeams = await pbList("teams", `coaches ~ '${coachAId}'`);
		expect(allTeams).toHaveLength(1);
	});
});

describe("collision-without-intent", () => {
	it("returns 400 with existingTeamId when name+school collide and no join_team_id", async () => {
		const coachA = await pbCreate("users", coachBody("col-a", "hooks-reg-col-team"));
		const coachAId = (coachA as { id: string }).id;
		track("users", coachAId);

		const teams = await pbList("teams", `coaches ~ '${coachAId}'`);
		const team = teams[0] as { id: string };
		track("teams", team.id);

		const err = await pbCreate(
			"users",
			coachBody("col-b", "hooks-reg-col-team")
		).catch((e: unknown) => e);

		expect(err).toBeInstanceOf(PbError);
		const pbErr = err as PbError;
		expect(pbErr.status).toBe(400);
		expect((pbErr.data as { data?: { existingTeamId?: string } }).data?.existingTeamId).toBe(
			team.id
		);
	});
});

describe("sole-coach delete guard", () => {
	it("blocks deletion of the sole coach on a pending team with 400", async () => {
		const coach = await pbCreate("users", coachBody("del-sole", "hooks-reg-del-sole-team"));
		const coachId = (coach as { id: string }).id;
		track("users", coachId);

		const teams = await pbList("teams", `coaches ~ '${coachId}'`);
		const team = teams[0] as { id: string };
		track("teams", team.id);

		const err = await pbDelete("users", coachId).catch((e: unknown) => e);
		expect(err).toBeInstanceOf(PbError);
		expect((err as PbError).status).toBe(400);
	});
});

describe("two-coach delete allowed", () => {
	it("allows deleting one coach when another remains on the team", async () => {
		const coachA = await pbCreate("users", coachBody("del-two-a", "hooks-reg-del-two-team"));
		const coachAId = (coachA as { id: string }).id;
		track("users", coachAId);

		const teams = await pbList("teams", `coaches ~ '${coachAId}'`);
		const team = teams[0] as { id: string; coaches: string[] };
		track("teams", team.id);

		const coachB = await pbCreate("users", {
			email: "hooks-reg-del-two-b@test.invalid",
			password: "testpass123",
			passwordConfirm: "testpass123",
			name: "hooks-reg-del-two-b",
			role: "coach",
			status: "pending",
			school: schoolId
		});
		const coachBId = (coachB as { id: string }).id;
		track("users", coachBId);

		// Add coach B directly via admin PATCH — bypasses hook for test setup.
		await pbPatch("teams", team.id, { coaches: [coachAId, coachBId] });

		// Deleting coach A should succeed now that coach B is on the team.
		await pbDelete("users", coachAId);
		// Remove coachA from tracked — already deleted above.
		const idx = tracked.findLastIndex(
			(t) => t.collection === "users" && t.id === coachAId
		);
		if (idx !== -1) tracked.splice(idx, 1);

		// Confirm coach A is gone and coach B remains on the team.
		const remaining = await pbList("teams", `id = '${team.id}'`);
		expect((remaining[0] as { coaches: string[] }).coaches).not.toContain(coachAId);
		expect((remaining[0] as { coaches: string[] }).coaches).toContain(coachBId);
	});
});

describe("status sync", () => {
	it("promotes team to active when coach is approved", async () => {
		const coach = await pbCreate("users", coachBody("sync-approve", "hooks-reg-sync-approve"));
		const coachId = (coach as { id: string }).id;
		track("users", coachId);

		const teams = await pbList("teams", `coaches ~ '${coachId}'`);
		const team = teams[0] as { id: string };
		track("teams", team.id);

		await pbPatch("users", coachId, { status: "approved" });

		const updated = await pbList("teams", `id = '${team.id}'`);
		expect((updated[0] as { status: string }).status).toBe("active");
	});

	it("rejects team when coach is rejected", async () => {
		const coach = await pbCreate("users", coachBody("sync-reject", "hooks-reg-sync-reject"));
		const coachId = (coach as { id: string }).id;
		track("users", coachId);

		const teams = await pbList("teams", `coaches ~ '${coachId}'`);
		const team = teams[0] as { id: string };
		track("teams", team.id);

		await pbPatch("users", coachId, { status: "rejected" });

		const updated = await pbList("teams", `id = '${team.id}'`);
		expect((updated[0] as { status: string }).status).toBe("rejected");
	});
});
