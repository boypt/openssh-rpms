%{?!opensslver: %global opensslver 3.0.8}
%{?!opensshver: %global opensshver 9.6p1}
%{?!perlver: %global perlver 5.38.2}
# Control openssl dependency
# 0: build without openssl
# 1: use system openssl
# 2: build openssl statically
%{!?with_openssl: %global with_openssl 2}

# Force to build openssl statically for el5/6
%if %{with_openssl} == 1
%global with_openssl 2
%endif

%global ver %{?opensshver}
%global rel %{?opensshpkgrel}%{?dist}

# OpenSSH privilege separation requires a user & group ID
%global sshd_uid    74
%global sshd_gid    74

# Version of ssh-askpass
%global aversion 1.2.4.1

# Do we want to disable building of x11-askpass? (1=yes 0=no)
%global no_x11_askpass 0

# Do we want to disable building of gnome-askpass? (1=yes 0=no)
%global no_gnome_askpass 0


# Do we want smartcard support (1=yes 0=no)
%global scard 0

# Use GTK2 instead of GNOME in gnome-ssh-askpass
%global gtk2 1

# Use build6x options for older RHEL builds
# RHEL 7 not yet supported
%if 0%{?rhel} > 6
%global build6x 0
%else
%global build6x 1
%endif

# Annotate content below to ENFORCE using SSL
#%global without_openssl 0
## build without openssl where 1.1.1 is not available
#%if 0%{?fedora} <= 28
#%global without_openssl 1
#%endif
#%if 0%{?rhel} <= 7
#%global without_openssl 1
#%endif

# Do we want kerberos5 support (1=yes 0=no)
%global kerberos5 0

# Reserve options to override askpass settings with:
# rpm -ba|--rebuild --define 'skip_xxx 1'
%{?skip_x11_askpass:%global no_x11_askpass 1}
%{?skip_gnome_askpass:%global no_gnome_askpass 1}

# Add option to build without GTK2 for older platforms with only GTK+.
# RedHat <= 7.2 and Red Hat Advanced Server 2.1 are examples.
# rpm -ba|--rebuild --define 'no_gtk2 1'
%{?no_gtk2:%global gtk2 0}

# Is this a build for RHL 6.x or earlier?
%{?build_6x:%global build6x 1}

# If this is RHL 6.x, the default configuration has sysconfdir in /usr/etc.
%if %{build6x}
%global _sysconfdir /etc
%endif


# Options for Smartcard support: (needs libsectok and openssl-engine)
# rpm -ba|--rebuild --define "smartcard 1"
%{?smartcard:%global scard 1}

# Is this a build for the rescue CD (without PAM)? (1=yes 0=no)
%global rescue 0
%{?build_rescue:%global rescue 1}

# Turn off some stuff for resuce builds
%if %{rescue}
%global kerberos5 0
%endif

Summary: The OpenSSH implementation of SSH protocol version 2.
Name: openssh
Version: %{ver}
%if %{rescue}
Release: %{rel}rescue
%else
Release: %{rel}
%endif
URL: https://www.openssh.com/portable.html
Source0: https://ftp.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-%{version}.tar.gz
Source1: http://www.jmknoble.net/software/x11-ssh-askpass/x11-ssh-askpass-%{aversion}.tar.gz
Source2: sshd.pam.el5
%if %{with_openssl} == 2
Source3: https://www.openssl.org/source/openssl-%{opensslver}.tar.gz
Source4: https://www.cpan.org/src/5.0/perl-%{perlver}.tar.gz
%endif

# glibc-headers-2.5 have endian.h but didn't define htole64
Patch0: have_endian.patch
License: BSD
Group: Applications/Internet
BuildRoot: %{_tmppath}/%{name}-%{version}-buildroot
Obsoletes: ssh
%if %{build6x}
PreReq: initscripts >= 5.00
%else
Requires: initscripts >= 5.20
%endif
#BuildRequires: perl
%if %{with_openssl} == 1
BuildRequires: openssl-devel
%endif
BuildRequires: /bin/login
%if ! %{build6x}
BuildRequires: glibc-devel, pam
%else
BuildRequires: /usr/include/security/pam_appl.h
%endif
%if ! %{no_x11_askpass}
BuildRequires: /usr/include/X11/Xlib.h
# Xt development tools
BuildRequires: libXt-devel
# Provides xmkmf
BuildRequires: imake
# Rely on relatively recent gtk
%if %{gtk2}
BuildRequires: gtk2-devel
%endif
%endif
%if ! %{no_gnome_askpass}
BuildRequires: pkgconfig
%endif
%if %{kerberos5}
BuildRequires: krb5-devel
BuildRequires: krb5-libs
%endif

