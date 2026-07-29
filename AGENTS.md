# AGENTS.md

## What this repo is

Shell scripts to backport and build OpenSSH RPMs for CentOS/RHEL-like distros (EL5 through EL9, also Rocky, AlmaLinux, Anolis, UOS, openEuler, Amazon Linux).

## Essential commands

```bash
# Download source tarballs into downloads/
./pullsrc.sh

# Build RPMs (auto-detects the EL version from the running system)
./compile.sh

# Force a specific EL target (useful on non-RPM build hosts like Docker/Ubuntu)
./compile.sh el7

# Docker-based build (see docker/README.md for per-version commands)
docker build -t elssh:el8 -f ./docker/Dockerfile.centos --build-arg VERSION_NUM=8 --build-arg MIRROR=0 .
docker run --rm -v .:/data elssh:el8
```

## Configuration

- `version.env` — source versions (OpenSSH, OpenSSL, Perl). Committed.
- `version-local.env` — user overrides like `PKGREL`, `WITH_OPENSSL`, `GH_PROXY`. Gitignored (`*-local*`).
- `compile.sh` sources `version.env` then `version-local.env` (if present), so `version-local.env` wins.

## Key variables

- `WITH_OPENSSL`: `0` = no OpenSSL (no ssh-rsa keys), `1` = system OpenSSL, `2` = static OpenSSL (default for EL5/6/7, EL8 defaults to `1`)
- `PKGREL`: package release number (defaults to `1`)
- `M32=1`: build 32-bit RPMs (EL5 only)
- `DOCKERBUILD=1`: when set, `pullsrc.sh` skips downloading (assumes Docker image has the sources)
- `GH_PROXY`: GitHub proxy URL for Chinese users (e.g. `https://gh-proxy.com/`)

## Architecture notes

- **EL8 and EL9 both use `el7/`** as the spec directory, since they share systemd. `compile.sh` GUESS_DIST returns `el7` for all versions >= EL7.
- EL6 uses `el6/` (SysVinit).
- EL5 uses `el5/` (SysVinit, requires Perl bootstrap for building OpenSSL).
- `WITH_OPENSSL` auto-detection: for `el7` (which covers EL7/8/9), if system OpenSSL >= 3, defaults to `1` (system), otherwise `2` (static).
- `compile.sh` has subcommands: `GETEL` (print detected distro), `GETRPM` (list RPM paths), `RPMDIR` (print RPM output dir).
- `el7/SPECS/` has three spec files: `openssh.spec` (default), `openssh.initv.spec`, `openssh.uos20.spec`. The default spec is selected via `SPECFILE` env var.
- `docker/docker_compile.sh` is the entrypoint inside Docker images — it copies the appropriate `el*` dir to `/BUILD` and runs `compile.sh` against it.

## CI

- `.github/workflows/build-images.yml` — manually triggered (`workflow_dispatch`), builds Docker images for each EL version and pushes to `ghcr.io`.
- `.github/workflows/build-rpm.yml` — runs on `v*` tags, builds RPMs inside Docker containers and creates a GitHub release.

## Gitignore

`*-local*` is gitignored — version-local.env, editor swap files, etc. `*.tar.gz` is gitignored everywhere, including `downloads/`. Generated RPMs go to `output/` (also gitignored).

## Release workflow

When a new upstream OpenSSH version is available:

```bash
# 1. Check latest version
./pullsrc.sh --latest

# 2. Update version.env: OPENSSHSRC and OPENSSHVER
#    Update README.md: "Current Version" section

# 3. Determine build number for this version
TAG_PREFIX="v${NEW_VERSION}_b"
BUILD_NUM=$(git tag | grep "^${TAG_PREFIX}" | sed "s/^${TAG_PREFIX}//" | sort -n | tail -1)
BUILD_NUM=$(( ${BUILD_NUM:-0} + 1 ))

# 4. Commit and tag
git add version.env README.md
git commit -m "bump: OpenSSH ${NEW_VERSION}_b${BUILD_NUM}"
git tag "v${NEW_VERSION}_b${BUILD_NUM}"

# 5. Push
git push origin main
git push origin "v${NEW_VERSION}_b${BUILD_NUM}"
```

Pushing the tag triggers `.github/workflows/build-rpm.yml` which builds RPMs for all EL versions and creates a GitHub release.