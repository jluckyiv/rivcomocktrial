/// <reference path="../pb_data/types.d.ts" />

// When a withdrawal request is approved, set the team status to "withdrawn".
onRecordAfterUpdateSuccess((e) => {
    const req = e.record;

    if (req.get("status") !== "approved") {
        return;
    }

    const teamId = req.get("team");

    let team;
    try {
        team = $app.findRecordById("teams", teamId);
    } catch (_) {
        console.error(
            "[withdrawal] Team not found for withdrawal request " + req.id
        );
        return;
    }

    team.set("status", "withdrawn");
    try {
        $app.save(team);
    } catch (err) {
        console.error(
            "[withdrawal] Failed to save team status for request " + req.id + " — " + err
        );
    }
}, "withdrawal_requests");