%package clients
Summary: OpenSSH clients.
Requires: openssh = %{version}-%{release}
Group: Applications/Internet
Obsoletes: ssh-clients

%package server
Summary: The OpenSSH server daemon.
Group: System Environment/Daemons
Obsoletes: ssh-server
Requires: openssh = %{version}-%{release}, chkconfig >= 0.9
%if ! %{build6x}
Requires: /etc/pam.d/system-auth
%endif

%package askpass
Summary: A passphrase dialog for OpenSSH and X.
Group: Applications/Internet
Requires: openssh = %{version}-%{release}
Obsoletes: ssh-extras

%package askpass-gnome
Summary: A passphrase dialog for OpenSSH, X, and GNOME.
Group: Applications/Internet
Requires: openssh = %{version}-%{release}
Obsoletes: ssh-extras

%description
SSH (Secure SHell) is a program for logging into and executing
commands on a remote machine. SSH is intended to replace rlogin and
rsh, and to provide secure encrypted communications between two
untrusted hosts over an insecure network. X11 connections and
arbitrary TCP/IP ports can also be forwarded over the secure channel.

OpenSSH is OpenBSD's version of the last free version of SSH, bringing
it up to date in terms of security and features, as well as removing
all patented algorithms to separate libraries.

This package includes the core files necessary for both the OpenSSH
client and server. To make this package useful, you should also
install openssh-clients, openssh-server, or both.

%description clients
OpenSSH is a free version of SSH (Secure SHell), a program for logging
into and executing commands on a remote machine. This package includes
the clients necessary to make encrypted connections to SSH servers.
You'll also need to install the openssh package on OpenSSH clients.

%description server
OpenSSH is a free version of SSH (Secure SHell), a program for logging
into and executing commands on a remote machine. This package contains
the secure shell daemon (sshd). The sshd daemon allows SSH clients to
securely connect to your SSH server. You also need to have the openssh
package installed.

%description askpass
OpenSSH is a free version of SSH (Secure SHell), a program for logging
into and executing commands on a remote machine. This package contains
an X11 passphrase dialog for OpenSSH.

%description askpass-gnome
OpenSSH is a free version of SSH (Secure SHell), a program for logging
into and executing commands on a remote machine. This package contains
an X11 passphrase dialog for OpenSSH and the GNOME GUI desktop
environment.

%global perl_version_ok %( \
    if command -v perl >/dev/null 2>&1; then \
        perl -e ' \
            if ($] >= 5.010) { \
                print "1"; \
            } else { \
                print "0"; \
            }; \
        ' \
    else \
        echo "0"; \
    fi \
)


%prep
%if ! %{no_x11_askpass}
%setup -q -a 1
%else
%setup -q
%endif

# Applay a patch if glibc version is 2.5, not sure about other versions
%global glibc_version %(ldd --version 2>&1 | head -n1 | grep -oP '[0-9.]+')
echo "GLIBC version: %{glibc_version}"
%if "%{glibc_version}" <= "2.5" && "%{opensshver}" == "9.9p2"
%patch0 -p0
%endif

%if %{with_openssl} == 2

# the OpenSSL build require perl version >= 5.10.0
# the EL5 perl in repo is 5.8, have to build our own.
%if "%{expand:%{perl_version_ok}}" == "0"

%define perl_dir %{_builddir}/%{name}-%{version}/perl
mkdir -p perl
tar xfz %{SOURCE4} --strip-components=1 -C perl
# perl is only needed during this build process.
pushd perl
mkdir -p perlbin
./configure.gnu --prefix=$PWD/perlbin
make %{?_smp_mflags}
make install.perl
export PATH=$PWD/perlbin/bin:$PATH
popd

# end of building perl
%endif

