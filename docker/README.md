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
# Download all required sources
env ALL=1 ./pullsrc.sh
```

> **Note**: Run this command only once before starting any builds. It prepares all necessary files for every supported platform.

## Step 2: Building RPMs for Specific Platforms

Choose only the platforms you need and run the corresponding commands.

### x86_64 Builds

#### For EL5 (CentOS 5)

```bash
# Build Docker image
docker build -t elssh_el5 -f ./docker/Dockerfile.centos5 --build-arg CHINA_MIRROR=0 .

# Build 64-bit packages (recommended)
docker run --rm -v .:/data -e "M32=0" elssh_el5

# Build 32-bit packages (optional)
docker run --rm -v .:/data -e "M32=1" elssh_el5
```

#### For EL6 (CentOS 6)

```bash
docker build -t elssh_el6 -f ./docker/Dockerfile.centos --build-arg VERSION_NUM=6 --build-arg CHINA_MIRROR=0 .
docker run --rm -v .:/data elssh_el6
```

#### For EL7 (CentOS 7)

```bash
docker build -t elssh_el7 -f ./docker/Dockerfile.centos --build-arg VERSION_NUM=7 --build-arg CHINA_MIRROR=0 .
docker run --rm -v .:/data elssh_el7
```

#### For EL8 (CentOS 8 / RHEL 8 / Rocky 8 / AlmaLinux 8)

```bash
docker build -t elssh_el8 -f ./docker/Dockerfile.centos --build-arg VERSION_NUM=8 --build-arg CHINA_MIRROR=0 .
docker run --rm -v .:/data elssh_el8
```

#### For EL9 (CentOS Stream 9 / RHEL 9 / Rocky 9 / AlmaLinux 9)

```bash
docker build -t elssh_el9 -f ./docker/Dockerfile.centos-stream --build-arg VERSION_NUM=9 --build-arg CHINA_MIRROR=0 .
docker run --rm -v .:/data elssh_el9
```

### aarch64 (ARM64) Builds

#### For EL8 aarch64

```bash
docker build -t elssh_aarch64_el8 \
  --platform linux/arm64 \
  -f ./docker/Dockerfile.centos-stream \
  --build-arg VERSION_NUM=8 \
  --build-arg CHINA_MIRROR=0 .

docker run --rm -v .:/data --platform linux/arm64 elssh_aarch64_el8
```

#### For EL9 aarch64

```bash
docker build -t elssh_aarch64_el9 \
  --platform linux/arm64 \
  -f ./docker/Dockerfile.centos-stream \
  --build-arg VERSION_NUM=9 \
  --build-arg CHINA_MIRROR=0 .

docker run --rm -v .:/data --platform linux/arm64 elssh_aarch64_el9
```

## Build Arguments

| Argument          | Values | Description |
|-------------------|--------|-----------|
| `CHINA_MIRROR`    | 0 or 1 | Set to `1` if you are in China and want to use faster domestic mirrors |
| `VERSION_NUM`     | 6,7,8,9| Specifies the target EL version (used in most Dockerfiles) |
| `M32` (EL5 only)  | 0 or 1 | `0` = 64-bit, `1` = 32-bit |

**Example for users in China:**

Add `--build-arg CHINA_MIRROR=1` to the `docker build` command.

## Output Location

After each successful build, the RPM packages are copied to:

```
./output/
```

Typical output structure:

```
output/
├── el5/
│   ├── x86_64/
│   └── i686/          # only if M32=1
├── el6/
├── el7/
├── el8/
├── el9/
├── el8-aarch64/
└── el9-aarch64/
```

Each subdirectory contains the generated `.rpm` files (including debuginfo if available).

## Quick Start Examples

### Build only for modern systems (EL8 + EL9)

```bash
env ALL=1 ./pullsrc.sh

docker build -t elssh_el8 -f ./docker/Dockerfile.centos --build-arg VERSION_NUM=8 --build-arg CHINA_MIRROR=0 .
docker run --rm -v .:/data elssh_el8

docker build -t elssh_el9 -f ./docker/Dockerfile.centos-stream --build-arg VERSION_NUM=9 --build-arg CHINA_MIRROR=0 .
docker run --rm -v .:/data elssh_el9
```

### Build only for ARM64

```bash
env ALL=1 ./pullsrc.sh

docker build -t elssh_aarch64_el9 --platform linux/arm64 -f ./docker/Dockerfile.centos-stream --build-arg VERSION_NUM=9 --build-arg CHINA_MIRROR=0 .
docker run --rm -v .:/data --platform linux/arm64 elssh_aarch64_el9
```

## Troubleshooting

- **Slow downloads**: Use `CHINA_MIRROR=1`
- **Permission issues**: Run `chown -R $USER output/` after building
- **Docker build fails on first run**: This is normal — it needs to download base images and dependencies
- **ARM64 builds**: Requires a machine with ARM64 support or Docker Buildx multi-platform enabled

