# Backport OpenSSH RPM / SRPM for CentOS

A script to backport upstream OpenSSH for CentOS/RHEL (like) distros.

Similar Project: [Backport OpenSSH for Debian / Ubuntu distros](https://github.com/boypt/openssh-deb)

## Supported (tested) Distro:

- CentOS 5/6/7/8/Stream 8/9
- Rocky Linux 8/9
- Amazon Linux 1/2/2023
- UnionTech OS 20
- openEuler 22.03/24.03
- AnolisOS 7/8/2023

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
yum groupinstall -y "Development Tools"
yum install -y imake rpm-build pam-devel krb5-devel zlib-devel libXt-devel libX11-devel gtk2-devel perl perl-IPC-Cmd perl-Time-Piece

# For CentOS7 and above:
yum install -y systemd-devel

# For CentOS5 only:
yum install -y gcc44
```

## Usage

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
