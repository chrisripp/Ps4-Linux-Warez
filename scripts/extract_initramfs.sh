#!/bin/bash

set -e

A7Z=$(which 7za 2>/dev/null) || true
GZIP=$(which gzip 2>/dev/null) || true
ZIP=$(which zip 2>/dev/null) || true
XZ=$(which xz 2>/dev/null) || true

usage() {
	cat <<_XXX_
Usage: $0 <cpio file> <out dir>
_XXX_
}

uncompressfs() {
	if $(file "${1}" | grep -qi ": 7-zip"); then
		7za x "${1}" -so
	elif $(file "${1}" | grep -qi ": zip"); then
		unzip -p "${1}"
	elif $(file "${1}" | grep -qi ": gzip"); then
		gzip -cd "${1}"
	elif $(file "${1}" | grep -qi ": XZ"); then
		xz -cd "${1}"
	else
		#gunzip -cd "${1}"
		cat "${1}"
	fi
}

if [ "$#" -lt 2 ]; then
	usage
	exit 1
fi

if [ -z "$1" ] || [ ! -f "$1" ] || [ ! -r "$1" ]; then
	usage
	exit 1
else
	in_file=$1
	[ "${in_file:0:1}" != "/" ] && in_file=$(pwd)/${in_file}
fi

if [ -z "$2" ]; then
	usage
	exit 1
else
	out_dir=$2
	if [ ! -d "$out_dir" ]; then
		if ! mkdir -p "$out_dir" ; then
			usage
			exit 1
		fi
	fi
fi

cd "$out_dir"

uncompressfs "$in_file" | cpio -i -d -H newc --no-absolute-filenames --preserve-modification-time --no-preserve-owner --unconditional -v
ret=$?
[ $ret -ne 0 ] && echo "An error occured in extracting archive (code: $ret)!"

cd ..