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

`el5`: Designed for legacy environments. It requires independent compilation of toolchains (e.g., Perl) to support the build process.
`el6`: Utilizes traditional SysVinit scripts for service startup.
`el7`: Adopts modern Systemd unit files for service management.

**Note**: The directory names (`el5`, `el6`, `el7`) serve as functional templates for different environment types. For instance, the Systemd units in `el7` are applicable not only to EL7 but also to EL8, EL9, and other modern distributions that rely on Systemd.

## Current Version:

- OpenSSH 10.2p1 (see: [OpenSSH Official](https://www.openssh.com/))
- OpenSSL 3.0.18 (see: [OpenSSL Official](https://www.openssl.org/source/))

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

Note: It is not necessary to build on every system that needs the latest version of OpenSSH, as most RPM-based Linux distributions are glibc compatible with each other. That is, RPMs built on CentOS can be installed and run on Rocky Linux 8/AlmaLinux/Oracle Linux 8, etc.

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

### Install RPMs

```bash
# Go to the generated RPMS directory.
cd $(./compile.sh RPMDIR)
pwd
ls
# you will find multiple RPM files in this directory.
# you may copy them to other machines, and continue following steps there.

# Backup current SSH config
[[ -f /etc/ssh/sshd_config ]] && mv /etc/ssh/sshd_config /etc/ssh/sshd_config.$(date +%Y%m%d)

# Install rpm packages.
sudo yum --disablerepo=* localinstall -y ./openssh*.rpm

# In case host key file permissions are too open.
chmod -v 600 /etc/ssh/ssh_host_*_key

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

## Security Notes

This package provide following options in `/etc/ssh/sshd_config` to work like triditional sshd.

Note: when built with `WITH_OPENSSL=0`, `ssh-rsa` is not supported.

```
PubkeyAcceptedAlgorithms +ssh-rsa
PermitRootLogin yes
PasswordAuthentication yes
UseDNS no
UsePAM yes
KexAlgorithms -diffie-hellman-group1-sha1,diffie-hellman-group1-sha256,diffie-hellman-group14-sha1,diffie-hellman-group14-sha256,diffie-hellman-group15-sha256,diffie-hellman-group15-sha512,diffie-hellman-group16-sha256,diffie-hellman-group16-sha512,diffie-hellman-group17-sha512,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha1,diffie-hellman-group-exchange-sha256,diffie-hellman-group-exchange-sha512
```
