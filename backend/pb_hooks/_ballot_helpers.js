/// <reference path="../pb_data/types.d.ts" />
// Shared helpers for ballot_guard.pb.js.
// Required inside each callback because PB v0.36 JSVM runs callbacks
// in a fresh VM context where top-level declarations are not in scope.

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

module.exports = { validateScorerToken, markTokenUsed };