# Build OpenSSL
%define openssl_dir %{_builddir}/%{name}-%{version}/openssl
mkdir -p openssl
tar xfz %{SOURCE3} --strip-components=1 -C openssl
pushd openssl
./config shared zlib -fPIC
make %{?_smp_mflags}
popd

# end of with_openssl == 2
%endif

%build
%if %{rescue}
CFLAGS="$RPM_OPT_FLAGS -Os"; export CFLAGS
%endif

%if %{with_openssl} == 2
# Add OpenSSL library
export LD_LIBRARY_PATH="%{openssl_dir}"
%endif
%configure \
	--sysconfdir=%{_sysconfdir}/ssh \
	--libexecdir=%{_libexecdir}/openssh \
	--datadir=%{_datadir}/openssh \
	--with-default-path=/usr/local/bin:/bin:/usr/bin \
	--with-superuser-path=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin \
	--with-privsep-path=%{_var}/empty/sshd \
	--with-md5-passwords \
	--mandir=%{_mandir} \
	--with-mantype=man \
	--disable-strip \
%if %{with_openssl} == 2
	--with-ssl-dir="%{openssl_dir}" \
%endif
%if %{with_openssl} == 0
	--without-openssl \
%endif
%if %{with_openssl} > 0
	--with-ssl-engine \
%endif
	--with-zlib \
%if %{scard}
	--with-smartcard \
%endif
%if %{rescue}
	--without-pam \
%else
	--with-pam \
%endif
%if %{kerberos5}
	 --with-kerberos5=$K5DIR \
%endif


%if %{with_openssl} == 2
#perl -pi -e "s|-lcrypto|%{_libdir}/libcrypto.a|g" Makefile
# Add OpenSSL library
perl -pi -e "s|-lcrypto|%{openssl_dir}/libcrypto.a -lpthread|g" Makefile
%endif

make %{?_smp_mflags}

%if ! %{no_x11_askpass}
pushd x11-ssh-askpass-%{aversion}
%configure --libexecdir=%{_libexecdir}/openssh
xmkmf -a
make -j
popd
%endif

# Define a variable to toggle gnome1/gtk2 building.  This is necessary
# because RPM doesn't handle nested %if statements.
%if %{gtk2}
	gtk2=yes
%else
	gtk2=no
%endif

%if ! %{no_gnome_askpass}
pushd contrib
if [ $gtk2 = yes ] ; then
	make gnome-ssh-askpass2
	mv gnome-ssh-askpass2 gnome-ssh-askpass
else
	make gnome-ssh-askpass1
	mv gnome-ssh-askpass1 gnome-ssh-askpass
fi
popd
%endif

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p -m755 $RPM_BUILD_ROOT%{_sysconfdir}/ssh
mkdir -p -m755 $RPM_BUILD_ROOT%{_libexecdir}/openssh
mkdir -p -m755 $RPM_BUILD_ROOT%{_var}/empty/sshd

make install DESTDIR=$RPM_BUILD_ROOT
# Modify sshd config file.
cat << EOF >> $RPM_BUILD_ROOT/etc/ssh/sshd_config
PubkeyAcceptedAlgorithms +ssh-rsa
PermitRootLogin yes
PasswordAuthentication yes
UseDNS no
UsePAM yes
KexAlgorithms -diffie-hellman-group1-sha1,diffie-hellman-group1-sha256,diffie-hellman-group14-sha1,diffie-hellman-group14-sha256,diffie-hellman-group15-sha256,diffie-hellman-group15-sha512,diffie-hellman-group16-sha256,diffie-hellman-group16-sha512,diffie-hellman-group17-sha512,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha1,diffie-hellman-group-exchange-sha256,diffie-hellman-group-exchange-sha512
EOF
# Modify ssh config file, to ensure that traditional RSA-type key authentication is available to avoid git clone failures.
# See: https://support.genymotion.com/hc/en-us/articles/9500420360093-I-get-the-error-no-matching-host-key-type-found-Their-offer-ssh-rsa-when-trying-to-connect-with-SSH
cat << EOF >> $RPM_BUILD_ROOT/etc/ssh/ssh_config
Host *
    HostKeyAlgorithms = +ssh-rsa
    PubkeyAcceptedAlgorithms = +ssh-rsa
