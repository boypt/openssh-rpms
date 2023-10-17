# Latest OpenSSH RPM / SRPM for old CentOS

For some reasons I have to maintain OpenSSH up to date for CentOS which no longer have offical supports.

- CentOS 5
- CentOS 6
- CentOS 7

## Current Version:

- OpenSSH 9.5p1
- OpenSSL 3.0.11 (static linked)

The build script reads `version.env` for actual version definitions.

## Build Requirements:

```
yum groupinstall -y "Development Tools"
yum install -y imake rpm-build pam-devel krb5-devel zlib-devel libXt-devel libX11-devel gtk2-devel perl-IPC-Cmd
```
### Note for CentOS 5:

- [Perl 5.10+](http://www.cpan.org/src/) is needed during build (`./configure.gnu && make && make install`)
- `gcc44` is prefered (`yum install gcc44`)

## Usage

```
# 1. Install build requirements as listed above.
# 2. Edit version.env file if you want a specific version of openssh/openssl combination (or maybe I havn't updated to the latest).

# 3. Download source packages.
# if any error comes up, just manally download the source tar files into the `downloads` dir.
./pullsrc.sh

# 4. Run the script to build RPMs. 
./compile.sh
# For CentOS 5, the default rpmbuild didn't set the variable of `${dist}`, manually run the script with argument `./compile.sh el5`
```

## Security

For **OLD** systems that are still on production, TOP security is hardly our first concern, while compatibility is.

This package provede the following options in `/etc/ssh/sshd_config` to work like the triditional sshd.

```
PubkeyAcceptedAlgorithms +ssh-rsa
UsePAM yes
PermitRootLogin yes
UseDNS no
```

