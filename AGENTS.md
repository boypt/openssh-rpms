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
- `UOS20=1`: build the UOS 20 variant — enables the kernel-panic patch (`openssh-uos20-kernel-panic-fix.patch`) and prefixes `PKGREL` with `uos20.` so resulting RPMs are distinguishable.

## Architecture notes

- **EL8 and EL9 both use `el7/`** as the spec directory, since they share systemd. `compile.sh` GUESS_DIST returns `el7` for all versions >= EL7.
- EL6 uses `el6/` (SysVinit).
- EL5 uses `el5/` (SysVinit, requires Perl bootstrap for building OpenSSL).
- **Supported architectures**: `x86_64` for all EL versions; `aarch64` for EL7/8/9 and UOS20 via per-arch tags (`aarch64_el7`, `aarch64_el8`, `aarch64_el9`). Docker tags are per-arch (e.g. `ghcr.io/boypt/openssh-rpms:aarch64_el7`), not multi-arch manifests.
- `WITH_OPENSSL` auto-detection: for `el7` (which covers EL7/8/9), if system OpenSSL >= 3, defaults to `1` (system), otherwise `2` (static).
- `compile.sh` has subcommands: `GETEL` (print detected distro), `GETRPM` (list RPM paths), `RPMDIR` (print RPM output dir).
- `el7/SPECS/` has two spec files: `openssh.spec` (default, systemd) and `openssh.initv.spec` (SysVinit). The default spec is selected via `SPECFILE` env var. The UOS 20 build uses the default spec with `UOS20=1`.
- `docker/docker_compile.sh` is the entrypoint inside Docker images — it copies the appropriate `el*` dir to `/BUILD` and runs `compile.sh` against it.
- `docker/modify_vault_source.sh` handles vault mirrors; for `aarch64` it appends `/altarch` (CentOS AltArch vault, e.g. `.../centos-vault/altarch/7.9.2009/`). For EL5 `EPEL` always uses `http://mirrors.aliyun.com/epel-archive` (avoids Python 2.4 TLS 1.0 → 302 → https failure on `archives.fedoraproject.org`).

## CI

- `.github/workflows/build-images.yml` — manually triggered (`workflow_dispatch`), builds Docker images and pushes to `ghcr.io`. Matrix: `build-amd64` (5 images: `el5`, `el6`, `el7`, `el8`, `el9` on `ubuntu-latest`) + `build-arm64` (3 images: `aarch64_el7`, `aarch64_el8`, `aarch64_el9` on `ubuntu-latest` with `setup-qemu-action` + `platforms: linux/arm64`). Cache: `type=gha`.
- `.github/workflows/build-rpm.yml` — runs on `v*` tags, builds RPMs inside Docker containers and creates a GitHub release. Jobs: `build-arm64` (`ubuntu-24.04-arm`, natively runs `aarch64_*` images), `build-amd64` (`ubuntu-latest`), `build-el5` (`ubuntu-latest`, handles `m32` for i686). Final `release` needs all three and zips artifacts as `openssh_<tag>_<artifact>.zip`.

## Linting & formatting

All shell scripts (`*.sh`) must pass `shellcheck` and `shfmt` before committing:

```bash
# Lint (warnings are errors)
shellcheck -S warning compile.sh pullsrc.sh

# Format check (must produce no diff)
shfmt -d -i 0 -bn -ci compile.sh pullsrc.sh

# Auto-fix formatting in-place
shfmt -w -i 0 -bn -ci compile.sh pullsrc.sh
```

- **shellcheck** `-S warning`: treat warnings as failures; informational/style notes may be suppressed inline with `# shellcheck disable=SCxxxx`.
- **shfmt** `-i 0 -bn -ci`: tabs for indentation (no extra indent), binary operators (`&&`, `||`, `|`) at start of next line, case body indented.
- Both tools must exit 0 before any commit touching `*.sh` files.

## Gitignore

`*-local*` is gitignored — version-local.env, editor swap files, etc. `*.tar.gz` is gitignored everywhere, including `downloads/`. Generated RPMs go to `output/` (also gitignored).

## Version bump workflow

When the user says "update to &lt;version&gt;" (e.g. "update to 10.5", "update to 10.6p1"), perform the following steps autonomously. Only update `README.md` and `version.env` — do not touch other files unless explicitly asked.

1. **Normalize the version**: append `p1` if not already present (all portable releases use `p1`). E.g. `10.5` → `10.5p1`.

2. **Update `version.env`**: change the `OPENSSHSRC` line to `openssh-<version>.tar.gz`. `OPENSSHVER` is derived automatically from `OPENSSHSRC`. Do NOT change `OPENSSLSRC`/`OPENSSLVER` or any other line unless the user explicitly asks.

3. **Update `README.md`**: in the "Current Version" section, update only the OpenSSH version line. Leave the OpenSSL line unchanged.

4. **Determine the next build number**:
   ```bash
   TAG_PREFIX="v${NEW_VERSION}_b"
   BUILD_NUM=$(git tag | grep "^${TAG_PREFIX}" | sed "s/^${TAG_PREFIX}//" | sort -n | tail -1)
   BUILD_NUM=$(( ${BUILD_NUM:-0} + 1 ))
   ```

5. **Commit and tag** (do not push yet):
   ```bash
   git add version.env README.md
   git commit -m "bump: OpenSSH ${NEW_VERSION}_b${BUILD_NUM}"
   git tag "v${NEW_VERSION}_b${BUILD_NUM}"
   ```

6. **Ask the user for confirmation to push** to remote. This is the only confirmation needed — do not ask about file changes, commit message, tag name, or anything else.

7. **After pushing**, the tag triggers `.github/workflows/build-rpm.yml` which builds RPMs for all EL versions and creates a GitHub release. Monitor CI using `gh` commands and report the status:
   ```bash
   gh run list --limit 5
   gh run watch    # watch the latest run to completion
   ```