EOF

install -m755 contrib/ssh-copy-id $RPM_BUILD_ROOT%{_bindir}/
install -m644 contrib/ssh-copy-id.1 $RPM_BUILD_ROOT%{_mandir}/man1/
install -d $RPM_BUILD_ROOT/etc/pam.d/
install -d $RPM_BUILD_ROOT/etc/rc.d/init.d
install -d $RPM_BUILD_ROOT%{_libexecdir}/openssh
# Using custom PAM file
install -m644 %{SOURCE2}     $RPM_BUILD_ROOT/etc/pam.d/sshd
install -m755 contrib/redhat/sshd.init $RPM_BUILD_ROOT/etc/rc.d/init.d/sshd

%if ! %{no_x11_askpass}
install x11-ssh-askpass-%{aversion}/x11-ssh-askpass $RPM_BUILD_ROOT%{_libexecdir}/openssh/x11-ssh-askpass
ln -s x11-ssh-askpass $RPM_BUILD_ROOT%{_libexecdir}/openssh/ssh-askpass
%endif

%if ! %{no_gnome_askpass}
install contrib/gnome-ssh-askpass $RPM_BUILD_ROOT%{_libexecdir}/openssh/gnome-ssh-askpass
%endif

%if ! %{scard}
	 rm -f $RPM_BUILD_ROOT/usr/share/openssh/Ssh.bin
%endif

%if ! %{no_gnome_askpass}
install -m 755 -d $RPM_BUILD_ROOT%{_sysconfdir}/profile.d/
install -m 755 contrib/redhat/gnome-ssh-askpass.csh $RPM_BUILD_ROOT%{_sysconfdir}/profile.d/
install -m 755 contrib/redhat/gnome-ssh-askpass.sh $RPM_BUILD_ROOT%{_sysconfdir}/profile.d/
%endif

