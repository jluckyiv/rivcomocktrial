/// <reference path="../pb_data/types.d.ts" />

// When an eligibility change request is approved, apply the change
// to the eligibility_list_entries collection.
onRecordAfterUpdateSuccess((e) => {
    const req = e.record;

    if (req.get("status") !== "approved") {
        return;
    }

    const teamId = req.get("team");
    const studentName = req.get("student_name");
    const changeType = req.get("change_type");

    if (changeType === "remove") {
        // Mark matching active entry as removed.
        const entries = $app.findRecordsByFilter(
            "eligibility_list_entries",
            "team = '" + teamId + "' && name = '" + studentName + "' && status = 'active'",
            "",
            1,
            0
        );

        for (const entry of entries) {
            entry.set("status", "removed");
            $app.save(entry);
        }
    } else if (changeType === "add") {
        // Find the team to get its tournament ID.
        const teams = $app.findRecordsByFilter(
            "teams",
            "id = '" + teamId + "'",
            "",
            1,
            0
        );

        if (teams.length === 0) {
            console.error(
                "[eligibility] Team not found for change request " + req.id
            );
            return;
        }

        const col = $app.findCollectionByNameOrId("eligibility_list_entries");
        const entry = new Record(col);
        entry.set("team", teamId);
        entry.set("tournament", teams[0].get("tournament"));
        entry.set("name", studentName);
        entry.set("status", "active");
        $app.save(entry);
    }
}, "eligibility_change_requests");
