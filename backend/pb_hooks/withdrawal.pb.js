/// <reference path="../pb_data/types.d.ts" />

// When a withdrawal request is approved, set the tournaments_teams eligibility
// status to "withdrawn" for the team's originating tournament.
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

    const tournamentId = team.get("tournament");
    if (!tournamentId) {
        console.error(
            "[withdrawal] Team " + teamId + " has no tournament FK — cannot update eligibility."
        );
        return;
    }

    let ttRow;
    try {
        ttRow = $app.findFirstRecordByFilter(
            "tournaments_teams",
            "team = {:teamId} && tournament = {:tournamentId}",
            { teamId, tournamentId }
        );
    } catch (_) {
        console.error(
            "[withdrawal] No tournaments_teams row for team " + teamId + " in tournament " + tournamentId
        );
        return;
    }

    ttRow.set("status", "withdrawn");
    try {
        $app.save(ttRow);
    } catch (err) {
        console.error(
            "[withdrawal] Failed to save tournaments_teams status for request " + req.id + " — " + err
        );
    }
}, "withdrawal_requests");
