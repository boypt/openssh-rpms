# OpenSSH RPMs for old CentOS

For some reasons I have to maintain OpenSSH up to date packages for CentOS versions that are no longer have supports.

This openssh package has OpenSSL statically linked.

## Current Version:

- OpenSSH 8.7p1
- OpenSSL 1.1.1k

## Supported CentOS:

- CentOS 5
- CentOS 6
- CentOS 7

## Build Requirements:

```
yum groupinstall -y "Development Tools"
yum install -y rpm-build pam-devel krb5-devel zlib-devel
```

### for CentOS5:

- Perl 5.10+ is needed (just `./configure.gnu && make && make install`)
- gcc44 is prefered


