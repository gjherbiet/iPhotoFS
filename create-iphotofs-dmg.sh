#!/bin/sh
# derived from a script by Marcus Müller <znek@mulle-kybernetik.com>

SOURCE_DIR=~/iPhotoFS/
BIN_DIR=~/iPhotoFS/build/Release/iPhotoFS.app
DST_DIR=~/iPhotoFS/iphotofs_app.$$
DST_IMG=${DST_DIR}.dmg

. ${SOURCE_DIR}/Version
RELEASE=${MAJOR_VERSION}.${MINOR_VERSION}.${SUBMINOR_VERSION}

if [ "$#" = "1" ]; then
  RELEASE=$1
fi

VOLUME_NAME="iPhotoFS ${RELEASE}"

echo "Making release: $RELEASE"
mkdir $DST_DIR
if [ ! -d $DST_DIR ]; then
  echo "Couldn't create intermediary dir $DST_DIR"
  exit 1
fi

# copy binaries
cd $BIN_DIR/..
gnutar cf - ${BIN_DIR##*/} | ( cd $DST_DIR ; gnutar xf - )

# copy READMEs
cd $SOURCE_DIR
gnutar cf - README COPYING | ( cd $DST_DIR; gnutar xf - )

# remove extra garbage
cd $DST_DIR
# some build artifact
rm -f iPhotoFS.app/iPhotoFS.app
find . -type d -name .svn -exec rm -rf {} \; > /dev/null 2>&1

# compute size for .dmg
SIZE_KB=`du -sk ${DST_DIR} | awk '{print $1}'`
# add some extra
SIZE_KB=`expr $SIZE_KB + 4096`

hdiutil create -size ${SIZE_KB}k ${DST_IMG} -layout NONE
#hdiutil create -size 15m ${DST_IMG} -layout NONE
DISK=`hdid -nomount ${DST_IMG} | awk '{print $1}'`
newfs_hfs -v "${VOLUME_NAME}" $DISK
hdiutil eject ${DISK}
DISK=`hdid ${DST_IMG} | awk '{print $1}'`

#copy package to .dmg
gnutar cf - . | ( cd "/Volumes/${VOLUME_NAME}" ; gnutar xf - )

# once again eject, to synchronize
hdiutil eject ${DISK}

# convert temp .dmg into compressed read-only distribution version
REL_IMG="${DST_DIR%%.*}-${RELEASE}.dmg"

# remove eventual ancestor
rm -f ${REL_IMG}

# convert .dmg into read-only zlib (-9) compressed release version
hdiutil convert -format UDZO ${DST_IMG} -o ${REL_IMG} -imagekey zlib-level=9

# internet-enable the release .dmg. for details see
# http://developer.apple.com/ue/files/iedi.html
hdiutil internet-enable -yes ${REL_IMG}

# clean up
rm -rf ${DST_DIR}
rm -rf ${DST_IMG}

MD5SUM=`md5 -q ${REL_IMG}`
REL_IMG_SIZE_B=`ls -l ${REL_IMG} | awk '{print $5}'`

echo "Image ready at: ${REL_IMG}"
