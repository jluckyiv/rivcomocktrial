/// <reference path="../pb_data/types.d.ts" />

const REGISTRATION_STATUS = "registration";

// Pre-commit: verify a registration-status tournament exists before
// creating the user record. Throws BadRequestError if registration is
// closed so the coach never becomes an orphaned account.
onRecordCreateRequest((e) => {
    const user = e.record;

    if (user.get("role") !== "coach") {
        return e.next();
    }

    const tournaments = $app.findRecordsByFilter(
        "tournaments",
        "status = {:status}",
        "-created",
        2,
        0,
        { status: REGISTRATION_STATUS }
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
    const user = e.record;

    if (user.get("role") !== "coach") {
        return;
    }

    const tournaments = $app.findRecordsByFilter(
        "tournaments",
        "status = {:status}",
        "-created",
        1,
        0,
        { status: REGISTRATION_STATUS }
    );

    const tournament = tournaments[0];
    const teamsCollection = $app.findCollectionByNameOrId("teams");
    const team = new Record(teamsCollection);

    team.set("tournament", tournament.id);
    team.set("school", user.get("school"));
    team.set("name", user.get("team_name"));
    team.set("coach", user.id);
    team.set("status", "pending");

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
    const user = e.record;

    if (user.get("role") !== "coach") {
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
    const user = e.record;

    if (user.get("role") !== "coach") {
        return;
    }

    const status = user.get("status");
    let teamStatus;

    if (status === "approved") {
        teamStatus = "active";
    } else if (status === "rejected") {
        teamStatus = "rejected";
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
