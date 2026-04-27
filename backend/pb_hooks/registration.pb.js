/// <reference path="../pb_data/types.d.ts" />

// Note: PocketBase v0.36 JSVM runs each hook callback in a fresh
// VM context, so top-level `const`s are NOT visible inside the
// callbacks. Use `require()` inside the callback instead.

// Pre-commit: verify a registration-status tournament exists and handle
// name+school+tournament collisions before the user record is created.
//
// Superuser-authenticated requests bypass the public-flow guard so
// admins can seed, restore, or back-fill coach records outside an
// active registration window.
onRecordCreateRequest((e) => {
    const { TOURNAMENT_STATUS, USER_ROLE } = require(`${__hooks}/_constants.js`);
    const user = e.record;

    if (user.get("role") !== USER_ROLE.COACH) {
        return e.next();
    }

    if (e.hasSuperuserAuth()) {
        // Admin-driven coach creates skip the public-flow guards. But
        // when the body requests team auto-creation (team_name +/or
        // school), the post-commit hook needs an active registration
        // tournament to attach the team to. Fail fast here with a
        // clear error rather than letting the post-commit silently
        // roll back the user record on a tournament.id throw.
        const teamName = user.get("team_name");
        const school = user.get("school");
        if (teamName || school) {
            const tournaments = $app.findRecordsByFilter(
                "tournaments",
                "status = {:status}",
                "-created",
                1,
                0,
                { status: TOURNAMENT_STATUS.REGISTRATION }
            );
            if (tournaments.length === 0) {
                throw new BadRequestError(
                    "Cannot auto-create team: no tournament is in registration status. " +
                    "Either set a tournament to \'registration\' or omit team_name/school " +
                    "to skip team creation."
                );
            }
        }
        return e.next();
    }

    const tournaments = $app.findRecordsByFilter(
        "tournaments",
        "status = {:status}",
        "-created",
        2,
        0,
        { status: TOURNAMENT_STATUS.REGISTRATION }
    );

    if (tournaments.length === 0) {
        throw new BadRequestError(
            "Registration is not currently open. " +
            "No active registration tournament found."
        );
    }

    if (tournaments.length > 1) {
        console.warn(
            "[registration] More than one registration-status tournament found. " +
            "Using the most recently created: " + tournaments[0].id
        );
    }

    const tournament = tournaments[0];
    const joinTeamId = e.requestInfo().body["join_team_id"];

    // Check for name+school+tournament collision.
    const school = user.get("school");
    const teamName = user.get("team_name");
    const existing = $app.findRecordsByFilter(
        "teams",
        "name = {:name} && school = {:school} && tournament = {:tournament}",
        "",
        1,
        0,
        { name: teamName, school: school, tournament: tournament.id }
    );

    if (existing.length > 0) {
        const existingTeam = existing[0];
        if (!joinTeamId) {
            // Collision with no join intent: tell the client which team exists.
            throw new BadRequestError(
                "A team with this name already exists at your school. " +
                "Choose a different name, or request to join the existing team.",
                { existingTeamId: existingTeam.id }
            );
        }
        if (joinTeamId !== existingTeam.id) {
            throw new BadRequestError(
                "The team ID does not match the existing team at your school."
            );
        }
        // join_team_id matches the collision — stash on the record so the
        // post-commit hook can read it (requestInfo is not available there).
        e.record.set("_join_team_id", existingTeam.id);
    } else if (joinTeamId) {
        // join_team_id provided but no collision — ignore it and create a new team.
        console.warn(
            "[registration] join_team_id provided but no name+school collision found. " +
            "Creating new team instead."
        );
    }

    return e.next();
}, "users");


