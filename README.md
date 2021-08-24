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

## Security

As OLD system still on production, the reasons are not for TOP security, but for compatibility.

Thus this package provede the following options in `sshd_config` to act like the triditional version sshd.

```
UsePAM yes
PermitRootLogin yes
UseDNS no
```

If this is not what you want, change them in `/etc/ssh/sshd_config`
