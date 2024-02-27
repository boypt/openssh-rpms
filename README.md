# Latest OpenSSH RPM / SRPM for old CentOS

- CentOS 5
- CentOS 6
- CentOS 7
- CentOS 8 (Stream 8)
- Amazon Linux 1
- Amazon Linux 2
- Amazon Linux 2023

Also tested in CentOS-like distros:

- UnionTech OS Server 20
- openEuler 22.03 (LTS-SP1)

## Current Version:

- OpenSSH 9.6p1 (see: [OpenSSH Official](https://www.openssh.com/))
- OpenSSL 3.0.13 / 3.0.9 (FIPS validated, see: [OpenSSL Official](https://www.openssl.org/source/))

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

```bash
# 1. Install build requirements listed above.
# 2. Edit version.env file if necessary.
# 3. Download source packages.
./pullsrc.sh
# if any error comes up, manally download the source files into the `downloads` dir.

# 4. Run the script to build RPMs. 
./compile.sh
```


### Install RPMs

```bash
# Backup current SSH config
[[ -f /etc/ssh/sshd_config ]] && mv /etc/ssh/sshd_config /etc/ssh/sshd_config.$(date +%Y%m%d)

# Install compiled packages.
RPMDIR="$PWD/$(./compile.sh GETEL)/RPMS/$(uname -m)"
find $RPMDIR -type f ! -name '*debug*' | xargs sudo yum --disablerepo=* localinstall -y

# in case host key files got permissions too open.
chmod -v 600 /etc/ssh/ssh_host_*_key

# For CentOS7+:
# in some cases previously installed systemd unit file is left on disk after upgrade.
# causes systemd mixing unit files and initscripts units provided by this package.
if [[ -d /run/systemd/system && -f /usr/lib/systemd/system/sshd.service ]]; then
    mv /usr/lib/systemd/system/sshd.service /usr/lib/systemd/system/sshd.service.$(date +%Y%m%d)
    systemctl daemon-reload
fi

# Restart service
service sshd restart
```

## Use Docker

See file `docker.README.md`

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
