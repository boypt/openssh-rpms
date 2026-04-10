# Backport OpenSSH RPM / SRPM for CentOS

A script to backport upstream OpenSSH for CentOS/RHEL (like) distros.

Similar Project: [Backport OpenSSH for Debian / Ubuntu distros](https://github.com/boypt/openssh-deb)

## Supported (tested) Distro:

| Distro         | Version        | Recommanded EL RPMs         |
|----------------|----------------|-----------------------------|
| CentOS         | 5              | EL 5                        |
| CentOS         | 6              | EL 6                        |
| CentOS         | 7              | EL 7                        |
| CentOS         | 8              | EL 8                        |
| CentOS Stream  | 8              | EL 8                        |
| CentOS Stream  | 9              | EL 9                        |
| Rocky Linux    | 8              | EL 8                        |
| Rocky Linux    | 9              | EL 9                        |
| Amazon Linux   | 1              | EL 6                        |
| Amazon Linux   | 2              | EL 7                        |
| Amazon Linux   | 2023           | EL 9                        |
| UnionTech UOS  | V20            | EL 8                        |
| openEuler      | 20.03          | EL 8                        |
| openEuler      | 22.03          | EL 8                        |
| openEuler      | 24.03          | EL 9                        |
| AnolisOS       | 7              | EL 7                        |
| AnolisOS       | 8              | EL 8                        |
| AnolisOS       | 2023           | EL 9                        |

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

- OpenSSH 10.3p1 (see: [OpenSSH Official](https://www.openssh.com/))
- OpenSSL 3.5.6 (see: [OpenSSL Official](https://openssl-library.org/source/))

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

You can download the needed RPMs from the Release, or use a simple script to download.

The following example filters out files with `contains("el7") and contains("x86_64")` to download.

```bash
curl -s https://api.github.com/repos/boypt/openssh-rpms/releases/latest \
| jq -r '.assets[] | select(.name | ascii_downcase | contains("el7") and contains("x86_64")) | .browser_download_url' \
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

### Install on uniontech UOS 20

UOS's `openssh-help` subpackage has files that confilict with the package. It's must be removed before installing the compiled RPMs:

```bash
sudo rpm --nodeps -e openssh-help
sudo yum --disablerepo=* install -y ./openssh*.rpm
```