// Post-commit: create a pending team + eligibility row, or a join request.
//
// Reads team intent from the record itself rather than checking who
// authenticated. Public registrations always carry team_name + school
// (the form requires them); admin seeds/restores typically do not.
// Skipping when no team intent is present means admin-driven creates
// (e.g. staging smoke seeds) don't accidentally trigger team creation
// — and don't fall over when no registration tournament exists.
onRecordAfterCreateSuccess((e) => {
    const { TOURNAMENT_STATUS, USER_ROLE, ELIGIBILITY_STATUS, JOIN_REQUEST_STATUS } =
        require(`${__hooks}/_constants.js`);
    const user = e.record;

    if (user.get("role") !== USER_ROLE.COACH) {
        return;
    }

    const teamName = user.get("team_name");
    const school = user.get("school");
    // requestInfo is not available on RecordEvent; join intent was stashed on
    // the record in the pre-commit hook via e.record.set("_join_team_id", ...).
    const joinTeamId = user.get("_join_team_id") || null;

    if (!teamName && !school && !joinTeamId) {
        return;
    }

    const tournaments = $app.findRecordsByFilter(
        "tournaments",
        "status = {:status}",
        "-created",
        1,
        0,
        { status: TOURNAMENT_STATUS.REGISTRATION }
    );

    const tournament = tournaments[0];

    if (joinTeamId) {
        // Join-existing path: create a pending join request.
        const joinRequestsCollection = $app.findCollectionByNameOrId("join_requests");
        const joinRequest = new Record(joinRequestsCollection);
        joinRequest.set("user", user.id);
        joinRequest.set("team", joinTeamId);
        joinRequest.set("status", JOIN_REQUEST_STATUS.PENDING);

        try {
            $app.save(joinRequest);
        } catch (err) {
            console.error(
                "[registration] Failed to save join request for user " +
                user.id + " — rolling back user record. Error: " + err
            );
            try {
                $app.delete(user);
            } catch (deleteErr) {
                console.error(
                    "[registration] Failed to delete orphaned user " +
                    user.id + " — manual cleanup required. Error: " + deleteErr
                );
            }
        }
        return;
    }

    // New-team path: create a team linked to this coach.
    const teamsCollection = $app.findCollectionByNameOrId("teams");
    const team = new Record(teamsCollection);

    team.set("tournament", tournament.id);
    team.set("school", user.get("school"));
    team.set("name", user.get("team_name"));
    team.set("coaches", [user.id]);

    try {
        $app.save(team);
    } catch (err) {
        console.error(
            "[registration] Failed to save team for user " + user.id +
            " — rolling back user record. Error: " + err
        );
        try {
            $app.delete(user);
        } catch (deleteErr) {
            console.error(
                "[registration] Failed to delete orphaned user " +
                user.id + " — manual cleanup required. Error: " + deleteErr
            );
        }
        return;
    }

    // Create the per-tournament eligibility record.
    const tournamentsTeamsCollection = $app.findCollectionByNameOrId("tournaments_teams");
    const eligibilityRow = new Record(tournamentsTeamsCollection);
    eligibilityRow.set("team", team.id);
    eligibilityRow.set("tournament", tournament.id);
    eligibilityRow.set("status", ELIGIBILITY_STATUS.PENDING);

    try {
        $app.save(eligibilityRow);
    } catch (err) {
        console.error(
            "[registration] Failed to save tournaments_teams for team " + team.id +
            " — rolling back team and user records. Error: " + err
        );
        try {
            $app.delete(team);
        } catch (deleteErr) {
            console.error("[registration] Failed to delete orphaned team " + team.id + ": " + deleteErr);
        }
        try {
            $app.delete(user);
        } catch (deleteErr) {
            console.error("[registration] Failed to delete orphaned user " + user.id + ": " + deleteErr);
        }
    }
}, "users");


// Pre-delete: block coach deletion if they are the sole coach on any
// team that is currently enrolled (pending or eligible) in a tournament.
// The caller must add another coach or withdraw the team first.
onRecordDeleteRequest((e) => {
    const { USER_ROLE } = require(`${__hooks}/_constants.js`);
    const user = e.record;

    if (user.get("role") !== USER_ROLE.COACH) {
        return e.next();
    }

    const eligibilityRows = $app.findRecordsByFilter(
        "tournaments_teams",
        "team.coaches ~ {:coachId} && (status = \'pending\' || status = \'eligible\')",
        "",
        100,
        0,
        { coachId: user.id }
    );

    for (const row of eligibilityRows) {
        const teamId = row.get("team");
        const team = $app.findRecordById("teams", teamId);
        const coaches = team.getStringSlice("coaches");
        if (coaches.length <= 1) {
            throw new BadRequestError(
                `Cannot delete coach: sole coach on team "${team.get("name")}". ` +
                "Add another coach or withdraw the team first."
            );
        }
    }

    return e.next();
}, "users");


// When a coach's enrollment is approved or rejected, sync the eligibility
// of their pending tournament enrollments. Runs after the user record commits.
onRecordAfterUpdateSuccess((e) => {
    const { USER_ROLE, USER_STATUS, ELIGIBILITY_STATUS } = require(`${__hooks}/_constants.js`);
    const user = e.record;

    if (user.get("role") !== USER_ROLE.COACH) {
        return;
    }

    const status = user.get("status");
    let eligibilityStatus;

    if (status === USER_STATUS.APPROVED) {
        eligibilityStatus = ELIGIBILITY_STATUS.ELIGIBLE;
    } else if (status === USER_STATUS.REJECTED) {
        eligibilityStatus = ELIGIBILITY_STATUS.INELIGIBLE;
    } else {
        return;
    }

    // Only update pending eligibility rows. Eligible, withdrawn, or
    // ineligible rows must not be touched if the coach record is updated later.
    const eligibilityRows = $app.findRecordsByFilter(
        "tournaments_teams",
        "team.coaches ~ {:coachId} && status = \'pending\'",
        "",
        100,
        0,
        { coachId: user.id }
    );

    for (const row of eligibilityRows) {
        row.set("status", eligibilityStatus);
        try {
            $app.save(row);
        } catch (err) {
            console.error(
                "[registration] Failed to save eligibility status for tournaments_teams " +
                row.id + " — " + err
            );
        }
    }
}, "users");
