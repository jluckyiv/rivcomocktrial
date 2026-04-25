/// <reference path="../pb_data/types.d.ts" />

// When a withdrawal request is approved, set the team status to "withdrawn".
onRecordAfterUpdateSuccess((e) => {
    const req = e.record;

    if (req.get("status") !== "approved") {
        return;
    }

    const teamId = req.get("team");

    const teams = $app.findRecordsByFilter(
        "teams",
        "id = '" + teamId + "'",
        "",
        1,
        0
    );

    if (teams.length === 0) {
        console.error(
            "[withdrawal] Team not found for withdrawal request " + req.id
        );
        return;
    }

    const team = teams[0];
    team.set("status", "withdrawn");
    $app.save(team);
}, "withdrawal_requests");
