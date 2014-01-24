#!/bin/bash

PREFIX=${1:-}
DIR_SRC=$HOME/workspaces
DIR_DS_GIT=389-ds-base
DIR_SPEC_GIT=389-ds-base-spec
DIR_RPM=$HOME/rpmbuild
DIR_INSTALL=$HOME/install   # a.k.a /directory/where/389-ds/is/installed
DIR_SRC_DIR=$DIR_SRC/$DIR_DS_GIT
DIR_SRC_PKG=$DIR_SRC/$DIR_SPEC_GIT
TMP=/tmp/tempo$$
SED_SCRIPT=/tmp/script$$
 

#
# Checkout the source/spec
#
initialize()
{
	for i in $DIR_DS_GIT $DIR_SPEC_GIT
	do 
		rm -rf "$DIR_SRC/$i"
		mkdir "$DIR_SRC/$i"
	done
	cd $DIR_SRC_DIR
	git clone http://git.fedorahosted.org/git/389/ds.git

	cd $DIR_SRC_PKG
	git clone http://pkgs.fedoraproject.org/cgit/389-ds-base.git/
}

#
# Compile 389-DS
#
compile()
{
	cd $DIR_SRC_PKG
	cp $DIR_SRC_PKG/389-ds-base.spec 	 $DIR_RPM/SPECS
	cp $DIR_SRC_PKG/389-ds-base-git.sh	 $DIR_RPM/SOURCES
	cp $DIR_SRC_PKG/389-ds-base-devel.README $DIR_RPM/SOURCES
	cd $DIR_SRC_DIR
	rm -f /tmp/*bz2
	TAG=HEAD sh $DIR_SRC_PKG/389-ds-base-git-local.sh /tmp
	SRC_BZ2=`ls -rt /tmp/*bz2 | tail -1 `
	echo "Copy $SRC_BZ2"
	cp $SRC_BZ2 $DIR_RPM/SOURCES

	if [ -n "$PREFIX" -a -d $PREFIX ]
	then
		TARGET="--prefix=$PREFIX"
	else
		TARGET=""
	fi
	echo "Active the debug compilation"

	echo "Compilation start"
       CFLAGS='-O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector --param=ssp-buffer-size=4 -grecord-gcc-switches -specs=/usr/lib/rpm/redhat/redhat-hardened-cc1 -m64 -mtune=generic'
       CXXFLAGS=$CFLAGS

 	sed -e 's/^\%configure/CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS" \%configure/' $DIR_RPM/SPECS/389-ds-base.spec > $DIR_RPM/SPECS/389-ds-base.spec.new 
	cp $DIR_RPM/SPECS/389-ds-base.spec.new $DIR_RPM/SPECS/389-ds-base.spec
	sleep 3
	rpmbuild -ba $DIR_RPM/SPECS/389-ds-base.spec 2>&1 | tee $DIR_RPM/build.output
}

#
# Install it on a private directory $HOME/install
#
install()
{ 
	cd $DIR_SRC_DIR
	CFLAGS="-g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector --param=ssp-buffer-size=4 -m64 -mtune=generic -Wextra -Wno-unused-parameter -Wno-missing-field-initializers -Wno-sign-compare" 
	CXXFLAGS="$CFLAGS" $DIR_SRC_DIR/ds/configure --prefix=$DIR_INSTALL --enable-debug --with-openldap 2>&1 > $DIR_RPM/BUILD/build_install.output

	echo "Now install dirsrv"   >> $DIR_RPM/BUILD/build_install.output
	make install 2>&1           >> $DIR_RPM/BUILD/build_install.output

}

if [ ! -d $HOME/.dirsrv ]
then
     mkdir ~/.dirsrv # this is where the instance specific sysconfig files go - dirsrv-instancename
fi

initialize
compile
install

