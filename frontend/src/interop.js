import "./catppuccin.css"

export const flags = ({ env }) => {
    return {
        adminToken: localStorage.getItem("adminToken") || null
    }
}

export const onReady = ({ app, env }) => {
    if (app.ports && app.ports.outgoing) {
        app.ports.outgoing.subscribe(({ tag, data }) => {
            switch (tag) {
                case "SaveAdminToken":
                    if (data) {
                        localStorage.setItem("adminToken", data)
                    } else {
                        localStorage.removeItem("adminToken")
                    }
                    break
            }
        })
    }
}
