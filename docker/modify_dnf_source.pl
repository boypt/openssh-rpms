#!/usr/bin/perl

use strict;
use warnings;
use autodie;

my @mirrors = (
	'https://vault.centos.org/centos-stream',
	'https://mirrors.ustc.edu.cn/centos-stream',
	'https://mirrors.aliyun.com/centos-stream',
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