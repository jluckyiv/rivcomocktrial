/// <reference path="../pb_data/types.d.ts" />
// Public endpoint: returns the existing team id when a name+school
// collision exists in the active registration tournament.
//
// GET /api/teams/check-collision?name=...&school=...
//   -> { existingTeamId: string } when a team matches
//   -> { existingTeamId: null }   when no match (or no open tournament)
//
// Used by the SvelteKit registration server action after catching the
// hook's BadRequestError — the hook's response data does not preserve
// the raw id (PB normalizes BadRequestError data values), so we need
// a separate lookup to surface the id to the client dialog.
routerAdd("GET", "/api/teams/check-collision", (e) => {
    const name = e.request.url.query().get("name") || "";
    const school = e.request.url.query().get("school") || "";

    if (!name || !school) {
        return e.json(200, { existingTeamId: null });
    }

    try {
        const tournaments = $app.findRecordsByFilter(
            "tournaments",
            "status = 'registration'",
            "-created",
            1,
            0
        );

        if (tournaments.length === 0) {
            return e.json(200, { existingTeamId: null });
        }

        const tournament = tournaments[0];

        const teams = $app.findRecordsByFilter(
            "teams",
            "name = {:name} && school = {:school} && tournament = {:tournament}",
            "",
            1,
            0,
            { name, school, tournament: tournament.id }
        );

        return e.json(200, { existingTeamId: teams.length > 0 ? teams[0].id : null });
    } catch (_) {
        return e.json(200, { existingTeamId: null });
    }
});
