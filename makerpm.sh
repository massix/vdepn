#!/bin/sh

git clean -fx

echo "Version is $1"

VERSION=$1

./autogen.sh
./configure --prefix=/usr
make DESTDIR=/home/$USER/rpmbuild/BUILDROOT/vdepn-$1-1.i386 install

echo "Modifying .spec file"

sed -i "s/Version: [0-9].[0-9].[0-9]/Version: ${VERSION}/" ~/rpmbuild/vdepn.spec

rpmbuild -ba ~/rpmbuild/vdepn.spec

su -c 'rpm -Uvh ~/rpmbuild/RPMS/i386/vdepn-$VERSION-1.rpm'
