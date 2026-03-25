/// <reference path="../pb_data/types.d.ts" />

// Block login for coaches whose registration has not
// been approved. Runs after password verification
// succeeds but before the token is returned.
onRecordAuthRequest((e) => {
    const status = e.record?.get("status")

    // Non-coach users (no status field) pass through.
    if (!status) {
        return e.next()
    }

    if (status === "approved") {
        return e.next()
    }

    if (status === "pending") {
        throw new ForbiddenError(
            "Your registration is pending admin approval."
        )
    }

    if (status === "rejected") {
        throw new ForbiddenError(
            "Your registration has been rejected."
            + " Please contact the organizer."
        )
    }

    // Unknown status — block by default.
    throw new ForbiddenError(
        "Your account is not active."
    )
}, "users")
