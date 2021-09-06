#!/usr/bin/env bash

set -e

BASE_DIR="$(pwd)"

if [ -z "$1" ]; then
    echo "Usage: $0 <package dir> [<package name>] [--tool]"
    exit 1
fi

set -x

if [ -z "$2" ]; then
    PKG_NAME="$1"
else
    if [ "$2" = "--tool" ]; then
        IS_TOOL="-tool"
        PKG_NAME="$1"
    else
        PKG_NAME="$2"
    fi
fi

if [ "$3" = "--tool" ]; then
    IS_TOOL="-tool"
fi

mkdir -p "$BASE_DIR"/patches/$1

[ -d 3rdparty/$1 ] || (
    cd build
    xbstrap fetch $1
    xbstrap checkout $1
    xbstrap patch $1
)

cd 3rdparty/$1
[ -f "$BASE_DIR"/patches/$1/0001-Vinix-specific-changes.patch ] && (
    git reset HEAD~1
)
rm -f *.xbstrap
git add .
git commit --allow-empty -m "Vinix specific changes"
git format-patch -1
if [ "`cat 0001-Vinix-specific-changes.patch`" = "" ]; then
    rm 0001-Vinix-specific-changes.patch
    git reset HEAD~1
else
    mv 0001-Vinix-specific-changes.patch "$BASE_DIR"/patches/$1/
fi
touch checkedout.xbstrap fetched.xbstrap patched.xbstrap

cd "$BASE_DIR"/build
xbstrap regenerate $1

[ -z "$IS_TOOL" ] && rm -rf pkg-builds/$1
[ -z "$IS_TOOL" ] || rm -rf tool-builds/$PKG_NAME

xbstrap install$IS_TOOL --reconfigure $PKG_NAME
