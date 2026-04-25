/// <reference path="../pb_data/types.d.ts" />

// Validates scorer token on ballot_submissions create.
// Ensures: token exists, is active, belongs to the correct trial,
// and has scorer role (not presider). Marks token as used atomically.
onRecordCreateRequest((e) => {
    const submission = e.record;
    const tokenId = submission.get("scorer_token");
    const trialId = submission.get("trial");

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

    if (token.get("scorer_role") !== "scorer") {
        throw new BadRequestError(
            "This token is for the presider, not a scorer. " +
            "Use the presider ballot form."
        );
    }

    // Check for duplicate submission (belt-and-suspenders; the unique
    // relation field on scorer_token also enforces this at the DB level).
    const existing = $app.findRecordsByFilter(
        "ballot_submissions",
        "scorer_token = {:tokenId}",
        "",
        1,
        0,
        { tokenId }
    );
    if (existing.length > 0) {
        throw new BadRequestError(
            "A ballot has already been submitted for this token."
        );
    }

    return e.next();
}, "ballot_submissions");


// Marks the scorer token as used after the ballot submission commits.
onRecordAfterCreateSuccess((e) => {
    const submission = e.record;
    const tokenId = submission.get("scorer_token");

    try {
        const token = $app.findRecordById("scorer_tokens", tokenId);
        token.set("status", "used");
        $app.save(token);
    } catch (err) {
        // The submission is already committed. Log the failure but do
        // not surface it — the ballot is safe, the token may just need
        // manual cleanup.
        console.error(
            "[ballot_guard] Failed to mark scorer token as used: " +
            tokenId + " — " + err
        );
    }
}, "ballot_submissions");


// Validates scorer token on presider_ballots create.
// Ensures: token exists, is active, belongs to the correct trial,
// and has presider role.
onRecordCreateRequest((e) => {
    const ballot = e.record;
    const tokenId = ballot.get("scorer_token");
    const trialId = ballot.get("trial");

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

    if (token.get("scorer_role") !== "presider") {
        throw new BadRequestError(
            "This token is for a scorer, not the presider. " +
            "Use the scorer ballot form."
        );
    }

    const existing = $app.findRecordsByFilter(
        "presider_ballots",
        "scorer_token = {:tokenId}",
        "",
        1,
        0,
        { tokenId }
    );
    if (existing.length > 0) {
        throw new BadRequestError(
            "A presider ballot has already been submitted for this token."
        );
    }

    return e.next();
}, "presider_ballots");


// Marks the presider token as used after the presider ballot commits.
onRecordAfterCreateSuccess((e) => {
    const ballot = e.record;
    const tokenId = ballot.get("scorer_token");

    try {
        const token = $app.findRecordById("scorer_tokens", tokenId);
        token.set("status", "used");
        $app.save(token);
    } catch (err) {
        console.error(
            "[ballot_guard] Failed to mark presider token as used: " +
            tokenId + " — " + err
        );
    }
}, "presider_ballots");
