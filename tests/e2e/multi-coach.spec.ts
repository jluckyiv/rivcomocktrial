import { test, expect } from "@playwright/test";
import { pbCreate, pbDelete, pbList } from "./helpers/pb";

// Smoke tests for the multi-coach teams backend (#169):
//   1. Coach registration creates a team with coaches: [userId]
//   2. Deleting the sole coach on a pending team is blocked with 400

const PB_URL = "http://localhost:8090";

async function adminToken(): Promise<string> {
  const email = process.env.PB_ADMIN_EMAIL!;
  const password = process.env.PB_ADMIN_PASSWORD!;
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

// Returns the HTTP status of a DELETE attempt (does not throw).
async function tryDeleteUser(id: string): Promise<number> {
  const token = await adminToken();
  const res = await fetch(`${PB_URL}/api/collections/users/records/${id}`, {
    method: "DELETE",
    headers: { Authorization: token },
  });
  return res.status;
}

let createdIds: { collection: string; id: string }[] = [];

async function cleanup() {
  for (const { collection, id } of [...createdIds].reverse()) {
    await pbDelete(collection, id);
  }
  createdIds = [];
}

test.describe("Multi-coach teams backend", () => {
  let schoolId: string;

  test.beforeAll(async () => {
    const tournaments = await pbList("tournaments", "status = 'registration'");
    if (tournaments.length === 0) {
      throw new Error("No registration-status tournament — seed the dev DB first.");
    }
    const districts = await pbList("districts", "");
    if (districts.length === 0) {
      throw new Error("No districts found — seed the dev DB first.");
    }
    const district = districts[0] as { id: string };
    const school = (await pbCreate("schools", {
      name: "PW Multi-Coach School",
      district: district.id,
    })) as { id: string };
    schoolId = school.id;
    createdIds.push({ collection: "schools", id: school.id });
  });

  test.afterAll(cleanup);

  test("coach registration creates team with coaches:[userId]", async () => {
    const coach = (await pbCreate("users", {
      email: "pw-multi-coach-reg@test.invalid",
      password: "testpass123",
      passwordConfirm: "testpass123",
      name: "PW Multi Coach Reg",
      role: "coach",
      status: "pending",
      school: schoolId,
      team_name: "PW Multi Coach Team",
    })) as { id: string };
    // Push coach before team so reversed cleanup deletes team first, then coach.
    createdIds.push({ collection: "users", id: coach.id });

    const teams = await pbList("teams", `coaches ~ '${coach.id}'`);
    expect(teams).toHaveLength(1);
    const team = teams[0] as { id: string; coaches: string[] };
    createdIds.push({ collection: "teams", id: team.id });

    expect(team.coaches).toContain(coach.id);
  });

  test("join-existing path creates a join request, not a duplicate team", async () => {
    // Register coach A — creates Team T.
    const coachA = (await pbCreate("users", {
      email: "pw-multi-coach-join-a@test.invalid",
      password: "testpass123",
      passwordConfirm: "testpass123",
      name: "PW Multi Coach Join A",
      role: "coach",
      status: "pending",
      school: schoolId,
      team_name: "PW Multi Coach Join Team",
    })) as { id: string };
    createdIds.push({ collection: "users", id: coachA.id });

    const teams = await pbList("teams", `coaches ~ '${coachA.id}'`);
    expect(teams).toHaveLength(1);
    const teamA = teams[0] as { id: string; name: string };
    createdIds.push({ collection: "teams", id: teamA.id });

    // Register coach B with same name+school and join_team_id = teamA.id.
    const coachB = (await pbCreate("users", {
      email: "pw-multi-coach-join-b@test.invalid",
      password: "testpass123",
      passwordConfirm: "testpass123",
      name: "PW Multi Coach Join B",
      role: "coach",
      status: "pending",
      school: schoolId,
      team_name: teamA.name,
      join_team_id: teamA.id,
    })) as { id: string };
    createdIds.push({ collection: "users", id: coachB.id });

    // A join request should exist for coach B on team A.
    const joinRequests = await pbList(
      "join_requests",
      `user = '${coachB.id}' && team = '${teamA.id}'`
    );
    expect(joinRequests).toHaveLength(1);
    const jr = joinRequests[0] as { id: string; status: string };
    createdIds.push({ collection: "join_requests", id: jr.id });
    expect(jr.status).toBe("pending");

    // No duplicate team should have been created.
    const allTeams = await pbList("teams", `coaches ~ '${coachA.id}'`);
    expect(allTeams).toHaveLength(1);
  });

  test("deleting sole coach on a pending team is blocked with 400", async () => {
    const coach = (await pbCreate("users", {
      email: "pw-multi-coach-del@test.invalid",
      password: "testpass123",
      passwordConfirm: "testpass123",
      name: "PW Multi Coach Del",
      role: "coach",
      status: "pending",
      school: schoolId,
      team_name: "PW Multi Coach Del Team",
    })) as { id: string };
    // Push coach before team — reversed cleanup deletes team first so the
    // sole-coach guard no longer blocks the coach delete.
    createdIds.push({ collection: "users", id: coach.id });

    const teams = await pbList("teams", `coaches ~ '${coach.id}'`);
    expect(teams).toHaveLength(1);
    const team = teams[0] as { id: string };
    createdIds.push({ collection: "teams", id: team.id });

    const status = await tryDeleteUser(coach.id);
    expect(status).toBe(400);
  });
});
