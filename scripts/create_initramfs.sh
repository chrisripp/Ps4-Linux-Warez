#!/bin/bash

set -e

A7Z=$(which 7za 2>/dev/null) || true
GZIP=$(which gzip 2>/dev/null) || true
ZIP=$(which zip 2>/dev/null) || true
XZ=$(which xz 2>/dev/null) || true

usage() {
	cat <<_XXX_
Usage: $0 <cpio file> <in dir>
_XXX_
}

compressfs() {
	if [ "$(echo "${1}" |rev |cut -d. -f1 | rev)" = "7z" -a -n "$A7Z" ]; then
		7za a ${1} -si
	elif [ "$(echo "${1}" |rev |cut -d. -f1 | rev)" = "zip" -a -n "$ZIP" ]; then
		zip "${1}" -
	elif [ "$(echo "${1}" |rev |cut -d. -f1 | rev)" = "gz" -a -n "$GZIP" ]; then
		gzip -c > "${1}"
	elif [ "$(echo "${1}" |rev |cut -d. -f1 | rev)" = "xz" -a -n "$XZ" ]; then
		xz -c > "${1}"
	else
		cat > "${1}"
	fi
}

if [ "$#" -lt 2 ]; then
	usage
	exit 1
fi

if [ -z "$1" ] || ([ -e "$1" ] && ([ ! -f "$1" ] || [ ! -w "$1" ])); then
	usage
	exit 1
else
	out_file=$1
	[ "${out_file:0:1}" != "/" ] && out_file=$(pwd)/${out_file}
fi

if [ -z "$2" ]; then
	usage
	exit 1
else
	in_dir=$2
	if [ ! -d "$in_dir" ]; then
		usage
		exit 1
	fi
fi

cd "$in_dir"

find . | cpio -o -H newc | compressfs "$out_file"
ret=$?
[ $ret -ne 0 ] && echo "An error occured in creating archive (code: $ret)!"

cd ..