# Backport OpenSSH RPM / SRPM for CentOS

A script to backport upstream OpenSSH for CentOS/RHEL (like) distros.

Similar Project: [Backport OpenSSH for Debian / Ubuntu distros](https://github.com/boypt/openssh-deb)

## Supported (tested) Distro:

| Distro         | Version        | Arch                | Recommanded EL RPMs                                                  |
|================|================|=====================|======================================================================|
| CentOS          | 5               | x86_64 / i686        | EL 5 (`rpm-el5-x86_64`, `rpm-el5-i686`)              |
| CentOS          | 6               | x86_64               | EL 6 (`rpm-el6-x86_64`)                              |
| CentOS          | 7               | x86_64 / aarch64     | EL 7 (`rpm-el7-x86_64`, `rpm-el7-aarch64`)           |
| CentOS          | 8               | x86_64 / aarch64     | EL 8 (`rpm-el8-x86_64`, `rpm-el8-aarch64`)           |
| CentOS Stream   | 8               | x86_64 / aarch64     | EL 8 (`rpm-el8-x86_64`, `rpm-el8-aarch64`)           |
| CentOS Stream   | 9               | x86_64 / aarch64     | EL 9 (`rpm-el9-x86_64`, `rpm-el9-aarch64`)           |
| Rocky Linux     | 8               | x86_64 / aarch64     | EL 8 (`rpm-el8-x86_64`, `rpm-el8-aarch64`)           |
| Rocky Linux     | 9               | x86_64 / aarch64     | EL 9 (`rpm-el9-x86_64`, `rpm-el9-aarch64`)           |
| Amazon Linux    | 1               | x86_64               | EL 6 (`rpm-el6-x86_64`)                              |
| Amazon Linux    | 2               | x86_64 / aarch64     | EL 7 (`rpm-el7-x86_64`, `rpm-el7-aarch64`)           |
| Amazon Linux    | 2023            | x86_64 / aarch64     | EL 9 (`rpm-el9-x86_64`, `rpm-el9-aarch64`)           |
| UnionTech UOS   | V20             | x86_64 / aarch64     | **UOS20** (`rpm-uos20-x86_64`, `rpm-uos20-aarch64`)  |
| openEuler       | 20.03           | x86_64 / aarch64     | EL 8 (`rpm-el8-x86_64`, `rpm-el8-aarch64`)           |
| openEuler       | 22.03           | x86_64 / aarch64     | EL 8 (`rpm-el8-x86_64`, `rpm-el8-aarch64`)           |
| openEuler       | 24.03           | x86_64 / aarch64     | EL 9 (`rpm-el9-x86_64`, `rpm-el9-aarch64`)           |
| AnolisOS        | 7               | x86_64 / aarch64     | EL 7 (`rpm-el7-x86_64`, `rpm-el7-aarch64`)           |
| AnolisOS        | 8               | x86_64 / aarch64     | EL 8 (`rpm-el8-x86_64`, `rpm-el8-aarch64`)           |
| AnolisOS        | 2023            | x86_64 / aarch64     | EL 9 (`rpm-el9-x86_64`, `rpm-el9-aarch64`)           |

> `aarch64` RPMs are built from the same `el7/` spec via `aarch64_el7/8/9` Docker tags (`ghcr.io/boypt/openssh-rpms:aarch64_el7` etc., QEMU-built, per-arch tags — not multi-arch manifests).

## Project Structure 

- `pullsrc.sh`: Script to download source packages.
- `compile.sh`: Script to build RPMs.
- `version.env`: config file for variables (versions, release number, OPENSSL MODE, proxy ...)

The directory (`el5`, `el6`, `el7`) serve as functional templates for different environment types. The `openssh.spec` are modified based on the shipped spec file from OpenSSH project.

- `el5`: Designed for legacy environments. With toolchains (Perl) to support the build process.
- `el6`: With SysVinit startup.
- `el7`: With Systemd service.

**Note**: the Systemd units in `el7` are applicable not only to EL7 but also to EL8, EL9, and other modern distributions that rely on Systemd.

## Current Version:

- OpenSSH 10.5p1 (see: [OpenSSH Official](https://www.openssh.com/))
- OpenSSL 3.5.7 (see: [OpenSSL Official](https://openssl-library.org/source/))

The build script reads `version.env` for version definitions.

OpenSSL is not needed when using `WITH_OPENSSL=0`. (see `version.env`)

## Build Requirements:

```bash
yum install -y autoconf automake gcc make rpm-build pam-devel krb5-devel zlib-devel libXt-devel libX11-devel gtk2-devel perl perl-IPC-Cmd perl-Time-Piece

# For CentOS7 and above:
yum install -y systemd-devel

# For CentOS5 only:
yum install -y gcc44
```

## Usage

### Download RPMs

You can download the needed RPMs from the GitHub Release using the GitHub
API. The script below auto-detects your architecture and EL version from
the running system, then fetches the matching asset from the latest
release.

```bash
ARCH=$(uname -m)
# Read the system's own rpm dist tag (.el8 -> el8, .el7 -> el7, ...).
# Override for non-elN dists (e.g. UOS 20) or when auto-detect fails.
# If unsure which EL value to use, see the "Supported (tested) Distro"
# table at the top of this README.
EL=$(rpm --eval '%{?dist}' 2>/dev/null | grep -oE 'el[0-9]+' | head -1)
[[ -z "$EL" ]] && EL=el7

curl -s https://api.github.com/repos/boypt/openssh-rpms/releases/latest \
| jq -r --arg el "$EL" --arg arch "$ARCH" \
    '.assets[] | select(.name | ascii_downcase | contains($el) and contains($arch)) | .browser_download_url' \
| wget -i - --show-progress -c
```

### Build RPMs

Note: It is unnecessary to build on each system, as most RPM-based Linux distributions are glibc compatible. That is, RPMs built on `CentOS 8` can be installed and run on `Rocky Linux 8`/`AlmaLinux 8`/`Oracle Linux 8`, etc.

1. Install build requirements listed above.
2. Edit `version.env` file if necessary.
3. Download source packages.
    ```bash
    ./pullsrc.sh
    ```
    if any error comes up, manually download the source files into the `downloads` dir.
4. Run the script to build RPMs. 
    ```bash
    ./compile.sh
    ```
5. The generated RPM files will be copied to the `output` directory.

### Install RPMs

```bash
ls output
# you will find multiple RPM files in this directory.
# you may copy them to other machines, and continue following steps there.

# Backup current SSH config
[[ -f /etc/ssh/sshd_config ]] && mv /etc/ssh/sshd_config /etc/ssh/sshd_config.$(date +%Y%m%d)

# Install rpm packages.
sudo yum --disablerepo=* localinstall -y ./openssh*.rpm

# Check Installed version:
ssh -V && /usr/sbin/sshd -V

# Restart service
sudo service sshd restart

# Test a new ssh connection
ssh localhost
```

**DO NOT DISCONNECET** current ssh shell yet, open a **NEW** shell and login to you machine to verify that sshd is working properly.

#### Trouble shooting

You may get complains during the `yum localinstall` process. It's mostly because some subpackages depend on the main openssh package, upgrading only the main package won't fit in their dependencies.

Commonly these packages are needed to be erased before installing built RPMs.

```
yum erase openssh-askpass openssh-keycat openssh-cavs openssh-askpass openssh-askpass-gnome openssh-debuginfo
```

If still not satisfied, you may try the final weapon: FORCED INSTALL.

```bash
rpm -ivh --force --nodeps --replacepkgs --replacefiles openssh-*.rpm
```

## Use Docker

For more details, see [docker/README.md](docker/README.md)

## Other Notes

### Built without OPENSSL

When built with `WITH_OPENSSL=0`, `ssh-rsa` keys are not supported. But the RPMs are much smaller, and the built process is much faster.

### Build for uniontech UOS 20

UOS 20 kernels have a `do_dup2()` bug that triggers a kernel NULL pointer
dereference panic when `sshd` re-execs:

```
BUG: unable to handle kernel NULL pointer dereference at 000000000000003f
IP: filp_close+0x9/0x70
Call Trace: do_dup2+xxx sys_dup2 entry_SYSCALL_64
PID: xxx Comm: sshd
```

To apply the workaround (`el7/SOURCES/openssh-uos20-kernel-panic-fix.patch`,
which closes the target fd before each `dup2()` in `sshd.c`), set
`UOS20=1`:

```bash
UOS20=1 ./compile.sh el8
```

The flag also prefixes `PKGREL` with `uos20.` so the resulting RPMs are distinguishable from the standard build (e.g. PKGREL `1` becomes `uos20.1`, producing `openssh-XXXXX-uos20.1.el7.x86_64.rpm`). The patch is only
applied when the `uos20` macro is set, so ordinary EL7/8/9 builds are
unaffected. For the Docker-based build, see
[docker/README.md](docker/README.md#uos-20-variant-el8).

### Install on uniontech UOS 20

UOS's `openssh-help` subpackage has files that confilict with the package. It's must be removed before installing the compiled RPMs:

```bash
sudo rpm --nodeps -e openssh-help
sudo yum --disablerepo=* install -y ./openssh*.rpm
```
