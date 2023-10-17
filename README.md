# OpenSSH RPMs for old CentOS

For some reasons I have to maintain OpenSSH up to date for CentOSs that are no longer have supports.

This openssh package has OpenSSL statically linked.

## Current Version:

- OpenSSH 9.5p1
- OpenSSL 3.0.11

The script reads `version.env` for actual verion definitions.

## Supported CentOS:

- CentOS 5
- CentOS 6
- CentOS 7

## Build Requirements:

```
yum groupinstall -y "Development Tools"
yum install -y imake rpm-build pam-devel krb5-devel zlib-devel libXt-devel libX11-devel gtk2-devel perl-IPC-Cmd
```
### Note for CentOS 5:

- Perl 5.10+ is needed (`./configure.gnu && make && make install`)
- `gcc44` is prefered

## Usage

```
# Edit version.env file if you want a specific version of openssh/openssl combination (or maybe I havn't updated to the latest).

# Download source packages.
# if any error comes up, just manally download the source tar files into the `downloads` dir.
./pullsrc.sh

# Run the script to build RPMs. 
# For CentOS 5, the default rpmbuild didn't set the variable of `${dist}`, manually run the script with argument `./compile.sh el5`
./compile.sh
```

## Security

For **OLD** systems that are still on production, TOP security is hardly the first concern, while compatibility is.

This package provede the following options in `/etc/ssh/sshd_config` to work like the triditional sshd.

```
PubkeyAcceptedAlgorithms +ssh-rsa
UsePAM yes
PermitRootLogin yes
UseDNS no
```

