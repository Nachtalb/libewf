#!/bin/sh
# Build static ewftools (ewfacquire, ewfacquirestream, ewfexport, ewfinfo,
# ewfverify) for QNX 6.5.0 armle-v7 from a libewf release tarball.
#
# Needs: docker, curl, tar, and the toolchain image built from
# https://github.com/Nachtalb/qnx65-armv7-toolchain (branch fix/debian-mirrors):
#   docker build --platform=linux/amd64 --target base-env \
#       --build-arg BASE=base-8.5 -t qnx65-armv7-toolchain:8.5 .
#
#   qnx/build.sh [version] [cpu]     defaults: 20260924 cortex-a8
# Output: build-qnx/ewf-qnx650-armv7/ with stripped binaries and SHA256SUMS.
set -eu
VERSION=${1:-20260924}
CPU=${2:-cortex-a8}
IMG=${QNX_IMAGE:-qnx65-armv7-toolchain:8.5}
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=$PWD/build-qnx
SRC=$OUT/libewf-$VERSION
TOOLS="ewfacquire ewfacquirestream ewfexport ewfinfo ewfverify"

mkdir -p "$OUT"
[ -f "$OUT/libewf-$VERSION.tar.gz" ] || curl -fsSL -o "$OUT/libewf-$VERSION.tar.gz" \
    "https://github.com/libyal/libewf/releases/download/$VERSION/libewf-experimental-$VERSION.tar.gz"
rm -rf "$SRC"
tar xzf "$OUT/libewf-$VERSION.tar.gz" -C "$OUT"

docker run --rm --platform=linux/amd64 -v "$SRC":/src -w /src -e CPU="$CPU" -e TOOLS="$TOOLS" "$IMG" sh -ec '
P=arm-unknown-nto-qnx6.5.0eabi
# The release ships the .cue scanner built with flex -Cf: a 1.7 MB table that
# doubles ewfacquire. Default compression is plenty for parsing a .cue file.
# (the outfile= %option in the .l wins over -o, hence lex.yy.c)
(cd libodraw && flex libodraw_cue_scanner.l && mv lex.yy.c libodraw_cue_scanner.c)

# No libpthread on QNX (pthreads live in libc), so threading is off.
CONFIG_SITE=/opt/qnx-cross/config.site \
CFLAGS="-O2 -mcpu=$CPU -mfpu=vfpv3 -mfloat-abi=softfp" \
./configure --host=$P --disable-shared --enable-static-executables \
    --without-pthread --disable-multi-threading-support \
    --without-openssl --without-libuuid --without-libfuse \
    --with-zlib --with-bzip2 > configure.log 2>&1 || { tail -30 configure.log; exit 1; }
make -j"$(nproc)" > make.log 2>&1 || { grep -E "error|Error" make.log | head -20; exit 1; }

# libtool drops -static/-all-static for this host; redo its final link lines.
cd ewftools
for b in $TOOLS; do
    cmd=$(grep "^libtool: link: $P-gcc .* -o $b " ../make.log | tail -1 | sed "s/^libtool: link: //")
    [ -n "$cmd" ] || { echo "no link line for $b" >&2; exit 1; }
    eval "$cmd -static" 2>&1 | grep -v "Unknown EABI object attribute" || true
    $P-strip $b
    if $P-readelf -d $b | grep -q NEEDED; then echo "$b is not static" >&2; exit 1; fi
    if $P-objdump -d $b | grep -qE "\s(sdiv|udiv)\s"; then echo "$b uses hardware divide" >&2; exit 1; fi
done
'

DIST=$OUT/ewf-qnx650-armv7
rm -rf "$DIST"; mkdir -p "$DIST"
for b in $TOOLS; do cp "$SRC/ewftools/$b" "$DIST/"; done
(cd "$DIST" && sha256sum $TOOLS > SHA256SUMS)
ls -l "$DIST"
