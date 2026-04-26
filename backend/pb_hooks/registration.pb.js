/// <reference path="../pb_data/types.d.ts" />

// Note: PocketBase v0.36 JSVM runs each hook callback in a fresh
// VM context, so top-level `const`s are NOT visible inside the
// callbacks. Use `require()` inside the callback instead.

// Pre-commit: verify a registration-status tournament exists before
// creating the user record. Throws BadRequestError if registration is
// closed so the coach never becomes an orphaned account.
onRecordCreateRequest((e) => {
    const { TOURNAMENT_STATUS, USER_ROLE } = require(`${__hooks}/_constants.js`);
    const user = e.record;

    if (user.get("role") !== USER_ROLE.COACH) {
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

    return e.next();
}, "users");


// Post-commit: create the pending team record after the user record
// is committed so the coach relation resolves correctly.
onRecordAfterCreateSuccess((e) => {
    const { TOURNAMENT_STATUS, USER_ROLE, TEAM_STATUS } = require(`${__hooks}/_constants.js`);
    const user = e.record;

    if (user.get("role") !== USER_ROLE.COACH) {
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
    const teamsCollection = $app.findCollectionByNameOrId("teams");
    const team = new Record(teamsCollection);

    team.set("tournament", tournament.id);
    team.set("school", user.get("school"));
    team.set("name", user.get("team_name"));
    team.set("coach", user.id);
    team.set("status", TEAM_STATUS.PENDING);

    try {
        $app.save(team);
    } catch (err) {
        console.error(
            "[registration] Failed to save team for user " + user.id + " — " + err
        );
    }
}, "users");


// When a coach is deleted, remove all associated team records.
onRecordAfterDeleteSuccess((e) => {
    const { USER_ROLE } = require(`${__hooks}/_constants.js`);
    const user = e.record;

    if (user.get("role") !== USER_ROLE.COACH) {
        return;
    }

    const teams = $app.findRecordsByFilter(
        "teams",
        "coach = {:coachId}",
        "",
        100,
        0,
        { coachId: user.id }
    );

    for (const team of teams) {
        try {
            $app.delete(team);
        } catch (err) {
            console.error(
                "[registration] Failed to delete team " + team.id + " — " + err
            );
        }
    }
}, "users");


// When a coach's status changes to approved or rejected, sync
// the linked team's status. Runs after the user record commits.
onRecordAfterUpdateSuccess((e) => {
    const { USER_ROLE, USER_STATUS, TEAM_STATUS } = require(`${__hooks}/_constants.js`);
    const user = e.record;

    if (user.get("role") !== USER_ROLE.COACH) {
        return;
    }

    const status = user.get("status");
    let teamStatus;

    if (status === USER_STATUS.APPROVED) {
        teamStatus = TEAM_STATUS.ACTIVE;
    } else if (status === USER_STATUS.REJECTED) {
        teamStatus = TEAM_STATUS.REJECTED;
    } else {
        return;
    }

    // Only promote/reject pending teams. Active or withdrawn teams
    // must not be touched if the coach record is updated later.
    const teams = $app.findRecordsByFilter(
        "teams",
        "coach = {:coachId} && status = 'pending'",
        "",
        100,
        0,
        { coachId: user.id }
    );

    for (const team of teams) {
        team.set("status", teamStatus);
        try {
            $app.save(team);
        } catch (err) {
            console.error(
                "[registration] Failed to save team status " + team.id + " — " + err
            );
        }
    }
}, "users");
