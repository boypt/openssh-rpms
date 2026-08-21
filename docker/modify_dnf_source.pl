#!/usr/bin/perl

# Rewrite DNF repository baseurls for still-supported CentOS Stream EL
# (e.g. 9-stream). Uses multiple failover baseurls; vault handling for
# EOL 8-stream lives in docker/modify_yum_source.sh.
#
# Note on mirror base paths: each entry is a prefix; the script appends
# "/${path}" (e.g. "9-stream/BaseOS/x86_64/os") to build the final URL.
# We use https://mirrors.kernel.org/centos (kernel.org official mirror) as
# the second entry; https://mirrors.kernel.org/centos-stream is an equally
# valid alternative that also resolves to the same kernel.org edge mirror.

use strict;
use warnings;
use autodie;

my @mirrors = (
	'https://mirror.stream.centos.org',
	'https://mirrors.kernel.org/centos',
	'https://mirrors.aliyun.com/centos-stream',
	'https://mirrors.ustc.edu.cn/centos-stream',
	'https://ftp.iij.ad.jp/pub/linux/centos-stream',
	'https://ftp.yandex.ru/centos-stream',
);

if (@ARGV < 1) {
    die "Usage: $0 <filename1> <filename2> ...\n";
}

while (my $filename = shift @ARGV) {
    my $backup_filename = $filename . '.bak';
    rename $filename, $backup_filename;

    open my $input, "<", $backup_filename;
    open my $output, ">", $filename;

    while (<$input>) {
        s/^metalink/# metalink/;

        if (m/^name/) {
            my (undef, $repo, $arch) = split /-/;
            $repo =~ s/^\s+|\s+$//g;
            ($arch = defined $arch ? lc($arch) : '') =~ s/^\s+|\s+$//g;

            my $path;
            if ($repo =~ /^Extras/) {
                $path = "SIGs/\$releasever-stream/extras" . ($arch eq 'source' ? "/${arch}/" : "/\$basearch/") . "extras-common";
            } else {
                $path = "\$releasever-stream/$repo" . ($arch eq 'source' ? "/" : "/\$basearch/") . ($arch ne '' ? "${arch}/tree/" : "os");
            }

            for my $mirror (@mirrors) {
                $_ .= "baseurl=${mirror}/${path}\n";
            }
        }

        print $output $_;
    }
}