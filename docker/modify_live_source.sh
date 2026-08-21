#!/bin/bash
# Rewrite DNF repository baseurls for still-supported CentOS Stream EL
# (e.g. 9-stream). Uses multiple failover baseurls; vault handling for
# EOL 8-stream lives in docker/modify_vault_source.sh.
#
# DNF 4.x `baseurl` is `list` type: space-or-comma-separated URLs on ONE line;
# repeated `baseurl=` keys overwrite (only the last survives) — see
# dnf.readthedocs.io/conf_ref.html — so all mirrors go on a single baseurl= line.
#
# Note on mirror base paths: each entry is a prefix; the script appends
# "/${path}" (e.g. "9-stream/BaseOS/x86_64/os") to build the final URL.
# We use https://mirrors.kernel.org/centos (kernel.org official mirror) as
# the second entry; https://mirrors.kernel.org/centos-stream is an equally
# valid alternative that also resolves to the same kernel.org edge mirror.

# Official-first mirror list for still-supported Stream releases
LIVE_MIRRORS=(
	"https://mirror.stream.centos.org"
	"https://mirrors.kernel.org/centos"
	"https://mirrors.aliyun.com/centos-stream"
	"https://mirrors.ustc.edu.cn/centos-stream"
	"https://ftp.iij.ad.jp/pub/linux/centos-stream"
	"https://ftp.yandex.ru/centos-stream"
)

usage() {
	echo "Usage: $0 <filename1> <filename2> ..." >&2
	exit 1
}

if [[ $# -lt 1 ]]; then
	usage
fi

# Trim leading/trailing whitespace from a string (result on stdout)
trim() {
	local s="$1"
	s="${s#"${s%%[![:space:]]*}"}"
	s="${s%"${s##*[![:space:]]}"}"
	printf '%s' "$s"
}

while [[ $# -gt 0 ]]; do
	filename="$1"
	shift
	backup="${filename}.bak"
	mv "$filename" "$backup" || continue
	while IFS= read -r line; do
		# comment out any metalink line (mirrors are preferred)
		if [[ $line == metalink* ]]; then
			line="# ${line}"
		fi
		if [[ $line == name* ]]; then
			# split the "name=... - <repo> - <arch>" line on dashes
			IFS='-' read -ra parts <<<"$line"
			repo=$(trim "${parts[1]:-}")
			arch=$(trim "${parts[2]:-}")
			arch=${arch,,}
			if [[ $repo == Extras* ]]; then
				if [[ $arch == source ]]; then
					path="SIGs/\$releasever-stream/extras/${arch}/extras-common"
				else
					path="SIGs/\$releasever-stream/extras/\$basearch/extras-common"
				fi
			else
				if [[ $arch == source ]]; then
					path="\$releasever-stream/${repo}/source/tree/"
				else
					path="\$releasever-stream/${repo}/\$basearch/os"
				fi
			fi
			printf '%s\n' "$line"
			# Single baseurl= line with all mirrors space-separated (DNF `list`
			# type: repeated `baseurl=` keys overwrite, so one line is required).
			urls=""
			sep=""
			for mirror in "${LIVE_MIRRORS[@]}"; do
				urls+="${sep}${mirror}/${path}"
				sep=" "
			done
			printf 'baseurl=%s\n' "$urls"
		else
			printf '%s\n' "$line"
		fi
	done <"$backup" >"$filename"
done
