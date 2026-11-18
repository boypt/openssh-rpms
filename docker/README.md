# elssh Build Guide – Docker-based RPM Packaging

This document explains how to build **elssh** RPM packages for various Enterprise Linux versions using Docker.

You only need to build the versions you actually require. There is no need to run all commands.

All built RPM packages will be automatically placed in the `./output/` directory on your host machine.

## Prerequisites

- Docker (version 20+ recommended)
- Git
- Sufficient disk space (~10 GB+ recommended)
- Internet connection

## Step 1: Download Sources

You must download the source code and tarballs before building:

```bash
# Download the pinned sources from version.env
./pullsrc.sh
```

> **Note**: Run this command only once before starting any builds. It downloads the single pinned set of sources defined in `version.env`. With `DOCKERBUILD=1 ./pullsrc.sh` only the Perl tarball is fetched (used for EL5 image builds).

## Step 2: Building RPMs for Specific Platforms

Choose only the platforms you need and run the corresponding commands.

### x86_64 Builds

#### For EL5 (CentOS 5)

```bash
# Build Docker image
docker build -t elssh:el5 -f ./docker/Dockerfile.centos5 .

# Build 64-bit packages (recommended)
docker run --rm -v .:/data -e "M32=0" elssh:el5

# Build 32-bit packages (optional)
docker run --rm -v .:/data -e "M32=1" elssh:el5
```

#### For EL6 (CentOS 6)

```bash
docker build -t elssh:el6 -f ./docker/Dockerfile.centos --build-arg VERSION_NUM=6 .
docker run --rm -v .:/data elssh:el6
```

#### For EL7 (CentOS 7)

```bash
docker build -t elssh:el7 -f ./docker/Dockerfile.centos --build-arg VERSION_NUM=7 .
docker run --rm -v .:/data elssh:el7
```

#### UOS 20 Variant (EL8)

Reuse the EL8 image (CentOS Stream 8, `el7/` spec via `GUESS_DIST` mapping) and pass `UOS20=1` to enable the kernel-panic fix in `sshd.c` and prefix `PKGREL` with `uos20.` (so the resulting RPMs are distinguishable from the standard build).

```bash
docker build -t elssh:el8 -f ./docker/Dockerfile.centos-stream --build-arg VERSION_NUM=8 .
docker run --rm -v .:/data -e "UOS20=1" elssh:el8
```

The aarch64 UOS20 build (CI artifact `rpm-uos20-aarch64`) uses the aarch64 EL8 image with `-e "UOS20=1"`.

#### For EL8 (CentOS 8 / RHEL 8 / Rocky 8 / AlmaLinux 8)

```bash
docker build -t elssh:el8 -f ./docker/Dockerfile.centos-stream --build-arg VERSION_NUM=8 .
docker run --rm -v .:/data elssh:el8
```

#### For EL9 (CentOS Stream 9 / RHEL 9 / Rocky 9 / AlmaLinux 9)

```bash
docker build -t elssh:el9 -f ./docker/Dockerfile.centos-stream --build-arg VERSION_NUM=9 .
docker run --rm -v .:/data elssh:el9
```

#### Amazon Linux native builds

Use the native Amazon Linux image when the RPM Release must retain its Amazon
identity (`.amzn1`, `.amzn2`, or `.amzn2023`). The container checks the RPM
`%{?dist}` macro before building, so it fails rather than producing an RPM with
the wrong internal release.

| Target | Docker tag | Build arguments |
|--------|------------|-----------------|
| Amazon Linux 1 x86_64 | `amzn1` | `VERSION_NUM=1 BUILD_TOPDIR=el6 EXPECTED_RPM_DIST=amzn1` |
| Amazon Linux 2 x86_64/aarch64 | `amzn2` | `VERSION_NUM=2 BUILD_TOPDIR=el7 EXPECTED_RPM_DIST=amzn2` |
| Amazon Linux 2023 x86_64/aarch64 | `amzn2023` | `VERSION_NUM=2023 BUILD_TOPDIR=el7 EXPECTED_RPM_DIST=amzn2023` |

For example, build Amazon Linux 2023 for x86_64:

```bash
docker build -t elssh:amzn2023 -f ./docker/Dockerfile.amazonlinux \
  --build-arg VERSION_NUM=2023 \
  --build-arg BUILD_TOPDIR=el7 \
  --build-arg EXPECTED_RPM_DIST=amzn2023 .
docker run --rm -v .:/data elssh:amzn2023
```

Add `--platform linux/arm64` when building Amazon Linux 2 or 2023 for
aarch64.

#### openEuler native builds

Use the native openEuler image when the RPM Release must retain its openEuler
identity. The supported image tags map to the corresponding RPM dist macro:

