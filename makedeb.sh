#!/bin/sh

git clean -fx

echo "Version is $1"

VERSION=$1
BUILDDIR=`pwd`/build
PATH="/sbin:$PATH"

./autogen.sh
./configure --prefix=/usr && \
make DESTDIR=${BUILDDIR} install

echo "Modifying control file"

sed -i "s/Version: [0-9].[0-9].*/Version: ${VERSION}/" ${BUILDDIR}/DEBIAN/control

dpkg -b ${BUILDDIR} vdepn-${VERSION}.deb

su -c "dpkg -i vdepn-${VERSION}.deb"
