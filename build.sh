#!/bin/sh
set -e
cd "$(dirname "$0")"

TAR="${LIBMAUDE_TAR:-}"
if [ -z "$TAR" ]; then
  for candidate in \
    ./libmaude.tar.xz \
    ../maudesmc/libmaude.tar.xz \
    ../Maude/libmaude.tar.xz
  do
    if [ -f "$candidate" ]; then
      TAR=$(cd "$(dirname "$candidate")" && pwd)/$(basename "$candidate")
      break
    fi
  done
fi

if [ -z "$TAR" ] || [ ! -f "$TAR" ]; then
  echo "ERROR: set LIBMAUDE_TAR=path/to/libmaude.tar.xz"
  echo "or place libmaude.tar.xz in .  or ../maudesmc/"
  exit 1
fi

mkdir -p dist
echo "==> image"
docker build -f Dockerfile.wheels -t maude-wheels .
echo "==> wheels from $TAR"
docker run --rm \
  -v "$TAR:/work/libmaude.tar.xz:ro" \
  -v "$(pwd)/dist:/work/dist" \
  -e LIBMAUDE_PKG=/work/libmaude.tar.xz \
  maude-wheels
echo "==> done"
ls -lh dist/