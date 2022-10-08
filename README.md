# OpenSSH RPMs for old CentOS

For some reasons I have to maintain OpenSSH up to date for CentOSs that are no longer have supports.

This openssh package has OpenSSL statically linked.

## Current Version:

- OpenSSH 9.1p1
- OpenSSL 1.1.1q

## Supported CentOS:

- CentOS 5
- CentOS 6
- CentOS 7

## Build Requirements:

```
yum groupinstall -y "Development Tools"
yum install -y imake rpm-build pam-devel krb5-devel zlib-devel libXt-devel libX11-devel gtk2-devel
```
### for CentOS5:

- Perl 5.10+ is needed (just `./configure.gnu && make && make install`)
- `gcc44` is prefered

## Usage

```
# Edit version.env file if you want a specific version of openssh/openssl combination (or maybe I havn't updated to the latest).

# this script try to download source packages.
# if any error come up, just manally put the source tar file into the `downloads` dir.
./pullsrc.sh

# just run the script to build RPMs. 
# For CentOS 5, the rpmbuild didn't set the variable of `.el`, you may need to run the script by `./compile.sh el5`
./compile.sh
```

## Security

As OLD systems that are still on production, TOP security is hardly the first concern, while compatibility is.

This package provede the following options in `/etc/ssh/sshd_config` to act like the triditional version sshd.

```
PubkeyAcceptedAlgorithms +ssh-rsa
UsePAM yes
PermitRootLogin yes
UseDNS no
```

