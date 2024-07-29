# Backport OpenSSH RPM / SRPM for CentOS

A simple script to backport latest OpenSSH RPMs for CentOS/RHEL (like) distros.

Similar Project: [Backport OpenSSH for Debian / Ubuntu distros](https://github.com/boypt/openssh-deb)

## Supported (tested) Distro:

- CentOS 5/6/7/8/Stream 8/9
- Amazon Linux 1/2/2023
- UnionTech OS Server 20
- openEuler 22.03 (LTS-SP1)
- AnolisOS 7.9/8.6

## Current Version:

- OpenSSH 9.8p1 (see: [OpenSSH Official](https://www.openssh.com/))
- OpenSSL 3.0.14 / 3.0.9 (FIPS validated, see: [OpenSSL Official](https://www.openssl.org/source/))

The build script reads `version.env` for actual version definitions.

## Build Requirements:

```bash
yum groupinstall -y "Development Tools"
yum install -y imake rpm-build pam-devel krb5-devel zlib-devel libXt-devel libX11-devel gtk2-devel perl perl-IPC-Cmd

# For CentOS5 only:
yum install -y gcc44
```

## Usage

### Build RPMs

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
# Go go the generated RPMS directory.
cd $(./compile.sh RPMDIR)
pwd
ls
# you will find multiple RPM files in this directory.
# you may copy them to other machines, and continue following steps there.

# Backup current SSH config
[[ -f /etc/ssh/sshd_config ]] && mv /etc/ssh/sshd_config /etc/ssh/sshd_config.$(date +%Y%m%d)

# Install rpm packages. Exclude all debug packages.
find . ! -name '*debug*' -name '*.rpm' | xargs sudo yum --disablerepo=* localinstall -y --allowerasing

# in case host key files got permissions too open.
chmod -v 600 /etc/ssh/ssh_host_*_key

# For CentOS7+:
# in some cases previously installed systemd unit file is left on disk after upgrade.
# causes systemd mixing unit files and initscripts units provided by this package.
if [[ -d /run/systemd/system && -f /usr/lib/systemd/system/sshd.service ]]; then
    mv /usr/lib/systemd/system/sshd.service /usr/lib/systemd/system/sshd.service.$(date +%Y%m%d)
    systemctl daemon-reload
fi

# Check Installed version:
ssh -V && /usr/sbin/sshd -V

# Restart service
service sshd restart
```

**DO NOT DISCONNECET** current ssh shell yet, open a **NEW** shell and login to you machine to verify that sshd is working properly.

#### Trouble shoot

You may get complains during the `yum localinstall` process. It's mostly because some subpackages depend on the main openssh package, upgrading only the main package won't fit in their dependencies.

Commonly these packages are needed to be erased before installing built RPMs.

```
yum erase openssh-askpass openssh-keycat openssh-cavs openssh-askpass openssh-askpass-gnome openssh-debuginfo
```

If still not satisfied, you may try the final wepon: FORCED INSTALL.

```bash
rpm -ivh --force --nodeps --replacepkgs --replacefiles openssh-*.rpm
```

## Use Docker

### TL;DR

```bash
# Define output directory
OUTPUT="/tmp/openssh-rpms"
# Specify build os and versions
declare -A MAPPING
MAPPING["amazonlinux2023"]="amzn2023"
MAPPING["amazonlinux2"]="amzn2"
MAPPING["amazonlinux1"]="amzn1"
MAPPING["centos-stream9"]="el7"
MAPPING["centos-stream8"]="el7"
MAPPING["centos7"]="el7"
MAPPING["centos6"]="el6"
# CentOS 5 is NOT valid.
# MAPPING["centos5"]="el5"

for VERSION in "${!MAPPING[@]}";
do
  DIST=${MAPPING[$VERSION]}
  echo "Create for OS: ${VERSION}"
  mkdir -p $OUTPUT/$VERSION
  # Run the builder container
  docker run -it --rm \
             -v $OUTPUT/$VERSION:/data/$DIST/RPMS \
             chowrex/openssh-rpms:$VERSION
done

```

For more details, see file `docker.README.md`

## Security Notes

This package provide following options in `/etc/ssh/sshd_config` to work like triditional sshd.

```
PubkeyAcceptedAlgorithms +ssh-rsa
PermitRootLogin yes
PasswordAuthentication yes
UseDNS no
UsePAM yes
KexAlgorithms -diffie-hellman-group1-sha1,diffie-hellman-group1-sha256,diffie-hellman-group14-sha1,diffie-hellman-group14-sha256,diffie-hellman-group15-sha256,diffie-hellman-group15-sha512,diffie-hellman-group16-sha256,diffie-hellman-group16-sha512,diffie-hellman-group17-sha512,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha1,diffie-hellman-group-exchange-sha256,diffie-hellman-group-exchange-sha512
```
