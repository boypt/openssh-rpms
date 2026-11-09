package main

import (
	"fmt"
	"net/http"
)

const page = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>OpenSSH RPM Builder</title>
<style>
* { box-sizing: border-box; }
body {
    margin: 0;
    font-family: Arial, sans-serif;
    background: #0f172a;
    color: #e2e8f0;
}
.container {
    max-width: 900px;
    margin: 50px auto;
    padding: 30px;
}
.header { margin-bottom: 30px; }
.header h1 { margin-bottom: 8px; color: #38bdf8; }
.header p { color: #94a3b8; }
.card {
    background: #1e293b;
    border: 1px solid #334155;
    border-radius: 12px;
    padding: 25px;
}
.grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 20px;
}
label {
    display: block;
    margin-bottom: 8px;
    font-weight: bold;
}
input, select {
    width: 100%;
    padding: 12px;
    border-radius: 6px;
    border: 1px solid #475569;
    background: #0f172a;
    color: white;
}
button {
    margin-top: 25px;
    padding: 12px 22px;
    border: 0;
    border-radius: 6px;
    background: #0284c7;
    color: white;
    font-weight: bold;
    cursor: pointer;
}
button:hover { background: #0369a1; }
#result {
    margin-top: 20px;
    padding: 15px;
    background: #020617;
    border-radius: 6px;
    white-space: pre-wrap;
    display: none;
    overflow-wrap: anywhere;
}
.footer {
    margin-top: 25px;
    color: #64748b;
    font-size: 13px;
}
@media(max-width: 600px) {
    .grid { grid-template-columns: 1fr; }
}

.api-status {
    display: flex;
    align-items: center;
    gap: 12px;
    margin: 16px 0;
    flex-wrap: wrap;
}
.status {
    font-size: 14px;
    font-weight: bold;
}
.status.connected { color: #4ade80; }
.status.disconnected { color: #f87171; }
.status.checking { color: #facc15; }

</style>
</head>
<body>
<div class="container">
    <div class="header">
        <h1>OpenSSH RPM Builder</h1>
        <p>Build OpenSSH RPM packages for Enterprise Linux</p>
    </div>

    <div class="card">
        <h2>Build Configuration</h2>

        <div class="grid">
            <div>
                <label for="ssh">OpenSSH Version</label>
                <input id="ssh" value="10.6p2">
            </div>

            <div>
                <label for="ssl">OpenSSL Version</label>
                <input id="ssl" value="3.5.9">
            </div>

            <div>
                <label for="el">Target EL Version</label>
                <select id="el">
                    <option value="el5">EL 5</option>
                    <option value="el6">EL 6</option>
                    <option value="el7">EL 7</option>
                    <option value="el8">EL 8</option>
                    <option value="el9" selected>EL 9</option>
                </select>
            </div>

            <div>
                <label for="openssl">OpenSSL Mode</label>
                <select id="openssl">
                    <option value="0">Without OpenSSL (0)</option>
                    <option value="1" selected>System OpenSSL (1)</option>
                    <option value="2">Static OpenSSL (2)</option>
                </select>
            </div>
        </div>

        <div class="api-status">
            <span id="apiStatus" class="status checking">API: Checking...</span>
            <button type="button" onclick="loadVersions()">Refresh Versions</button>
        </div>

        <div class="actions">
            <button type="button" onclick="preview()">Preview Configuration</button>
            <button type="button" id="buildButton" onclick="startBuild()">Build RPMs</button>
        </div>

        <div id="result"></div>

        <div id="buildResult" style="display:none; margin-top:20px;">
            <h3 id="buildStatus">Build status</h3>
            <pre id="buildLog" style="white-space:pre-wrap; overflow:auto; max-height:400px;"></pre>
            <div id="downloads"></div>
        </div>
    </div>

    <div class="footer">
        OpenSSH RPM Builder — Build and download RPMs.
    </div>
</div>

<script>
async function loadVersions() {
    const status = document.getElementById("apiStatus");
    status.textContent = "API: Checking...";
    status.className = "status checking";

    try {
        const response = await fetch("/api/version", { cache: "no-store" });
        if (!response.ok) {
            throw new Error("API returned HTTP " + response.status);
        }

        const data = await response.json();
        if (!data.openssh_version || !data.openssl_version) {
            throw new Error("Version values are missing");
        }

        document.getElementById("ssh").value = data.openssh_version;
        document.getElementById("ssl").value = data.openssl_version;
        status.textContent = "API: Connected";
        status.className = "status connected";
    } catch (error) {
        status.textContent = "API: Disconnected — " + error.message;
        status.className = "status disconnected";
        console.error("Failed to load versions:", error);
    }
}

window.addEventListener("DOMContentLoaded", loadVersions);

function preview() {
    const ssh = document.getElementById("ssh").value.trim();
    const ssl = document.getElementById("ssl").value.trim();
    const el = document.getElementById("el").value;
    const openssl = document.getElementById("openssl").value;

    const specMap = {
        "el5": "el5",
        "el6": "el6",
        "el7": "el7",
        "el8": "el7",
        "el9": "el7"
    };

    const result = document.getElementById("result");
    result.style.display = "block";

    result.textContent =
        "Configuration Preview\n" +
        "---------------------\n" +
        "OpenSSH Version: " + ssh + "\n" +
        "OpenSSL Version: " + ssl + "\n" +
        "Target EL: " + el.toUpperCase() + "\n" +
        "Spec Directory: " + specMap[el] + "/\n" +
        "OpenSSL Mode: " + openssl + "\n\n" +
        "Proposed command (preview only):\n" +
        "WITH_OPENSSL=" + openssl + " ./compile.sh " + specMap[el] + "\n\n" +
        "No build has been started.\n\n" +
        "IMPORTANT: Target EL is a UI selection only.\n" +
        "compile.sh detects the actual EL from the build host.\n" +
        "OpenSSL Mode is included in the proposed command only; no build is executed.\n\n" +
        "Versions are loaded from version.env through the API.";
}

async function startBuild() {
    const button = document.getElementById("buildButton");
    const result = document.getElementById("buildResult");
    const status = document.getElementById("buildStatus");
    const log = document.getElementById("buildLog");
    const downloads = document.getElementById("downloads");

    const targetEL = document.getElementById("el").value;
    const opensslMode = document.getElementById("openssl").value;
    const opensshVersion = document.getElementById("ssh").value.trim();
    const opensslVersion = document.getElementById("ssl").value.trim();

    if (!opensshVersion || !opensslVersion) {
        status.textContent = "Please enter both OpenSSH and OpenSSL versions.";
        result.style.display = "block";
        return;
    }

    result.style.display = "block";
    status.textContent = "Build running...";
    log.textContent = "Starting RPM build. Please wait...";
    downloads.replaceChildren();
    button.disabled = true;

    try {
        const response = await fetch("/api/build", {
            method: "POST",
            headers: {"Content-Type": "application/json"},
            body: JSON.stringify({
                target_el: targetEL,
                openssl_mode: opensslMode,
                openssh_version: opensshVersion,
                openssl_version: opensslVersion
            })
        });

        const data = await response.json();

        log.textContent = data.log || "No build output received.";
        status.textContent = data.success ? "Build completed successfully" : "Build failed";

        if (data.rpms && data.rpms.length > 0) {
            const heading = document.createElement("h3");
            heading.textContent = "RPM files";
            downloads.appendChild(heading);

            data.rpms.forEach(function(name) {
                const link = document.createElement("a");
                link.href = "/api/download?file=" + encodeURIComponent(name);
                link.textContent = "Download " + name;
                link.style.display = "block";
                link.style.margin = "8px 0";
                downloads.appendChild(link);
            });
        } else if (data.success) {
            downloads.textContent = "Build succeeded, but no RPM files were found in output/.";
        }

        if (!response.ok && !data.log) {
            status.textContent = "Build request failed (HTTP " + response.status + ")";
        }
    } catch (error) {
        status.textContent = "Build request error";
        log.textContent = error.message;
    } finally {
        button.disabled = false;
    }
}

</script>
</body>
</html>`

func main() {
	http.HandleFunc("/api/version", versionHandler)
	http.HandleFunc("/api/build", buildHandler)
	http.HandleFunc("/api/download", downloadHandler)
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}

		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		fmt.Fprint(w, page)
	})

	addr := "0.0.0.0:8081"
	fmt.Println("OpenSSH RPM Builder UI:", "http://"+addr)

	if err := http.ListenAndServe(addr, nil); err != nil {
		panic(err)
	}
}