| Target | Docker tag | Build arguments |
|--------|------------|-----------------|
| openEuler 20.03 SP4 | `oe2003sp4` | `VERSION_NUM=20.03-lts-sp4 BUILD_TOPDIR=el7 EXPECTED_RPM_DIST=oe2003sp4` |
| openEuler 22.03 SP4 | `oe2203sp4` | `VERSION_NUM=22.03-lts-sp4 BUILD_TOPDIR=el7 EXPECTED_RPM_DIST=oe2203sp4` |
| openEuler 24.03 SP2 | `oe2403sp2` | `VERSION_NUM=24.03-lts-sp2 BUILD_TOPDIR=el7 EXPECTED_RPM_DIST=oe2403sp2` |

For example, build openEuler 24.03 SP2 for x86_64:

```bash
docker build -t elssh:oe2403sp2 -f ./docker/Dockerfile.openeuler \
  --build-arg VERSION_NUM=24.03-lts-sp2 \
  --build-arg BUILD_TOPDIR=el7 \
  --build-arg EXPECTED_RPM_DIST=oe2403sp2 .
docker run --rm -v .:/data elssh:oe2403sp2
```

Add `--platform linux/arm64` for aarch64 builds.

### aarch64 (ARM64) Builds

#### For EL7 aarch64

```bash
docker build -t elssh_aarch64:el7 \
  --platform linux/arm64 \
  -f ./docker/Dockerfile.centos \
  --build-arg VERSION_NUM=7 .

docker run --rm -v .:/data --platform linux/arm64 elssh_aarch64:el7
```

#### For EL8 aarch64

```bash
docker build -t elssh_aarch64:el8 \
  --platform linux/arm64 \
  -f ./docker/Dockerfile.centos-stream \
  --build-arg VERSION_NUM=8 .

docker run --rm -v .:/data --platform linux/arm64 elssh_aarch64:el8
```

#### For EL9 aarch64

```bash
docker build -t elssh_aarch64:el9 \
  --platform linux/arm64 \
  -f ./docker/Dockerfile.centos-stream \
  --build-arg VERSION_NUM=9 .

docker run --rm -v .:/data --platform linux/arm64 elssh_aarch64:el9
```

## Build Arguments

| Argument          | Values | Description |
|-------------------|--------|-----------|
| `VERSION_NUM`     | EL: 6, 7, 8, 9; Amazon: 1, 2, 2023; openEuler: `20.03-lts-sp4`, `22.03-lts-sp4`, `24.03-lts-sp2` | Selects the target operating-system image |
| `BUILD_TOPDIR`    | `el6`, `el7` | Selects the compatible RPM spec tree; Amazon Linux 1 uses `el6`, all restored native targets use `el7` |
| `EXPECTED_RPM_DIST` | e.g. `amzn2023`, `oe2403sp2` | Fails the native build if the target image reports an unexpected RPM `%{?dist}` value |
| `M32` (EL5 only)  | 0 or 1 | `0` = 64-bit, `1` = 32-bit |
| `UOS20`           | 0 or 1 | `1` = build the UOS 20 variant (EL8 image); enables the kernel-panic patch and prefixes `PKGREL` with `uos20.` |

> Native Amazon Linux and openEuler Dockerfiles are maintained because Yum dependency resolution uses the RPM's internal Name-Version-Release-Architecture fields. Renaming an EL RPM file after its build does not change those fields.

## Output Location

After each successful build, all built `.rpm` files land directly in `./output/` (flat, no per-version subdirs):

```
output/
├── openssh-*.rpm
├── openssh-clients-*.rpm
└── ...
```

Every build (native `./compile.sh` or Docker via `docker/docker_compile.sh`) funnels through the same copy step, so building another EL version adds to / overwrites the same flat directory — copy the files out first if you need to keep versions separate.

## Quick Start Examples

### Build only for modern systems (EL8 + EL9)

```bash
./pullsrc.sh

docker build -t elssh:el8 -f ./docker/Dockerfile.centos-stream --build-arg VERSION_NUM=8 .
docker run --rm -v .:/data elssh:el8

docker build -t elssh:el9 -f ./docker/Dockerfile.centos-stream --build-arg VERSION_NUM=9 .
docker run --rm -v .:/data elssh:el9
```

### Build only for ARM64

```bash
./pullsrc.sh

docker build -t elssh_aarch64:el9 --platform linux/arm64 -f ./docker/Dockerfile.centos-stream --build-arg VERSION_NUM=9 .
docker run --rm -v .:/data --platform linux/arm64 elssh_aarch64:el9
```

## Troubleshooting

- **Permission issues**: Run `chown -R $USER output/` after building
- **Docker build fails on first run**: This is normal — it needs to download base images and dependencies
- **ARM64 builds**: Requires a machine with ARM64 support or Docker Buildx multi-platform enabled

