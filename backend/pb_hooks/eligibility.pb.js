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
            "team = {:teamId} && name = {:studentName} && status = 'active'",
            "",
            1,
            0,
            { teamId, studentName }
        );

        for (const entry of entries) {
            entry.set("status", "removed");
            try {
                $app.save(entry);
            } catch (err) {
                console.error(
                    "[eligibility] Failed to save entry removal for request " + req.id + " — " + err
                );
            }
        }
    } else if (changeType === "add") {
        // Look up the team by its primary key.
        let team;
        try {
            team = $app.findRecordById("teams", teamId);
        } catch (_) {
            console.error(
                "[eligibility] Team not found for change request " + req.id
            );
            return;
        }

        const col = $app.findCollectionByNameOrId("eligibility_list_entries");
        const entry = new Record(col);
        entry.set("team", teamId);
        entry.set("tournament", team.get("tournament"));
        entry.set("name", studentName);
        entry.set("status", "active");
        try {
            $app.save(entry);
        } catch (err) {
            console.error(
                "[eligibility] Failed to save new entry for request " + req.id + " — " + err
            );
        }
    }
}, "eligibility_change_requests");
