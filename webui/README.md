# OpenSSH RPM Builder Web UI

A lightweight web interface for the OpenSSH RPM build scripts in this repository.

## Features

- Select the target Enterprise Linux version.
- Configure OpenSSH and OpenSSL versions.
- Select the OpenSSL build mode.
- Preview the build configuration.
- Run the RPM build process.
- View build logs and download generated RPM packages.

## Requirements

- Linux build host
- Go 1.22 or later
- RPM build tools and dependencies required by this repository
- Network access to download source archives

## Build

From the repository root:

    cd webui
    go build -o openssh-webui main.go api.go build.go

## Run

    cd webui
    ./openssh-webui

The web interface listens on port 8081.

Open:

    http://<server-ip>:8081

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /api/version | Read configured versions |
| POST | /api/build | Start an RPM build |
| GET | /api/download?file=<filename> | Download a generated RPM |

## Security Notice

The build endpoint executes repository scripts with the permissions of the web UI process.

Run the service only in a trusted environment. Do not expose it directly to the public internet.

For production deployments, use a dedicated unprivileged service account, restrict network access, and implement authentication and authorization before enabling remote builds.
