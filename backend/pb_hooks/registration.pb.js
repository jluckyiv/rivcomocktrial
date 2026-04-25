/// <reference path="../pb_data/types.d.ts" />

// When a coach registers, find the active registration tournament
// and create the pending team record. Runs after the user record
// is committed so the coach relation resolves correctly.
onRecordAfterCreateSuccess((e) => {
    const user = e.record;

    if (user.get("role") !== "coach") {
        return;
    }

    const tournaments = $app.findRecordsByFilter(
        "tournaments",
        "status = 'registration'",
        "-created",
        1,
        0
    );

    if (tournaments.length === 0) {
        // Registration was closed between the frontend check and
        // submission. Log and return — the user record is committed;
        // RCOE will need to manually associate a team.
        console.error(
            "[registration] No registration-status tournament found "
            + "while creating team for user " + user.id
        );
        return;
    }

    const tournament = tournaments[0];
    const teamsCollection = $app.findCollectionByNameOrId("teams");
    const team = new Record(teamsCollection);

    team.set("tournament", tournament.id);
    team.set("school", user.get("school"));
    team.set("name", user.get("team_name"));
    team.set("coach", user.id);
    team.set("status", "pending");

    $app.save(team);
}, "users");


// When a coach is deleted, remove all associated team records.
onRecordAfterDeleteSuccess((e) => {
    const user = e.record;

    if (user.get("role") !== "coach") {
        return;
    }

    const teams = $app.findRecordsByFilter(
        "teams",
        "coach = '" + user.id + "'",
        "",
        100,
        0
    );

    for (const team of teams) {
        $app.delete(team);
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
        "coach = '" + user.id + "' && status = 'pending'",
        "",
        100,
        0
    );

    for (const team of teams) {
        team.set("status", teamStatus);
        $app.save(team);
    }
}, "users");
