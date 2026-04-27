/// <reference path="../pb_data/types.d.ts" />
// Shared constants for hook files. The leading underscore prevents
// PocketBase from auto-loading this as a hook file (`*.pb.js`).
// Hooks `require("./_constants.js")` inside their callbacks because
// PocketBase v0.36 runs each callback in a fresh VM context and
// top-level declarations from the hook file itself are NOT visible.

module.exports = {
    TOURNAMENT_STATUS: {
        DRAFT: "draft",
        REGISTRATION: "registration",
        ACTIVE: "active",
        COMPLETED: "completed",
    },
    USER_ROLE: {
        COACH: "coach",
    },
    USER_STATUS: {
        PENDING: "pending",
        APPROVED: "approved",
        REJECTED: "rejected",
    },
    ELIGIBILITY_STATUS: {
        PENDING: "pending",
        ELIGIBLE: "eligible",
        INELIGIBLE: "ineligible",
        WITHDRAWN: "withdrawn",
    },
    JOIN_REQUEST_STATUS: {
        PENDING: "pending",
        APPROVED: "approved",
        REJECTED: "rejected",
    },
};