perl -pi -e "s|$RPM_BUILD_ROOT||g" $RPM_BUILD_ROOT%{_mandir}/man*/*

%clean
rm -rf $RPM_BUILD_ROOT

%triggerun server -- ssh-server
if [ "$1" != 0 -a -r /var/run/sshd.pid ] ; then
	touch /var/run/sshd.restart
fi

%triggerun server -- openssh-server < 2.5.0p1
# Count the number of HostKey and HostDsaKey statements we have.
gawk	'BEGIN {IGNORECASE=1}
	 /^hostkey/ || /^hostdsakey/ {sawhostkey = sawhostkey + 1}
	 END {exit sawhostkey}' /etc/ssh/sshd_config
# And if we only found one, we know the client was relying on the old default
# behavior, which loaded the the SSH2 DSA host key when HostDsaKey wasn't
# specified.  Now that HostKey is used for both SSH1 and SSH2 keys, specifying
# one nullifies the default, which would have loaded both.
if [ $? -eq 1 ] ; then
	echo HostKey /etc/ssh/ssh_host_rsa_key >> /etc/ssh/sshd_config
	echo HostKey /etc/ssh/ssh_host_dsa_key >> /etc/ssh/sshd_config
fi

%triggerpostun server -- ssh-server
if [ "$1" != 0 ] ; then
	/sbin/chkconfig --add sshd
	if test -f /var/run/sshd.restart ; then
		rm -f /var/run/sshd.restart
		/sbin/service sshd start > /dev/null 2>&1 || :
	fi
fi

%pre server
%{_sbindir}/groupadd -r -g %{sshd_gid} sshd 2>/dev/null || :
%{_sbindir}/useradd -d /var/empty/sshd -s /bin/false -u %{sshd_uid} \
	-g sshd -M -r sshd 2>/dev/null || :

%post server
/sbin/chkconfig --add sshd

%postun server
/sbin/service sshd condrestart > /dev/null 2>&1 || :

%preun server
if [ "$1" = 0 ]
then
	/sbin/service sshd stop > /dev/null 2>&1 || :
	/sbin/chkconfig --del sshd
fi

%files
%defattr(-,root,root)
%doc CREDITS ChangeLog INSTALL LICENCE OVERVIEW README* PROTOCOL* TODO
%attr(0755,root,root) %{_bindir}/scp
%attr(0644,root,root) %{_mandir}/man1/scp.1*
%attr(0755,root,root) %dir %{_sysconfdir}/ssh
%attr(0600,root,root) %config(noreplace) %{_sysconfdir}/ssh/moduli
%if ! %{rescue}
%attr(0755,root,root) %{_bindir}/ssh-keygen
%attr(0644,root,root) %{_mandir}/man1/ssh-keygen.1*
%attr(0755,root,root) %dir %{_libexecdir}/openssh
%attr(4711,root,root) %{_libexecdir}/openssh/ssh-keysign
%attr(0755,root,root) %{_libexecdir}/openssh/ssh-pkcs11-helper
%attr(0755,root,root) %{_libexecdir}/openssh/ssh-sk-helper
%attr(0644,root,root) %{_mandir}/man8/ssh-keysign.8*
%attr(0644,root,root) %{_mandir}/man8/ssh-pkcs11-helper.8*
%attr(0644,root,root) %{_mandir}/man8/ssh-sk-helper.8*
%endif
%if %{scard}
%attr(0755,root,root) %dir %{_datadir}/openssh
%attr(0644,root,root) %{_datadir}/openssh/Ssh.bin
%endif

%files clients
%defattr(-,root,root)
%attr(0755,root,root) %{_bindir}/ssh
%attr(0644,root,root) %{_mandir}/man1/ssh.1*
%attr(0644,root,root) %{_mandir}/man5/ssh_config.5*
%attr(0644,root,root) %config(noreplace) %{_sysconfdir}/ssh/ssh_config
%if ! %{rescue}
%attr(2755,root,nobody) %{_bindir}/ssh-agent
%attr(0755,root,root) %{_bindir}/ssh-add
%attr(0755,root,root) %{_bindir}/ssh-keyscan
%attr(0755,root,root) %{_bindir}/sftp
%attr(0755,root,root) %{_bindir}/ssh-copy-id
%attr(0644,root,root) %{_mandir}/man1/ssh-agent.1*
%attr(0644,root,root) %{_mandir}/man1/ssh-add.1*
%attr(0644,root,root) %{_mandir}/man1/ssh-keyscan.1*
%attr(0644,root,root) %{_mandir}/man1/sftp.1*
%attr(0644,root,root) %{_mandir}/man1/ssh-copy-id.1*
%endif

%if ! %{rescue}
%files server
%defattr(-,root,root)
%dir %attr(0111,root,root) %{_var}/empty/sshd
%attr(0755,root,root) %{_sbindir}/sshd
%attr(0755,root,root) %{_libexecdir}/openssh/sshd-session
%attr(0755,root,root) %{_libexecdir}/openssh/sshd-auth
%attr(0755,root,root) %{_libexecdir}/openssh/sftp-server
%attr(0644,root,root) %{_mandir}/man8/sshd.8*
%attr(0644,root,root) %{_mandir}/man5/moduli.5*
%attr(0644,root,root) %{_mandir}/man5/sshd_config.5*
%attr(0644,root,root) %{_mandir}/man8/sftp-server.8*
%attr(0755,root,root) %dir %{_sysconfdir}/ssh
%attr(0600,root,root) %config(noreplace) %{_sysconfdir}/ssh/sshd_config
%attr(0600,root,root) %config(noreplace) /etc/pam.d/sshd
%attr(0755,root,root) %config /etc/rc.d/init.d/sshd
%endif

%if ! %{no_x11_askpass}
%files askpass
%defattr(-,root,root)
%doc x11-ssh-askpass-%{aversion}/README
%doc x11-ssh-askpass-%{aversion}/ChangeLog
%doc x11-ssh-askpass-%{aversion}/SshAskpass*.ad
%{_libexecdir}/openssh/ssh-askpass
%attr(0755,root,root) %{_libexecdir}/openssh/x11-ssh-askpass
%endif

%if ! %{no_gnome_askpass}
%files askpass-gnome
%defattr(-,root,root)
%attr(0755,root,root) %config %{_sysconfdir}/profile.d/gnome-ssh-askpass.*
%attr(0755,root,root) %{_libexecdir}/openssh/gnome-ssh-askpass
%endif
