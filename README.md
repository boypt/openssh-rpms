# Latest OpenSSH RPM / SRPM for old CentOS

- CentOS 5
- CentOS 6
- CentOS 7
- Amazon Linux 1
- Amazon Linux 2
- Amazon Linux 2023

## Current Version:

- OpenSSH 9.6p1
- OpenSSL 3.0.13 / 3.0.9 (FIPS validated, see: [[OpenSSL Official](https://www.openssl.org/source/))

The build script reads `version.env` for actual version definitions.

## Build Requirements:

```bash
yum groupinstall -y "Development Tools"
yum install -y imake rpm-build pam-devel krb5-devel zlib-devel libXt-devel libX11-devel gtk2-devel perl-IPC-Cmd

# For CentOS5:
yum install gcc44
```

## Usage

### Build RPMs

```bash
# 1. Install build requirements as listed above.
# 2. Edit version.env file if you want a specific version of openssh/openssl combination (or maybe I havn't updated to the latest).

# 3. Download source packages.
# if any error comes up, manally download the source files into the `downloads` dir.
./pullsrc.sh

# 4. Run the script to build RPMs. 
./compile.sh
# For CentOS 5 
# ./compile.sh el5
# CentOS5 didn't set the variable of `${dist}`, manually run the script with argument 
```


### Install RPMs

```bash
# Backup current SSH config
if test -e /etc/ssh/sshd_config; then
  mv /etc/ssh/sshd_config /etc/ssh/sshd_config.$(date +%Y%m%d)
fi

# Force install compiled packages.
yum install -y coreutils
OS_DIST="$(rpm --eval '%{?dist}'|tr -d '.')"
[ -z "$OS_DIST" ] && OS_DIST="el5"
BASE_PATH="$PWD/$OS_DIST/RPMS/$(uname -m)"

yum --disablerepo=* localinstall $BASE_PATH/openssh-*.rpm

# in case host key files got permissions too open.
chmod -v 600 /etc/ssh/ssh_host_*_key

# For OSs CentOS7:
# sometimes the previous installed systemd unit file is left on disk,
# which causes systemd mixing unit files and initscripts units provided by this package.
if [[ -d /run/systemd/system ]]; then
    mv /usr/lib/systemd/system/sshd.service /usr/lib/systemd/system/sshd.service.$(date +%Y%m%d)
    systemctl daemon-reload
    cp /run/systemd/generator.late/sshd.service /usr/lib/systemd/system/sshd.service 
fi

# Restart service
service sshd restart
```

## Security Notes

For **OLD** systems that are still in production, TOP security is hardly our first concern, while compatibility is.

This package provide following options in `/etc/ssh/sshd_config` to work like triditional sshd.

```
PubkeyAcceptedAlgorithms +ssh-rsa
PermitRootLogin yes
PasswordAuthentication yes
UseDNS no
UsePAM yes
KexAlgorithms -diffie-hellman-group1-sha1,diffie-hellman-group1-sha256,diffie-hellman-group14-sha1,diffie-hellman-group14-sha256,diffie-hellman-group15-sha256,diffie-hellman-group15-sha512,diffie-hellman-group16-sha256,diffie-hellman-group16-sha512,diffie-hellman-group17-sha512,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha1,diffie-hellman-group-exchange-sha256,diffie-hellman-group-exchange-sha512
```

## Use Docker

See file `docker.README.md`
