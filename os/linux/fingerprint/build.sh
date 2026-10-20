#!/usr/bin/bash
# Build Fedora's libfprint with ft9366-driver.patch (see README.md). User-level,
# no sudo: builds in a throwaway rootless podman container of this Fedora release.
# RPMs land in ~/.cache/libfprint-ft9366. Then: sudo bash install.sh
set -e
cd "$(dirname "$(readlink -f "$0")")"

out=$HOME/.cache/libfprint-ft9366
mkdir -p "$out"
rm -f "$out"/*.rpm

podman run --rm --security-opt label=disable \
    -v "$PWD:/src:ro" -v "$out:/out" \
    "registry.fedoraproject.org/fedora:$(rpm -E %fedora)" bash -euc '
dnf -y -q install rpm-build
cd /tmp
dnf -q download --source libfprint
rpm -i libfprint-*.src.rpm 2>/dev/null
spec=~/rpmbuild/SPECS/libfprint.spec
cp /src/ft9366-driver.patch ~/rpmbuild/SOURCES/
# -e tags the release (1.ft9366.fc44), so rpm -q shows which build is installed
sed -i "s/^Release:.*/Release:        %autorelease -e ft9366/
        /^Source0:/a Patch0:         ft9366-driver.patch" $spec
dnf -y -q builddep $spec >/dev/null
rpmbuild -bb --nodebuginfo $spec >/tmp/build.log 2>&1 || { tail -40 /tmp/build.log; exit 1; }
cp ~/rpmbuild/RPMS/*/*.rpm /out/
'
ls "$out"
