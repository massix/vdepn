#!/bin/sh

git clean -fx

echo "Version is $1-$2"

VERSION=$1
RELEASE=$2

./autogen.sh
./configure --prefix=/usr
make DESTDIR=/home/$USER/rpmbuild/BUILDROOT/vdepn-$1-$2.i386 install

echo "Modifying .spec file"

sed -i "s/Version: [0-9].[0-9].[0-9]/Version: ${VERSION}/" ~/rpmbuild/vdepn.spec
sed -i "s/Release: [0-9]/Release: ${RELEASE}/" ~/rpmbuild/vdepn.spec

rpmbuild -ba ~/rpmbuild/vdepn.spec

su -c "rpm -Uvh /home/massi/rpmbuild/RPMS/i386/vdepn-${VERSION}-${RELEASE}.i386.rpm"
