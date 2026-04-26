/// <reference path="../pb_data/types.d.ts" />
// Public endpoint that returns the primary RCOE contact email and
// name. Reads from `_superusers` server-side using `$app` (admin
// privileges) so we don't have to expose the whole superusers
// collection publicly.
//
// GET /api/contact -> { email: string, name: string }
//
// If no superuser is flagged `is_primary_contact`, falls back to
// the first superuser by creation date.
routerAdd("GET", "/api/contact", (e) => {
    let record;

    try {
        const flagged = $app.findRecordsByFilter(
            "_superusers",
            "is_primary_contact = true",
            "-created",
            1,
            0
        );
        record = flagged[0];
    } catch (_) {
        record = undefined;
    }

    if (!record) {
        const all = $app.findRecordsByFilter("_superusers", "", "created", 1, 0);
        record = all[0];
    }

    if (!record) {
        return e.json(404, { error: "No superusers configured." });
    }

    return e.json(200, {
        email: record.get("email"),
        name: record.get("name") || "",
    });
});
