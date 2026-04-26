/// <reference path="../pb_data/types.d.ts" />

// Note: PocketBase v0.36 JSVM runs each hook callback in a fresh
// VM context, so top-level declarations are NOT visible inside the
// callbacks. Helper functions live in _ballot_helpers.js and are
// required inside each callback.

// ---------------------------------------------------------------------------
// ballot_submissions
// ---------------------------------------------------------------------------

// Validates scorer token on ballot_submissions create.
// Ensures: token exists, is active, belongs to the correct trial,
// and has scorer role (not presider). Marks token as used atomically.
onRecordCreateRequest((e) => {
    const { validateScorerToken } = require(`${__hooks}/_ballot_helpers.js`);
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
    const { markTokenUsed } = require(`${__hooks}/_ballot_helpers.js`);
    markTokenUsed(e.record.get("scorer_token"), "scorer");
}, "ballot_submissions");

// ---------------------------------------------------------------------------
// presider_ballots
// ---------------------------------------------------------------------------

// Validates scorer token on presider_ballots create.
// Ensures: token exists, is active, belongs to the correct trial,
// and has presider role.
onRecordCreateRequest((e) => {
    const { validateScorerToken } = require(`${__hooks}/_ballot_helpers.js`);
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
    const { markTokenUsed } = require(`${__hooks}/_ballot_helpers.js`);
    markTokenUsed(e.record.get("scorer_token"), "presider");
}, "presider_ballots");
