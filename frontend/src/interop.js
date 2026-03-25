// PocketBase JS SDK is the sole client for all PB operations.
// See ADR-010 in docs/decisions.md for rationale.
//
// Two SDK instances: pbAdmin (superuser auth) and pb (coach/public).
// Auth tokens are persisted to localStorage manually; SDK auth
// stores are in-memory only to avoid key conflicts.

import "./app.css"
import PocketBase from "pocketbase"

const pb = new PocketBase(window.location.origin)
const pbAdmin = new PocketBase(window.location.origin)

// Disable SDK auto-persistence (we manage localStorage ourselves)
pb.autoCancellation(false)
pbAdmin.autoCancellation(false)

// Restore admin auth from localStorage on load
const savedAdminToken = localStorage.getItem("adminToken")
if (savedAdminToken) {
    pbAdmin.authStore.save(savedAdminToken, { id: "admin" })
}

// Restore coach auth from localStorage on load
const savedCoachToken = localStorage.getItem("coachToken")
if (savedCoachToken) {
    try {
        const savedCoachUser = JSON.parse(
            localStorage.getItem("coachUser") || "{}"
        )
        pb.authStore.save(savedCoachToken, savedCoachUser)
    } catch {
        // Corrupted localStorage data; ignore
    }
}

export const flags = ({ env }) => {
    const coachUser = (() => {
        try {
            const raw = localStorage.getItem("coachUser")
            return raw ? JSON.parse(raw) : null
        } catch {
            return null
        }
    })()

    return {
        adminToken: localStorage.getItem("adminToken") || null,
        coachToken: localStorage.getItem("coachToken") || null,
        coachUser,
    }
}

export const onReady = ({ app, env }) => {
    const send = (tag, data) => {
        if (app.ports.incoming) {
            app.ports.incoming.send({ tag, data })
        }
    }

    const sendError = (tag, err) => {
        const message = err?.message || String(err)
        if (app.ports.incoming) {
            app.ports.incoming.send({ tag, error: message })
        }
    }

    if (app.ports && app.ports.outgoing) {
        app.ports.outgoing.subscribe(({ tag, data }) => {
            switch (tag) {
                case "PbSend":
                    handlePbSend(data, send, sendError)
                    break

                case "SaveAdminToken":
                    if (data) {
                        localStorage.setItem("adminToken", data)
                        pbAdmin.authStore.save(data, {
                            id: "admin",
                        })
                    } else {
                        localStorage.removeItem("adminToken")
                        pbAdmin.authStore.clear()
                    }
                    break

                case "SaveCoachToken":
                    if (data) {
                        localStorage.setItem("coachToken", data)
                    } else {
                        localStorage.removeItem("coachToken")
                        localStorage.removeItem("coachUser")
                        pb.authStore.clear()
                    }
                    break

                case "SaveCoachUser":
                    if (data) {
                        localStorage.setItem(
                            "coachUser",
                            JSON.stringify(data)
                        )
                    } else {
                        localStorage.removeItem("coachUser")
                    }
                    break
            }
        })
    }
}

function handlePbSend(data, send, sendError) {
    const { action, tag } = data
    const client = data.admin ? pbAdmin : pb

    switch (action) {
        case "list": {
            const options = {}
            if (data.filter) options.filter = data.filter
            if (data.sort) options.sort = data.sort
            client
                .collection(data.collection)
                .getList(1, data.perPage || 200, options)
                .then((result) => send(tag, result))
                .catch((err) => sendError(tag, err))
            break
        }

        case "create":
            client
                .collection(data.collection)
                .create(data.body)
                .then((record) => send(tag, record))
                .catch((err) => sendError(tag, err))
            break

        case "update":
            client
                .collection(data.collection)
                .update(data.id, data.body)
                .then((record) => send(tag, record))
                .catch((err) => sendError(tag, err))
            break

        case "delete":
            client
                .collection(data.collection)
                .delete(data.id)
                .then(() => send(tag, { id: data.id }))
                .catch((err) => sendError(tag, err))
            break

        case "adminLogin":
            pbAdmin
                .collection("_superusers")
                .authWithPassword(data.email, data.password)
                .then((auth) => {
                    localStorage.setItem(
                        "adminToken",
                        auth.token
                    )
                    send(tag, { token: auth.token })
                })
                .catch((err) => sendError(tag, err))
            break

        case "coachLogin":
            pb.collection("users")
                .authWithPassword(data.email, data.password)
                .then((auth) => {
                    const user = {
                        id: auth.record.id,
                        email: auth.record.email,
                        name: auth.record.name || "",
                    }
                    localStorage.setItem(
                        "coachToken",
                        auth.token
                    )
                    localStorage.setItem(
                        "coachUser",
                        JSON.stringify(user)
                    )
                    send(tag, {
                        token: auth.token,
                        record: auth.record,
                    })
                })
                .catch((err) => sendError(tag, err))
            break
    }
}
