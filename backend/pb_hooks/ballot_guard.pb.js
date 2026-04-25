/// <reference path="../pb_data/types.d.ts" />

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/**
 * Validate a scorer token on ballot create.
 *
 * @param {object} opts
 * @param {string} opts.tokenId       - ID from the submitted record
 * @param {string} opts.trialId       - trial ID from the submitted record
 * @param {string} opts.expectedRole  - "scorer" or "presider"
 * @param {string} opts.collection    - collection name for dup check
 * @param {string} opts.wrongRoleMsg  - error message when role is wrong
 * @param {string} opts.dupErrorMsg   - error message on duplicate submission
 */
function validateScorerToken({ tokenId, trialId, expectedRole, collection, wrongRoleMsg, dupErrorMsg }) {
    let token;
    try {
        token = $app.findRecordById("scorer_tokens", tokenId);
    } catch (_) {
        throw new BadRequestError("Invalid scorer token.");
    }

    if (token.get("status") !== "active") {
        throw new BadRequestError(
            "Scorer token has already been used or has been revoked."
        );
    }

    if (token.get("trial") !== trialId) {
        throw new BadRequestError(
            "Scorer token does not belong to this trial."
        );
    }

    if (token.get("scorer_role") !== expectedRole) {
        throw new BadRequestError(wrongRoleMsg);
    }

    // Belt-and-suspenders dup check; the unique relation field on
    // scorer_token also enforces this at the DB level.
    const existing = $app.findRecordsByFilter(
        collection,
        "scorer_token = {:tokenId}",
        "",
        1,
        0,
        { tokenId }
    );
    if (existing.length > 0) {
        throw new BadRequestError(dupErrorMsg);
    }
}

/**
 * Mark a scorer token as used after the ballot record commits.
 * Logs on failure but does not throw — the ballot is already safe.
 *
 * @param {string} tokenId - ID of the scorer_token record
 * @param {string} label   - "scorer" or "presider" (for log messages)
 */
function markTokenUsed(tokenId, label) {
    try {
        const token = $app.findRecordById("scorer_tokens", tokenId);
        token.set("status", "used");
        $app.save(token);
    } catch (err) {
        console.error(
            "[ballot_guard] Failed to mark " + label + " token as used: " +
            tokenId + " — " + err
        );
    }
}

// ---------------------------------------------------------------------------
// ballot_submissions
// ---------------------------------------------------------------------------

// Validates scorer token on ballot_submissions create.
// Ensures: token exists, is active, belongs to the correct trial,
// and has scorer role (not presider). Marks token as used atomically.
onRecordCreateRequest((e) => {
    const submission = e.record;
    validateScorerToken({
        tokenId: submission.get("scorer_token"),
        trialId: submission.get("trial"),
        expectedRole: "scorer",
        collection: "ballot_submissions",
        wrongRoleMsg:
            "This token is for the presider, not a scorer. " +
            "Use the presider ballot form.",
        dupErrorMsg: "A ballot has already been submitted for this token.",
    });
    return e.next();
}, "ballot_submissions");


// Marks the scorer token as used after the ballot submission commits.
onRecordAfterCreateSuccess((e) => {
    markTokenUsed(e.record.get("scorer_token"), "scorer");
}, "ballot_submissions");

// ---------------------------------------------------------------------------
// presider_ballots
// ---------------------------------------------------------------------------

// Validates scorer token on presider_ballots create.
// Ensures: token exists, is active, belongs to the correct trial,
// and has presider role.
onRecordCreateRequest((e) => {
    const ballot = e.record;
    validateScorerToken({
        tokenId: ballot.get("scorer_token"),
        trialId: ballot.get("trial"),
        expectedRole: "presider",
        collection: "presider_ballots",
        wrongRoleMsg:
            "This token is for a scorer, not the presider. " +
            "Use the scorer ballot form.",
        dupErrorMsg:
            "A presider ballot has already been submitted for this token.",
    });
    return e.next();
}, "presider_ballots");


// Marks the presider token as used after the presider ballot commits.
onRecordAfterCreateSuccess((e) => {
    markTokenUsed(e.record.get("scorer_token"), "presider");
}, "presider_ballots");
